# Debugging Guide — Sakura LSL Toolchain

This guide catalogues every observability and debugging facility shipped
with the three Sakura tools — the compiler `sakura-lslc`, the headless
region emulator `sakura-slemu`, and the Python test framework
`sakura-lsltest` — and gives you a recipe for reaching it in under thirty
seconds.

---

## Quick-reference cheat sheet

When you hit a problem, scan this table top-to-bottom. The first row is
where roughly 80% of investigations start.

| You want to…                                       | Tool   | Invocation                                                  |
| -------------------------------------------------- | ------ | ----------------------------------------------------------- |
| See *why* a script won't compile                   | lslc   | `lslc -Wall foo.lsl`                                        |
| Watch *every* event a script raises                | slemu  | `slemu --trace --json-events foo.lslbc`                     |
| Stream side effects machine-readably               | slemu  | `slemu --json-events foo.lslbc \| jq -c .`                  |
| Drive scripted player input                        | slemu  | `slemu --commands actions.cmds foo.lslbc`                   |
| Provoke a specific event from Python               | lsltest| `world.touch(link=1)` etc., inside `@scene(...)`            |
| Keep the generated config / commands file          | lsltest| `lsltest run --keep`  *or* `configure(keep_artefacts=True)` |
| Find what built-ins exist                          | lslc   | `lslc --list-builtins \| sort`                              |
| Verify what bytecode size a script will use        | lslc   | `lslc --memory-budget=65536 foo.lsl` (warns at 80%)         |
| Capture diagnostics for CI                         | lslc   | `lslc --diag-output build.log foo.lsl`                      |
| Inspect persistent state                           | slemu  | `ls slemu_volume/`, `cat slemu_volume/economy.txt`          |
| Reset persistent state                             | slemu  | `rm -rf slemu_volume/`                                      |
| Hit a real HTTP endpoint                           | slemu  | `slemu --http-real foo.lslbc`                               |
| Bail out fast on first failure                     | lslc   | `lslc -fmax-errors=1 foo.lsl`                               |

---

## 1. Compile-time debugging (sakura-lslc)

`lslc` produces gcc-style diagnostics. Each diagnostic carries a source
location, a kind, a message, the offending source line, a caret row
underlining the exact range, and (when relevant) an indented `help:`
hint with a *did you mean?* suggestion.

```
foo.lsl:12:5: error: undeclared identifier 'llSetTextColr'
   12 |     llSetTextColr("hi", <1,1,1>, 1);
      |     ^~~~~~~~~~~~~
  help: did you mean 'llSetTextColor'?
```

The exact prefix `path:line:col: kind:` is gcc-compatible, so any editor
with a `gcc`-style problem matcher will jump straight to the right line.

### 1.1 Flag matrix

| Flag                    | What it does                                                  |
| ----------------------- | ------------------------------------------------------------- |
| `--mono`                | Target the Mono VM (default, 64 KiB budget)                   |
| `--lso`                 | Target legacy LSO VM (16 KiB budget; rejects Mono-only calls) |
| `--memory-budget=N`     | Override the bytecode-size budget (bytes)                     |
| `--no-memory-check`     | Disable the source-size budget check entirely                 |
| `-W` / `-Wall`          | Enable extra warnings                                         |
| `-Werror`               | Promote warnings to errors                                    |
| `-fsyntax-only`         | Default mode; only check syntax & types                       |
| `-fno-color`            | Disable ANSI color in diagnostics                             |
| `-fmax-errors=N`        | Stop after N errors (default 50)                              |
| `-q` / `--quiet`        | Suppress source carets and OK/warn summaries                  |
| `-I PATH`               | Add a preprocessor include directory                          |
| `-D NAME[=value]`       | Pre-define a preprocessor macro                               |
| `-E`                    | Print preprocessed source and exit (no parsing)               |
| `--no-preprocess`       | Skip the preprocessor entirely                                |
| `-c` / `--emit-bytecode`| Emit SLBC bytecode (`.lslbc`) for slemu                       |
| `-o FILE`               | With `-c`, output path (default: `<input>.lslbc`)             |
| `--diag-output FILE`    | Redirect diagnostics to FILE (default: stderr)                |
| `--list-builtins`       | Print every built-in function/constant/event name             |

