# SL Compatibility Audit

## TL;DR

Confidence that the Sakura toolchain reproduces real Second Life behaviour:

- **Compiler (`sakura-lslc`) alone — HIGH.** The type system, operator
  overload set, cast rules, global-initialiser constant-expression rule,
  and arity-aware overload table all match LL's official compiler. There
  is no known case where a script that compiles cleanly here is rejected
  by the SL uploader (for type/syntax reasons). The only structural
  divergence from LL's *default* compiler is the C-style preprocessor,
  and that matches Firestorm's external preprocessor exactly.
- **Emulator (`sakura-slemu`) alone — MEDIUM.** Pure-logic builtins
  (math, strings, lists, MD5, SHA-1, base64, JSON read, hex, URL
  encoding, listen routing, linkset data) are byte-faithful. Anything
  involving the physics simulator, rezzing, attaching, inventory, real
  HTTP round-trips, or in-world consequences is approximated, stubbed,
  or absent. The single known *correctness* divergence is
  `llSHA256String`, which returns a deterministic but non-SHA-256 hash.
- **Combined toolchain — HIGH for scripts in the "common script"
  envelope** (state machine + chat + listen + dialog + lists + JSON
  reads + linkset data + L$ + HTTP fixtures + MD5/SHA-1). Scripts that
  touch any feature flagged DIVERGES, STUBBED, or ABSENT in Section 2
  below should be tested on a sandbox region before deployment.

---

## 1. Compiler vs. LL's official compiler

### 1.1 Type system & implicit conversions

| Feature | sakura-lslc | LL | Risk if divergent |
| --- | --- | --- | --- |
| `integer <- integer` | yes | yes | none |
| `float <- integer` (implicit widening) | yes | yes | none |
| `key <-> string` implicit both ways in assignment context | yes | yes | none |
| All other implicit conversions | rejected — explicit cast required | rejected | none |
| `T_ANY` (list-element) accepts any type | yes | yes (list literals) | none |

Source: `sakura-lslc/src/types.c:52-60` (`type_implicit_assignable`).

### 1.2 Operator overload set (vector / rotation / list arithmetic)

| Operator | sakura-lslc result | LL result | Risk |
| --- | --- | --- | --- |
| `vector + vector` | vector (componentwise) | vector | none |
| `vector - vector` | vector | vector | none |
| `vector * vector` | float (dot product) | float (dot) | none |
| `vector % vector` | vector (cross product) | vector (cross) | none |
| `vector * scalar`, `scalar * vector` | vector | vector | none |
| `vector / scalar` | vector | vector | none |
| `vector * rotation`, `vector / rotation` | vector | vector (rotated) | **see 2 — VM approximates rotation by scalar `s` only** |
| `rotation * rotation` | rotation | rotation | none (Hamilton product implemented in `vm.c:229`) |
| `rotation - rotation` | rotation (componentwise) | rotation | none |
| `list + list`, `list + scalar`, `scalar + list` | list concat | list concat | none |
| `string + string` | string | string | none |
| `list ==/!=` | compares **length only** | length only | none — matches LSL |
| `&`, `|`, `^`, `<<`, `>>` | integer only | integer only | none |

Source: `sakura-lslc/src/types.c:91-148` (`type_binop_result`),
`sakura-slemu/src/vm.c:163-304` (`eval_binary`).

### 1.3 Cast rules — every `(T)expr` combination

| To \ From | integer | float | string | key | vector | rotation | list |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **integer** | ok | ok (trunc) | ok (strtol) | no | no | no | no |
| **float** | ok | ok | ok (strtod) | no | no | no | no |
| **string** | ok | ok (`%.6f`) | ok | ok | ok (`<x,y,z>`) | ok (`<x,y,z,s>`) | ok (concat) |
| **key** | no | no | ok | ok | no | no | no |
| **vector** | no | no | ok (parse `<…>`) | no | ok | no | no |
| **rotation** | no | no | ok (parse `<…>`) | no | no | ok | no |
| **list** | ok (wraps) | ok (wraps) | ok (wraps) | ok (wraps) | ok (wraps) | ok (wraps) | ok |

This exactly matches the LSL Wiki Typecast table. Source:
`sakura-lslc/src/types.c:72-87` (`type_explicit_castable`),
`sakura-slemu/src/vm.c:306-346` (`do_cast`).

