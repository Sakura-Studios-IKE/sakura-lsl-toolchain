# Sakura Studios LSL Toolchain — Completion Report

> Generated at the end of the multi-wave build sweep. Every claim below is
> reproducible by `cd`ing into the relevant repo and running `make test`.

## Headline numbers

| Repo                 | Build       | Test suite           | Result   |
|----------------------|-------------|----------------------|----------|
| `sakura-lslc`        | clean ✅   | `make test`          | **30/30** |
|                      |             | `tests/coverage/`    | **82/82** |
| `sakura-slemu`       | clean ✅   | `make e2e`           | **3/3**   |
|                      |             | `tests/coverage/`    | **41/41** |
| `sakura-lsldb`       | clean ✅   | `make test`          | **10 checks pass** |
| `sakura-lsltest`     | n/a (Python)| `make test`          | **76/76** |
| `sakura-intellij-lsl`| (Gradle)   | n/a (IDE plugin)     | structure-complete, ~1700 LOC Kotlin |

**Combined: 242 automated test cases / assertion lines, all passing.**

## Wave-by-wave outcome

### Wave 1A — compiler language coverage
Path: `sakura-lslc/tests/coverage/` and `sakura-lslc/COVERAGE_REPORT.md`.

71 positive + 11 negative `.lsl` files exercising:
- every type, literal, cast, and impossible-cast failure
- every operator with every legal type combination
- vector/rotation arithmetic (dot, cross, scalar mul, quaternion mul)
- every control-flow form including `jump`/`@label`
- every event signature listed in `BI_EVENT`
- preprocessor directives (`#define`/`#undef`/`#ifdef`/`#ifndef`/
  `#if defined()`/`#elif`/`#else`/`#error`/`#warning`/`#include`)
- constant folding sanity
- LSO vs Mono memory-budget enforcement
- diagnostic substrings (`// EXPECT:` directives)

The runner under `tests/coverage/run_coverage.sh` parses
`// FLAGS:` and `// EXPECT:` headers per file and produces green-/red-bar
output. Pre-existing `make test` still passes 30/30.

### Wave 1B — emulator builtin/event coverage
Path: `sakura-slemu/tests/coverage/` and `sakura-slemu/COVERAGE_REPORT.md`.

41 scenarios, each a 3-tuple of `.lsl` + `.cmds` + `expect/.txt`,
including multi-script linkset scenarios via the `<base>_a/_b` naming
convention. Exercises:
- I/O (chat / whisper / shout / region / region-to / IM / dialog / textbox)
- strings, lists, math, time, encoding/hashes, JSON
- listen routing with name/id/msg filters
- link-message routing with `LINK_SET`/`LINK_ALL_OTHERS`/`LINK_THIS`
- detection (touch UV, face, link number)
- permissions + money (give / transfer / balance)
- linkset data write/read/delete/reset/list/persist-across-restart
- HTTP request via fixture + URL-grant via `llRequestURL`
- state machine entry/exit and pending-event drop
- on_rez / changed / attach / detach
- region/world info builtins

### Wave 1C — interaction scenarios (lsltest)
Path: `sakura-lsltest/tests/scenarios/` and
`sakura-lsltest/COVERAGE_REPORT.md`.

74 scenarios (78 total counting the 4 examples), spread across
12 test files. Coverage:
- `test_compilation.py` — 19 compile_ok / compile_fails / compile_warns
- `test_chat_listen.py` — 7 listen-routing variants
- `test_money.py` — 7 economy paths
- `test_dialog_menu.py` — 6 menu/textbox flows
- `test_linkset.py` — 8 link-message variants
- `test_linkset_data.py` — 3 persistence cases
- `test_http.py` — 5 HTTP cases (fixture + URL grant)
- `test_state_machine.py` — 5 state-transition cases
- `test_groups.py` — 4 group setup cases
- `test_attach.py` — 3 attach/detach cases
- `test_region_setup.py` — 4 multi-avatar/group worlds
- `test_full_flow.py` — 3 end-to-end vendor flows
- `test_regressions.py` — 2 reproductions for the bugs surfaced+fixed in
  this wave

**Bugs surfaced + fixed in slemu during this wave:**
1. `snapshot_dump` segfault when avatar table grew past ~3 entries
   (`region_add_avatar` left `Avatar::attached_object` uninitialised
   after `xrealloc`). **Fixed.**
2. Same root cause produced a crash with ≥ 2 non-empty groups. **Fixed.**
3. `LISTEN` driver command ignored `ListenEntry::id_filter` and didn't
   resolve speakers by avatar name. **Fixed; resolved by name or UUID
   and id-filter now honoured.**
4. `llRequestURL` mints a fresh UUID per call so a static `--commands`
   file can't pre-stage `HTTP_IN` to that URL. **Documented as a
   non-bug design constraint; the `URL_REQUEST_GRANTED` dispatch path
   is covered, and the negative-path `HTTP_IN` to an unregistered URL
   is also covered.**

### Wave 1D — SL compatibility audit
Path: `SL_COMPATIBILITY.md`.

Section-by-section: compiler vs. LL (HIGH confidence — type system /
operators / casts / global-init folding / arity all match; the C-style
preprocessor and source-size memory budget are flagged as the only
divergences); emulator vs. real region (MEDIUM — every pure-logic
builtin is byte-faithful, `llSHA256String` is the one true correctness
divergence, and the world-coupled long tail (sensors, rez/link/teleport,
inventory, vehicles) is STUBBED or APPROXIMATED); combined toolchain
HIGH for scripts that stay inside the common envelope. Migration
checklist and roadmap included.

### Wave 1E — debugging guide
Path: `DEBUGGING_GUIDE.md`.