### 1.2 Consuming diagnostics in editors / CI

Every diagnostic line begins with the gcc-format prefix:

```
<path>:<line>:<col>: <kind>: <message>
```

That matches the canonical regex:

```
^([^:]+):(\d+):(\d+):\s*(note|help|warning|error|fatal error):\s*(.*)$
```

Drop that into:

- **Vim** — `errorformat=%f:%l:%c:\ %t%*[^:]:\ %m`
- **VS Code** — `"problemMatcher.pattern.regexp"`
- **IntelliJ** — *Run / Edit Configurations / Output Filters*

For CI it's easier to capture diagnostics to a file instead of mixing
them with build output:

```sh
lslc --diag-output build.log -Wall *.lsl
```

### 1.3 Inspecting expansion before it hits the parser

When a macro is misbehaving, run only the preprocessor:

```sh
lslc -E -DDEBUG=1 -I include/ src/buyer.lsl > buyer.pp.lsl
```

When you suspect a header is *hiding* a parse error, run with
`--no-preprocess` so you can see whether the bare source compiles.

### 1.4 Enumerating the built-in vocabulary

`--list-builtins` is the canonical answer to "does that function exist?"

```sh
lslc --list-builtins | grep -i sit       # all sit-related built-ins
lslc --list-builtins | sort > builtins.txt
diff builtins.txt /opt/secondlife/builtins.txt   # what's missing?
```

### 1.5 The memory-budget heuristic

`lslc` strips comments and whitespace, counts the remaining bytes, and
compares to the per-VM budget (64 KiB Mono, 16 KiB LSO). At ≥80% you
get a `warning`; over the budget, an `error`. It is *not* an exact
bytecode size — disable with `--no-memory-check` if it gets in the way.

---

## 2. Runtime debugging (sakura-slemu)

`slemu` runs SLBC bytecode in a simulated region. Every script-visible
side effect goes through a single emitter (`events.c`), which has two
output modes.

### 2.1 Default (human) vs `--json-events`

The exact same scenario rendered both ways:

```
[say   ch=0 root] Hello, world!
[hud   root] text=Buy something rgb=(1.00,1.00,1.00) a=1.00
[dialog from=root to=2222... ch=-42] msg="Pick one" buttons=[OK|Cancel]
[money 2222... -> 1111... L$50 ok=1]
```

vs.

```json
{"t":0.010,"type":"chat","kind":"say","ch":0,"src":"root","src_uuid":"…","msg":"Hello, world!"}
{"t":0.011,"type":"hud","src":"root","text":"Buy something","r":1.0,"g":1.0,"b":1.0,"a":1.0}
{"t":0.012,"type":"dialog","src":"root","src_uuid":"…","to":"2222…","ch":-42,"msg":"Pick one","buttons":["OK","Cancel"]}
{"t":0.013,"type":"money","from":"2222…","to":"1111…","amount":50,"ok":1}
```

Use **human** mode when eyeballing in a terminal; use **JSON** mode when
piping into `jq`, your test framework, or any structured tool.

### 2.2 Flag matrix

| Flag                          | Default        | Purpose                                              |
| ----------------------------- | -------------- | ---------------------------------------------------- |
| `--trace`                     | off            | Log every dispatched event (adds `dispatch` events)  |
| `--json-events`               | off            | One JSON object per line on stdout                   |
| `--steps N`                   | 100000         | Cap on virtual event steps (0 = unlimited)           |
| `--timeout SECS`              | 60             | Wall-clock cap                                       |
| `--volume DIR`                | `./slemu_volume` | Persistence directory                              |
| `--config FILE`               | none           | Avatar / group / fixture seeding                     |
| `--commands FILE`             | none           | Scripted player actions                              |
| `--owner UUID[:Name]`         | synthetic      | Avatar reported by `llGetOwner()`                    |
| `--owner-balance N`           | 0              | Owner's starting L\$                                 |
| `--avatar UUID:BAL[:Name]`    | (repeatable)   | Pre-register an avatar with starting balance         |
| `--name NAME`                 | `Object`       | Object name from `llGetObjectName()`                 |
| `--no-http`                   | (default)      | Use HTTP fixture file                                |
| `--http-real`                 | off            | Send real HTTP via system `curl`                     |
| `--http-fixture FILE`         | none           | Fixture matched by URL substring                     |