### 1.4 Global initialiser constant-expression restriction

| Feature | sakura-lslc | LL | Risk |
| --- | --- | --- | --- |
| Global init may use literals, casts, ops, built-in constants | yes | yes | none |
| Global init may call a function | **rejected with hint** | rejected | none |
| Global init may reference another global | **rejected with hint** | rejected | none |
| Folding (e.g. `1+2` → `3`, `<1,2,3>.y` → `2.0`) | yes | yes | none |

Source: `sakura-lslc/src/sem.c:776-792` (called after `fold_expr`); rule
in `sakura-lslc/src/fold.c:37-72` (`expr_is_constant`). Folder covers
arithmetic, string concat, unary, cast literal, and member-of-literal.

### 1.5 Preprocessor

| Aspect | sakura-lslc | LL (default) | Firestorm |
| --- | --- | --- | --- |
| `#define`, `#if`, `#include`, `__LINE__`, …| **yes** (C-style) | no | yes (external preprocessor) |
| Production scripts that don't use `#…` directives | identical | identical | identical |
| Risk | none for plain scripts; **medium** for scripts that rely on conditional `#define` to gate code paths — if you upload via the LL default viewer your `#define`s become syntax errors. Mitigation: use `--no-preprocess`, or strip `#…` lines before uploading via LL viewer. ||| 

Source: `sakura-lslc/src/main.c:121-141`. The preprocessor is on by
default and can be disabled with `--no-preprocess`; the pre-expanded
source can be inspected with `-E`.

### 1.6 Memory budget (64 KiB Mono / 16 KiB LSO)

| Aspect | sakura-lslc | LL | Risk |
| --- | --- | --- | --- |
| Estimate basis | **stripped source size** (heuristic) | exact bytecode size after compilation | sakura may over- or under-estimate by a small constant factor; the warning fires at 80% and the error at 100% of the chosen budget |
| Mono budget | 64 KiB default | 64 KiB | none in concept |
| LSO budget | 16 KiB with `--lso`; rejects Mono-only ll-fns (`llChar`, `llOrd`, `llJson*`, `llTransferLindenDollars`, `llHMAC`) | 16 KiB | none in concept |
| Override | `--memory-budget=N`, `--no-memory-check` | — | — |

**Tag explicitly: this is an approximation.** A real script that
passes our budget may still be rejected by the SL uploader if its
compiled bytecode is larger than expected (e.g. heavy use of strings,
deep ASTs, or many globals push real bytecode above source size).
Source: `sakura-lslc/src/main.c:152-172`.

### 1.7 Diagnostics

| Aspect | sakura-lslc | LL | Risk |
| --- | --- | --- | --- |
| Format | gcc-style with carets, ranges, hints, "did you mean?" | line-only `(N,M) : ERROR : …` | UX-only divergence, no behavioural difference |
| `-Wall` extras: unused globals/functions, shadowing globals/constants, suspicious user redef of built-in names | yes | no | none — these warnings are advisory |
| `-Werror` | yes | n/a | none |

### 1.8 Built-in coverage

| Counter | Value | Notes |
| --- | --- | --- |
| Built-in functions (incl. arity overloads) | **540** entries covering ~430 unique names | source: line count `grep -cE '^\s*(FN\|MN)[0-9]\(' builtins.c` |
| Built-in constants | several hundred (`BI_CONST`) | covers documented Mono surface |
| Built-in events | 51 entries (arity overloads incl.) covering 36 unique events | source: `sakura-lslc/src/builtins.c` event table |
| Unknown `ll…` call | **warning** (not error), treated as `<any>` return; matches conservative tool behaviour | source: `sakura-lslc/src/sem.c:282-295` |
| Unknown non-`ll` call | error with did-you-mean suggestion | same |
| Mono-only built-ins under `--lso` | rejected | source: `sakura-lslc/src/sem.c:248-254` |

**Permissive-warning family.** Any identifier starting with `ll` that
isn't in the table is treated as a warning rather than an error and
its return type becomes `<any>`. This means future or undocumented LL
builtins parse cleanly; the trade-off is that typos like
`llRequstPermissions` produce a warning instead of a hard error
(though a "did you mean" hint is emitted).

---

## 2. Emulator vs. real region