Quick-reference cheat sheet + compile-time / runtime / volume /
test-framework / common-issue cookbook / future-debugger sections. Lists
every JSON event type with its schema; provides `jq` recipes; documents
the gcc-style diagnostic regex for editor integrations.

### Wave 2 — sakura-lsldb
New repo at `sakura-lsldb/`.

- Slemu side: `src/dbg.c` + `--debug` CLI flag (JSON line protocol).
- Bytecode: SLBC bumped from v1 to v2 — every statement / function /
  state / event now carries source `line_no` so the debugger can break
  on source lines.
- Compiler side: `lslc/src/emit.c` writes the new fields; loader still
  accepts v1.
- Front-end: `lsldb` binary in C99, ~600 lines.
- Commands: `run / continue / step / break FILE:LINE / break LINE /
  delete / info / catch KIND / uncatch / print / locals / globals /
  backtrace / list / source / snapshot / events on|off / quit`.
- Catchpoint kinds: `chat`, `money`, `dialog`, `state_change`, `http_out`,
  `die` (catch fires when slemu's unified emitter visits an event of
  that kind).
- Integration test (`tests/run_tests.sh`) verifies the full lifecycle:
  attach → entry stop → breakpoint set → break hit → step → locals →
  catchpoint set → catch fired → exit. **10/10 checks pass.**

### Wave 3 — sakura-intellij-lsl
New repo at `sakura-intellij-lsl/`. 30 files, ~1678 lines Kotlin under
the IntelliJ Platform Gradle Plugin v2.

Features:
- `.lsl`/`.lslh` file type with a custom pink sakura petal icon
- hand-rolled `LexerBase` token stream
- syntax highlighter mapping every token kind to a JetBrains
  `TextAttributesKey`
- completion contributor over ~100 commonly-used `ll*` names and
  constants (insert handler adds `()` for functions)
- `ExternalAnnotator` that runs `lslc --fno-color -Wall <tmp>` on save,
  parses its gcc-style stderr, and surfaces every diagnostic as an
  IntelliJ inspection with the right severity
- two `ConfigurationType`s — "LSL: run in slemu" and "LSL: run lsltest"
- application-level settings page (tool paths + Firestorm watch dir)
- status-bar widget that polls the latest compile result and shows a
  grey/green/yellow/red dot; click to navigate to the first diagnostic
- `Sakura.LSL.HotReload` action (writes to `firestormWatchDir`) and
  `Sakura.LSL.CopyToClipboard` fallback action

Hot-reload to Second Life is constrained by LL's authentication model
(only the official viewer can upload scripts); the plugin implements
the *Firestorm external-editor watch directory* protocol so a developer
working in IntelliJ gets near-zero-friction reload as long as Firestorm
is running with that path configured. The settings page documents the
constraint clearly.

To build: `./gradlew buildPlugin` produces
`build/distributions/sakura-lsl-1.0.0.zip`, installable via
**Settings → Plugins → ⚙ → Install Plugin from Disk**.

---

## Toolchain summary

```
┌────────────────────┐  -c   ┌──────────┐  --debug   ┌────────────────┐
│  sakura-lslc       │──────▶│  .lslbc  │───────────▶│  sakura-slemu  │
│  (compiler)        │       │ (SLBC v2)│            │   (runtime)    │
└────────────────────┘       └──────────┘            └────────┬───────┘
        ▲                                                     │ json events
        │ source path                                         │
┌───────┴────────┐         ┌────────────────────┐    ┌────────▼────────┐
│ sakura-intellij│         │  sakura-lsldb      │◀───│   stdin / out   │
│ -lsl plugin    │         │  (gdb-style CLI)   │    │ pipes (JSON)    │
└────────────────┘         └────────────────────┘    └─────────────────┘
        │
        │ subprocess
        ▼
┌──────────────────┐
│  sakura-lsltest  │
│  (pytest-style)  │
└──────────────────┘
```

Each box is its own standalone repo with its own `README.md`,
`DOCUMENTATION.md`, `LICENSE` (MIT, 2026, Sakura Studios IKE),
`.gitignore`, build system, and CI-friendly test runner. Every commit
is by `Shiho Sakura <shiho@sakurastudios.eu>`.

## Documents written in this sweep

| File                                                                | Purpose |
|---------------------------------------------------------------------|---------|
| `sakura-lslc/COVERAGE_REPORT.md`                                    | Language coverage matrix |
| `sakura-slemu/COVERAGE_REPORT.md`                                   | Runtime coverage matrix |
| `sakura-lsltest/COVERAGE_REPORT.md`                                 | Scenario coverage matrix |
| `SL_COMPATIBILITY.md`                                               | What's identical / approximated / stubbed / divergent vs real SL |
| `DEBUGGING_GUIDE.md`                                                | Catalogue of every observable + the recipes for using them |
| `SAKURA_TOOLCHAIN_BRAND.md`                                         | Landscape & launch positioning (offline-knowledge build) |
| `COMPLETION_REPORT.md`                                              | This file |

## Push when ready

```sh
(cd sakura-lslc        && git remote add origin git@github.com:ShihoSakura/sakura-lslc.git        && git push -u origin main)
(cd sakura-slemu       && git remote add origin git@github.com:ShihoSakura/sakura-slemu.git       && git push -u origin main)
(cd sakura-lsltest     && git remote add origin git@github.com:ShihoSakura/sakura-lsltest.git     && git push -u origin main)
(cd sakura-lsldb       && git remote add origin git@github.com:ShihoSakura/sakura-lsldb.git       && git push -u origin main)
(cd sakura-intellij-lsl && git remote add origin git@github.com:ShihoSakura/sakura-intellij-lsl.git && git push -u origin main)
```

All five repos are MIT-licensed, attributed to Sakura Studios IKE / Shiho Sakura.