### 2.3 JSON event catalogue

Every event emitted by `events.c` / `dialog.c`:

| `type`         | Key fields                                                            | Fires when                                              |
| -------------- | --------------------------------------------------------------------- | ------------------------------------------------------- |
| `chat`         | `kind`, `ch`, `src`, `src_uuid`, `msg` (+ `to` for `region-to`)       | `llSay`, `llShout`, `llWhisper`, `llRegionSay*`         |
| `hud`          | `src`, `text`, `r`,`g`,`b`,`a`                                        | `llSetText` / `llSetLinkPrimitiveParamsFast(PRIM_TEXT)` |
| `dialog`       | `src`, `to`, `ch`, `msg`, `buttons[]`                                 | `llDialog`                                              |
| `textbox`      | `src`, `to`, `ch`, `msg`                                              | `llTextBox`                                             |
| `loadurl`      | `src`, `to`, `label`, `url`                                           | `llLoadURL`                                             |
| `money`        | `from`, `to`, `amount`, `ok`                                          | `llTransferLindenDollars` or a player `MONEY_FROM`      |
| `link_message` | `src`, `src_link`, `target_link`, `num`, `str`, `id`                  | `llMessageLinked`                                       |
| `http_out`     | `src`, `url`, `method`, `status`, `body_len`                          | `llHTTPRequest` resolves (fixture or real)              |
| `state_change` | `src`, `from`, `to`                                                   | `state X;` in a script                                  |
| `dispatch`     | `src`, `event`, `n_args`                                              | Every event dispatched (only when `--trace`)            |
| `die`          | `src`                                                                 | `llDie()`                                               |
| `reset`        | `src`                                                                 | `llResetScript()` / `llResetOtherScript()`              |
| `info`         | `msg`                                                                 | slemu-internal informational lines                      |
| `assertion`    | `what`, `passed` (0/1), `detail`                                      | An `ASSERT_*` command runs                              |
| `snapshot`     | `avatars[]`, `groups[]`, `scripts[]`, `dialogs[]`                     | A `SNAPSHOT` command runs                               |

Every record also carries `"t":<float>` (virtual seconds).

### 2.4 Recipes

**Watch only money flow:**

```sh
slemu --json-events shop.lslbc | jq -c 'select(.type=="money")'
```

**Watch chat for a substring:**

```sh
slemu --json-events bot.lslbc | jq -c 'select(.type=="chat" and (.msg|test("BUY")))'
```

**Diff two runs of the same scenario:**

```sh
slemu --json-events --commands cmds scriptA.lslbc > a.events
slemu --json-events --commands cmds scriptB.lslbc > b.events
diff <(jq -c . a.events) <(jq -c . b.events)
```

**Tail forever** (long-running listener / load test):

```sh
slemu --json-events --steps 0 --timeout 0 listener.lslbc
```

`--steps 0` means *unlimited steps*; combine with `--timeout 0` to lift
the wall-clock cap too.

### 2.5 Player action verbs (the `--commands` file)

The file is line-oriented; `#` starts a comment, blanks are skipped.