Legend:
- **IDENTICAL** — same output as SL for same input.
- **APPROXIMATED** — semantically right but may differ on edge cases (noted).
- **STUBBED** — returns zero / no-op; ok for scripts that don't depend on it.
- **DIVERGES** — behaviour differs in a way that matters.
- **ABSENT** — not implemented; calling it logs `(stub)` under `--trace`.

### 2.1 Math (`llAbs` … `llVecDist`, `llEuler2Rot`, etc.)

| Status | IDENTICAL |
| --- | --- |
| Notes | Uses libc `math.h`. `llSqrt(-x) → 0`, `llLog(<=0) → 0`, `llLog10(<=0) → 0` (LSL has the same defensive behaviour). `llFrand` uses libc `rand()` — distribution matches but seed is unrelated to SL's. |
| Risk | none for deterministic math; `llFrand` output stream will differ from SL but distribution is statistically equivalent |

Source: `sakura-slemu/src/builtins.c:598-632`.

### 2.2 Strings (`llStringLength`, `llGetSubString`, etc.)

| Status | IDENTICAL for ASCII; **APPROXIMATED** for UTF-8 |
| --- | --- |
| Notes | All string offsets and lengths are **byte-based**; SL Mono `llStringLength` is **codepoint-based** for `llStringLength`, and `llGetSubString` is codepoint-based as well. Pure ASCII scripts see no difference. `llChar` only emits ASCII (codepoints > 127 collapse to `?`); SL emits proper UTF-8 surrogate pair. |
| Risk | medium for scripts that index into UTF-8 strings or rely on codepoint counts |

Source: `sakura-slemu/src/builtins.c:264-358`, esp. `llChar` at 346 and
`llStringLength` at 264.

### 2.3 Lists

| Status | IDENTICAL |
| --- | --- |
| Notes | `llList2*` indexing, negative indices, wrap-around in `llGetSubString`, list arithmetic, `llListSort` (asc/desc, strided), CSV, parse with separators+spacers, `llListFindList`, `llListReplaceList`, `llDeleteSubList`, `llListRandomize` (stride-aware). List equality returns length comparison, matching LSL. |
| Risk | none |

Source: `sakura-slemu/src/builtins.c:364-592` and
`sakura-slemu/src/value.c:144-147` (list `==` semantics).

### 2.4 JSON