| Verb                                 | What it does                                                |
| ------------------------------------ | ----------------------------------------------------------- |
| `WAIT <secs>`                        | Advance virtual time                                        |
| `ECHO <msg>`                         | Print a marker `info` event                                 |
| `EXIT`                               | Stop the main loop                                          |
| `TOUCH <link>`                       | Fire `touch_start`/`touch`/`touch_end` on a link            |
| `TOUCH_FACE <link> <face>`           | Touch with a face index (HUD click)                         |
| `TOUCH_AS <link> <avatar_uuid>`      | Touch by a specific avatar                                  |
| `LISTEN <ch> <name> <msg>`           | Someone speaks; delivered to every matching listener        |
| `IM <from_uuid> <msg>`               | Logs an IM (scripts rarely see IM in LSL)                   |
| `DIALOG_REPLY <avatar_uuid> <btn>`   | Avatar clicks a dialog button                               |
| `TEXTBOX_REPLY <avatar_uuid> <txt>`  | Avatar submits a textbox                                    |
| `MONEY_FROM <avatar_uuid> <amount>`  | Avatar pays the object (fires `money` event)                |
| `HTTP_IN <url_sub> <method> <body>`  | External system hits a slemu URL                            |
| `ATTACH <avatar_uuid> <point>`       | Script gets `attach(id)`                                    |
| `DETACH`                             | Script gets `attach(NULL_KEY)`                              |
| `ON_REZ <start_param>`               | Fire `on_rez(start_param)` on every script                  |
| `CHANGED <flags>`                    | Fire `changed(flags)`                                       |
| `SNAPSHOT`                           | Dump full region state to the event stream                  |
| `ASSERT_BALANCE <uuid> <amount>`     | Verify avatar balance                                       |
| `ASSERT_HUD <link> <substring>`      | Verify HUD text on a link contains substring                |
| `ASSERT_SAID <kind> <ch> <substring>`| Verify chat history (`kind` of `say`/`shout`/etc, or `*`)   |
| `ASSERT_DIALOG_OPEN <uuid>`          | Verify an open dialog for that avatar exists                |

### 2.6 Assertions in the JSON stream

Each `ASSERT_*` produces one record with `passed=0` or `passed=1`:

```json
{"t":1.500,"type":"assertion","what":"balance","passed":1,"detail":"2222… balance == 950"}
{"t":1.501,"type":"assertion","what":"hud","passed":0,"detail":"link=1 want=\"SOLD\" got=\"FOR SALE\""}
```

Fail an entire run by piping through `jq`:

```sh
slemu --json-events --commands cmds shop.lslbc | tee run.log \
  | jq -e 'if .type=="assertion" and .passed==0 then halt_error(1) else empty end'
```

### 2.7 `SNAPSHOT` — full state dump

In human mode you get a banner block:

```
==== slemu snapshot @ t=12.345 ====
  avatars (2):
    11111111-…  L$1050  Test Owner
    22222222-…  L$ 950  Buyer
  groups (0):
  scripts (1):
    link 1 vendor                12345-…  hud=Buy now!
  open dialogs:
    src=12345 -> 22222… ch=-42 [dialog] msg="Pick one"
      buttons: [OK] [Cancel]
============================
```

In `--json-events` mode it becomes one event:

```json
{"t":12.345,"type":"snapshot","avatars":[…],"groups":[…],"scripts":[…],"dialogs":[…]}
```

Use snapshots liberally at the end of scenarios — they're cheap and
they let post-run inspection answer "what was the state when this
finished?" without re-running.

---

## 3. Volume forensics

The persistent on-disk state lives under `--volume DIR` (default
`./slemu_volume`):

```
slemu_volume/
├── economy.txt        # avatar uuid -> balance, one row each
├── notecards/         # one file per virtual notecard
└── lsd/               # llLinksetData* persistent KV, one file per script
    └── <script-uuid>.txt
```

**Inspect the economy:**

```sh
cat slemu_volume/economy.txt
# 11111111-1111-1111-1111-111111111111 1050 Test Owner
# 22222222-2222-2222-2222-222222222222 950  Buyer
```

**Inspect a script's linkset data:**

```sh
ls slemu_volume/lsd/
cat slemu_volume/lsd/<script-uuid>.txt
```

### 3.1 Suggested workflows

1. Commit a known-good `slemu_volume/` directory to the repo as
   `tests/fixtures/baseline_volume/`. Before each scenario, copy it
   over the working volume.
2. After the run, `diff -ru tests/fixtures/baseline_volume slemu_volume`
   tells you exactly which scripts wrote what.
3. To clear everything: `rm -rf slemu_volume/`.

---

## 4. Test-framework debugging (sakura-lsltest)

The Python `World` fixture wraps `slemu --json-events` and parses every
emitted record into an `EventLine`. Failure mode is the same `assertion`
record from §2.6 — `World._run()` raises `LsltestError` listing each
failing assertion's `what` and `detail`.

### 4.1 Verbose output

```sh
lsltest run -v               # show full failure detail
```

### 4.2 Keep generated artefacts

By default the framework writes `world.cfg`, `session.cmds`, and the
volume into a fresh tmpdir and deletes it on success. To inspect them:

```sh
lsltest run --keep
```

Or in Python:

```python
from sakura_lsltest.core import configure
configure(keep_artefacts=True)
```

The path printed in failure messages can be replayed by hand:

```sh
slemu --json-events --config <tmp>/world.cfg \
      --commands <tmp>/session.cmds --volume <tmp>/volume \
      <tmp>/*.lslbc | jq -c .
```

### 4.3 Post-run inspection in Python

```python
@scene(scripts=[VENDOR], owner=("1111…", "Owner", 0),
       avatars=[("2222…", "Buyer", 1000)])
def test_buy(world):
    world.touch(link=1, avatar="2222…")
    world.dialog_reply(avatar="2222…", button="Buy")
    world.snapshot()                                # always handy
    world.assert_balance("2222…", 950)

# after the test runs, every event is queryable:
chats = world.events("chat")
first_money = world.first("money", to="1111…")
final = world.events("snapshot")[-1]
```

`World.events(type=...)` and `World.first(type=..., **filters)` accept
the same keys you see in §2.3, plus the magic `substring="…"` filter
that does a contains-match on `repr(raw_dict)`.

### 4.4 Recipe: stabilise flaky scenarios

End every flaky scene with a snapshot — when the assertion fails, you'll
have the full state to compare against expectation:

```python
def test_thing(world):
    ...
    world.snapshot()
    world.assert_hud(1, "SOLD")
# on failure, look at world.events("snapshot")[-1]
```

---

## 5. Common-issue recipes

| Symptom                                                | First thing to check                                                              |
| ------------------------------------------------------ | --------------------------------------------------------------------------------- |
| Script compiles but emulator prints `(stub) X`         | Built-in is recognised but not implemented; see `SL_COMPATIBILITY.md`.            |
| `llListen` handler never fires                         | Verify the 4 filter args (chan, name, key, msg). Run with `--trace`.              |
| Money transfer returned 0                              | `PERMISSION_DEBIT` not granted, or owner balance < amount. Inspect `economy.txt`. |
| HTTP request never gets a `http_response`              | No fixture provided. Use `--http-fixture` *or* `--http-real`.                     |
| Dialog opens but reply doesn't reach script            | The listen handle's channel must match `llDialog`'s `channel` argument.           |
| Test passes locally, fails in CI                       | Almost always wall-clock; bump `--timeout` (or `default_timeout`).                |
| `lsltest` shows `unknown command: X` in info events    | A `World` helper isn't generating the right verb; check spelling in `core.py`.    |
| Avatar appears unknown to script                       | Pass `--avatar UUID:BAL:Name` *and* `--owner` if it's the owner avatar.           |
| Diagnostics look bare in CI output                     | You're running with no TTY — pass `-Wall` and reach for `--diag-output build.log`.|

---

## 6. Future debugger (sakura-lsldb)

A dedicated source-level debugger (`sakura-lsldb`) — breakpoints,
single-stepping, stack inspection — is in development. Until it lands,
the supported triage workflow is the union of the techniques in this
guide:

1. `lslc -Wall` to catch every static issue before runtime.
2. `slemu --trace --json-events` to see every event dispatched.
3. `--commands` to script player input deterministically.
4. `ASSERT_*` and `SNAPSHOT` to capture state at known points.
5. `lsltest run --keep` to replay the exact failing scenario by hand.

This pipeline reliably localises every reproducible defect to a single
event or assertion; the upcoming debugger will close the gap for
non-deterministic ones.