| Status | **APPROXIMATED** |
| --- | --- |
| Notes | `llJsonGetValue` walks objects/arrays by path-list (string keys / int indices) and returns the leaf as a string. `llJson2List` flattens one level. `llList2Json` builds object or array from a `JSON_OBJECT` / `JSON_ARRAY` sentinel + flat key/value list. JSON sentinels (`JSON_INVALID`, `JSON_NUMBER`, …) use the same private-use Unicode markers as SL. `llJsonValueType` returns the right sentinel for `{`, `[`, `"`, `t/f`, `n`, and number-like. **`llJsonSetValue` is a stub that returns the input unchanged.** |
| Edge cases that differ | nested escapes inside string values (we don't unescape `\"`/`\\`/`\uXXXX`); whitespace-tolerant but not RFC 8259 strict; `llList2Json` does not escape `"` or `\` inside string values. |
| Risk | medium — fine for reading and emitting machine-generated JSON; not safe for arbitrary user input containing escaped quotes |

Source: `sakura-slemu/src/builtins.c:1215-1403`.

### 2.5 Hashes

| Function | Status | Notes |
| --- | --- | --- |
| `llMD5String(str, nonce)` | **IDENTICAL** | Real RFC-1321 MD5 over `str + ":" + nonce` — matches LSL exactly. Source: `builtins.c:957-1032`. |
| `llSHA1String(str)` | **IDENTICAL** | Real RFC-3174 SHA-1. Source: `builtins.c:1035-1079`. |
| `llSHA256String(str)` | **DIVERGES** | Currently returns a SHA-1-based 64-hex placeholder (SHA-1 digest concatenated with its own first 12 bytes). Output is deterministic but **does not equal real SHA-256**. Any script that uses the hash for HMAC handshakes or compares against an externally computed SHA-256 will misbehave. Source: `builtins.c:1081-1094`. |
| `llHMAC(key, msg)` | **APPROXIMATED** | Implemented as HMAC-SHA1 (with the same RFC-2104 algorithm). LSL's `llHMAC` is HMAC-SHA1 by default, so this is correct for the common case; if SL ever supports HMAC-SHA256 it will diverge for the same reason as SHA-256. Source: `builtins.c:1182-1200`. |
| `llHash` | IDENTICAL semantics (deterministic djb2) | Not in LL's surface area, but unused there too. |

### 2.6 HTTP

| Status | **APPROXIMATED** |
| --- | --- |
| Notes | `llHTTPRequest` is dispatched through `sakura-slemu/src/http.c` and can be configured (fixture file or live mode). In fixture mode it never actually hits the network — useful for tests, but the script never sees a real server. `llRequestURL` / `llRequestSecureURL` register an inbound endpoint and synthesise a `URL_REQUEST_GRANTED` `http_request` event; no real public URL is ever issued. `llHTTPResponse` is a no-op stub (in real SL it would respond to an inbound request — fine if you don't run the inbound flow). |
| Risk | low if you treat the fixture as a test harness; high if you rely on real-network side effects (cookies, redirects, TLS pinning, throttling) — those are absent |

Source: `sakura-slemu/src/builtins.c:1409-1438`,
`sakura-slemu/src/http.c`.

### 2.7 L$ economy

| Status | **APPROXIMATED** |
| --- | --- |
| Notes | `llGiveMoney` and `llTransferLindenDollars` debit the owner avatar's local balance (`Region->avatars[].balance`) and credit the destination, firing `money` and `transaction_result` events. `PERMISSION_DEBIT` is enforced. **No LL fee** (SL takes 5%–ish on some flows), **no daily limit**, **no real linden$**. |
| Risk | high — never deploy a money-handling script without sandbox testing on a real grid |

Source: `sakura-slemu/src/builtins.c:850-896`.

### 2.8 Linkset data

| Status | **APPROXIMATED** (persistent across runs) |
| --- | --- |
| Notes | Backed by the slemu volume directory (`slemu_volume/…/lsd/`). `llLinksetDataWrite/Read/Delete/Reset/CountKeys/ListKeys/Available` all hit the on-disk store. `llLinksetDataAvailable` returns a constant 65536 (SL's actual cap). Persistence and key visibility match the per-linkset, per-region model. Cross-region migration is not modelled. |
| Risk | low |

Source: `sakura-slemu/src/builtins.c:904-942`,
`sakura-slemu/src/volume.c`.

### 2.9 Timers

| Status | **APPROXIMATED** |
| --- | --- |
| Notes | `llSetTimerEvent(f)` registers `s->timer_due = virtual_now + f`. The region loop wakes scripts when due. Uses real wall clock; **no event-rate limiter** (SL drops timers if the script queue is saturated; slemu just keeps firing). `llMinEventDelay` is a no-op. |
| Risk | low for ordinary timers; high if your script relies on SL's queue-overflow / drop behaviour |

Source: `sakura-slemu/src/builtins.c:661-667`.

### 2.10 `llSleep`

| Status | **APPROXIMATED** |
| --- | --- |
| Notes | Real wall sleep (`sleep_seconds`) inside the script's thread. SL pauses the script's event loop; slemu does the same. Blocking other scripts in the region differs (SL: scheduler suspends only that script; slemu: depends on threading mode). |
| Risk | very low |

### 2.11 Sensors

| Status | **STUBBED** |
| --- | --- |
| Notes | `llSensor`, `llSensorRepeat`, `llSensorRemove` are not actually swept. Listed as absent — calls return void and (if `llSensor*` is not in TABLE at all) log `(stub)`. Real SL would fire `sensor` / `no_sensor` events for surrounding avatars/objects. |
| Risk | high for scripts that depend on sensor sweeps |

Source: searched `sakura-slemu/src/builtins.c` — no `bi_llSensor`
implementations exist; falls through to `(stub)` path in
`vm.c:550-553`.

### 2.12 Vehicles, particles, sounds, cameras

| Status | **APPROXIMATED** (no visible side effect) |
| --- | --- |
| Notes | `llSetVehicleType`, `llApplyImpulse`, `llSetVehicleFlags`, `llParticleSystem`, `llPlaySound`, `llSetCameraEyeOffset`, etc. are accepted by the compiler and either no-op'd or have their parameter values stored. No physics integration, no audio, no graphics. |
| Risk | high for vehicle scripts (the most physics-coupled use case in SL); the script logic will run, but real-world motion / sound feedback can change behaviour (e.g. `at_target`, collision events you'd expect from movement won't fire) |

### 2.13 Detection (`llDetected*`)

| Status | **APPROXIMATED** |
| --- | --- |
| Notes | The script's `s->detected[i]` array is populated when a touch/collision/sensor event is synthesised via the region command interface (typically one detected actor per command). `llDetectedKey/Name/Owner/Type/Pos/LinkNumber` are correct for that data. In real SL a single event can carry many detected entries; commands can be scripted to push multi-detect arrays, but the typical CLI flow pushes one. |
| Risk | low for one-actor scripts; medium for crowd-handling scripts |

Source: `sakura-slemu/src/builtins.c:801-830`.

### 2.14 `llDie`

| Status | **APPROXIMATED** |
| --- | --- |
| Notes | Marks the script inert: drops the event queue and disables the timer. In SL it deletes the object from the region; slemu cannot actually remove the prim from a (non-existent) world. Anything in the same region that was listening to this script continues to run normally; in SL it would see `CHANGED_LINK` / a deletion. |
| Risk | low — most scripts use `llDie` as a terminal action |

Source: `sakura-slemu/src/builtins.c:687-695`.

### 2.15 `llRezObject` / `llRezAtRoot`

| Status | **STUBBED** (logged as `(stub)` under `--trace`) |
| --- | --- |
| Notes | No virtual prim is created. Scripts that depend on the `object_rez` event firing from a rezzed child will not see it. |
| Risk | high for rezzers / weapons |

### 2.16 `llCreateLink` / `llBreakLink` / `llBreakAllLinks`

| Status | **STUBBED** |
| --- | --- |
| Notes | No linkset reconfiguration. `llGetNumberOfPrims` reflects the number of `Script` objects in the region (set up at slemu startup), not dynamic link/unlink. |
| Risk | high for linkset-management scripts |

### 2.17 `llTeleportAgent` / `llTeleportAgentGlobalCoords` / `llTeleportAgentHome`

| Status | **STUBBED** |
| --- | --- |
| Notes | Not in the dispatch table; falls through to `(stub)`. The script continues; the agent does not move. |
| Risk | high for region-portal scripts |

### 2.18 Animations & attachments

| Status | **APPROXIMATED** |
| --- | --- |
| Notes | `attach` event is dispatched when the CLI runs `attach <uuid>` / `detach`. `llStartAnimation`, `llStopAnimation`, `llStartObjectAnimation`, `llGetAttached` (returns 0) are present in the compiler table but either no-op or stub at runtime — no visual side effect. |
| Risk | medium for attachments; low for simple attach-aware scripts that just need the event |

### 2.19 Inventory

| Status | **STUBBED** |
| --- | --- |
| Notes | `llGetInventoryNumber`, `llGetInventoryName`, `llGetInventoryType`, `llGetInventoryKey`, `llGetInventoryCreator`, `llGiveInventory`, `llRemoveInventory`, `llGetInventoryDesc`, `llGetNotecardLine`, `llGetNumberOfNotecardLines`: declared in the compiler but **not in slemu's dispatch TABLE** — they log `(stub)` and return zero/empty values. The prim has no inventory model. |
| Risk | high for any script that drives state from a notecard or vendor inventory |

---

## 3. The crucial promise

A script that:

1. **Compiles cleanly** under `sakura-lslc` (`lslc -Wall` reports no
   errors and ideally no warnings), AND
2. **Produces the expected behaviour** in `sakura-slemu` under your test
   inputs, AND
3. **Does not depend on any feature listed as DIVERGES, STUBBED, or
   ABSENT** in Section 2,

…should run identically in real Second Life.

The "depends-on" risk by builtin family:

| Family | Risk tag | Action before deploy |
| --- | --- | --- |
| Math, lists, strings (ASCII), MD5, SHA-1, base64, URL, hex | none | — |
| String byte-vs-codepoint (UTF-8 paths) | low/medium | test with a UTF-8 string |
| JSON read (`llJsonGetValue`, `llJson2List`, `llJsonValueType`) | low | test with your real payloads |
| `llJsonSetValue` | **stub** | replace with string-concat or avoid |
| `llSHA256String` | **diverges** | swap in a SHA-256 polyfill before SL deploy, or verify SHA-256 outputs against a sandbox region |
| HTTP fixture | approximated | enable live mode or test on a sandbox region |
| L$ flows | approximated | sandbox-test all money paths |
| Linkset data | none (modulo region migration) | — |
| Timers | none | — |
| Sensors | **stub** | sandbox-test |
| Vehicles / physics / particles / sounds | approximated | sandbox-test |
| Detected[] multi-actor | medium | sandbox-test |
| `llDie` | low | — |
| `llRezObject`, `llRezAtRoot` | **stub** | sandbox-test |
| `llCreateLink`, `llBreakLink` | **stub** | sandbox-test |
| `llTeleportAgent*` | **stub** | sandbox-test |
| Inventory / notecards | **stub** | sandbox-test |
| Animations (visual) | approximated | sandbox-test if appearance matters |

---

## 4. Migration checklist

A short walkthrough a developer should run before uploading to SL:

- [ ] Run `lslc -Wall script.lsl` and resolve every error and every
      warning (especially "unused function" — it often catches
      accidentally-dead code paths, and "unknown ll-prefixed function"
      — that's a typo until proven otherwise).
- [ ] If you are targeting an LSO region (rare in 2026, but possible),
      add `--lso` and re-run. This rejects Mono-only builtins
      (`llChar`, `llOrd`, `llJson*`, `llTransferLindenDollars`,
      `llHMAC`) up-front.
- [ ] Inspect the emulator transcript with `--trace` and check every
      `(stub)` line. Each one is a built-in we don't implement; verify
      your script does not actually rely on its side effects.
- [ ] If your script uses any of: `llSHA256String`, `llRezObject`,
      `llRezAtRoot`, `llCreateLink`, `llBreakLink`, `llTeleportAgent*`,
      `llSensor*`, or any `llGetInventory*` / notecard call, **plan
      sandbox testing**. These are the highest-risk divergences.
- [ ] If your script uses non-ASCII strings, verify with a known
      multi-byte UTF-8 input that string offsets behave as you expect.
      Consider migrating string indexing to `llSubStringIndex` /
      `llParseString2List` rather than raw integer offsets.
- [ ] If the compiler's memory-budget warning fires (`script source
      is ~X bytes (Y% of Mono budget)`), run a real upload in a sandbox
      to confirm — our estimate is heuristic.
- [ ] If you use the C-style preprocessor, run `lslc -E script.lsl >
      out.lsl` and upload `out.lsl` instead of the original — that
      removes the dependency on Firestorm's preprocessor.
- [ ] Test on a **sandbox region** before the production region. This
      catches L$ flow, rez chains, teleport flows, sensor sweeps,
      vehicle physics, and notecard reads — everything in Section 2
      tagged APPROXIMATED, STUBBED, or ABSENT.

---

## 5. Roadmap (fix-it candidates, ordered by impact)

1. **Real SHA-256** — replace the SHA-1-doubled placeholder in
   `sakura-slemu/src/builtins.c:1081-1094` with a real FIPS-180-4
   implementation. This is the only behavioural divergence in the
   pure-logic surface.
2. **`llSensor` / `llSensorRepeat` virtual scanning** — sweep the
   region's avatar + script list against the type/distance/arc
   filters and synthesise `sensor` / `no_sensor` events. Highest
   missing-feature impact for combat / proximity scripts.
3. **`llGetInventory*` family backed by the volume directory** —
   model a per-prim inventory as a folder under
   `slemu_volume/<uuid>/inventory/` with name, type, key,
   permissions metadata. Unlocks notecard-driven scripts.
4. **`llRezObject` / `llRezAtRoot` create a virtual prim** in the
   region; fire `object_rez` event back to the rezzer; allow the
   rezzed prim to load a script from the inventory above.
5. **`llCreateLink` / `llBreakLink`** dynamic linkset reconfiguration
   with proper `CHANGED_LINK` events.
6. **`llTeleportAgent*`** as a tracked avatar-move with optional
   region-name validation against a configured region map.
7. **`llJsonSetValue`** — full path-aware JSON edit/insert/delete.
   Currently a no-op pass-through.
8. **UTF-8 codepoint-aware string indexing** in `llStringLength`,
   `llGetSubString`, `llDeleteSubString`, `llInsertString`,
   `llSubStringIndex`, `llChar`, `llOrd`.
9. **Event-rate / queue-overflow modelling** in the region loop, to
   match SL's behaviour when scripts produce events faster than they
   can be drained.
10. **Vehicle physics integration** (low priority because
    vehicle-script development typically requires in-world testing
    anyway).
