# Sakura Studios LSL Toolchain — Landscape & Positioning

> **Note on sourcing.** WebFetch and WebSearch were unavailable when this
> document was drafted (denied at the permission layer despite the
> retry). Claims drawn purely from offline model knowledge are tagged
> `*(unverified)*`. Anything inside Sakura's own repos (`sakura-lslc`,
> `sakura-slemu`) is verified against the local tree. The Sakura
> Studios website (`sakurastudios.eu`) could not be read, so Section
> 3's "brand voice" notes are framed as recommendations, not facts
> about the live site.

---

## 1. The state of LSL tooling today

LSL — Linden Scripting Language — has a tooling ecosystem that is wide,
old, and almost entirely *single-developer hobby projects* that come and
go. Below is the current lay of the land.

### In-viewer / official

- **Built-in viewer editor (Linden Lab official)** — plain textarea
  inside the SL viewer with syntax colouring; "Save" round-trips
  through the simulator, which is the only authoritative LSL
  compiler. Maintained as part of the viewer.
  <https://wiki.secondlife.com/wiki/LSL_Tutorial> *(unverified)*
- **Firestorm Preprocessor / Script Editor** — Firestorm's viewer
  adds a real script editor: external-editor hooks, an *optional*
  C-style preprocessor (`#include`, `#define`, `#ifdef`),
  script-recompile bulk ops, AO / translation helpers. Maintained —
  Firestorm ships regularly.
  <https://wiki.firestormviewer.org/fs_preprocessor> *(unverified)*

### Third-party desktop IDEs

- **LSL Editor** (`lsleditor.org`) — Windows-only IDE by
  *Alphons van der Heijden*. Mono compiler reimplementation,
  built-in simulator, debugger, project tree. Status: last
  meaningfully updated several years ago; still distributed and
  still has a Discord, development intermittent. *(unverified)*
- **LSLForge** — Eclipse plugin, fork of the older "LSL Plus". Type
  checker, in-editor errors, partial simulator. Source on GitHub
  (`raysilent/lslforge` is a common fork). Status: **mostly
  abandoned** — last substantive commit several years back; an
  unofficial fork occasionally fixes Eclipse breakage. *(unverified)*

### VS Code / modern editors

- **`vscode-lsl`** and **`lsl-language-server`** community
  packages — provide syntax, snippets, occasionally a partial
  linter. None ship a real type-checker or a backend that proves
  the script will upload cleanly. Maintenance is per-author and
  ranges from "updated this year" to "last touched 2019".
  *(unverified)*
- **Sublime / Atom / Notepad++ syntax packs** — exist
  (`LSL.sublime-syntax`, Notepad++ UDL XMLs floating around the SL
  forums), but are syntax-only and largely unmaintained.
  *(unverified)*

### Server-side / runtime

- **OpenSim XEngine / YEngine** — OpenSimulator's LSL runtimes.
  XEngine compiles LSL to C# and runs it under Mono/.NET; YEngine
  is the newer engine. Actively maintained as part of OpenSim
  itself. `opensimulator.org` *(unverified)*
- **LSL-PyOptimizer** by **Sei Lisa** — Python tool that parses
  LSL, folds constants, dead-code-eliminates, emits a much smaller
  source for upload. GitHub: `Sei-Lisa/LSL-PyOptimizer`.
  Maintained, low-frequency but real. The closest thing the
  community has to a serious offline static analyser today.
  *(unverified)*

### Online / validators / reference

- **LSL Wiki** (`wiki.secondlife.com/wiki/LSL_Portal`) — the
  canonical function/event reference; CC-BY-SA. Actively edited by
  community.
- **`outworldz.com`** LSL tools, assorted pastebins — online
  syntax-checkers; mostly wrappers over `LSL-PyOptimizer` or
  hand-written regexes. *(unverified)*

### Closed-source uploaders

A handful of commercial creators ship private build pipelines
(`make` + `curl` + viewer asset upload via undocumented endpoints).
None are public products. *(unverified)*

### Summary

**There is no actively-maintained, cross-platform, dependency-free,
gcc-grade LSL toolchain.** Firestorm ships an editor and a
preprocessor but not a compiler. LSL-PyOptimizer is a single-script
optimiser, not an IDE backend. LSLForge is dead. LSL Editor is
Windows-only and slowing down. Everything else is syntax
highlighting.

---

## 2. What Sakura's toolchain does that nothing else does

Mapping Sakura's tools against the gap list:

| Capability | Sakura | Firestorm | LSL Editor | LSLForge | PyOptimizer | VS Code packs |
|---|---|---|---|---|---|---|
| gcc-style diagnostics, carets, ranges | **Yes** | No | Partial | Partial | No | No |
| "did you mean?" suggestions | **Yes** (Levenshtein) | No | No | No | No | No |
| Headless C99 emulator | **Yes** (`slemu`) | No | Partial (Windows .NET sim) | Partial | No | No |
| Real automated-test framework | **In progress** (`lsltest`) | No | No | No | No | No |
| LSO compatibility mode | **Yes** (`--lso`) | No | Partial | No | Partial | No |
| Portable bytecode artefact (`.lslbc`) | **Yes** | No | No | No | No | No |
| Preprocessor matching Firestorm's | **Yes** | (Reference impl) | Partial | No | Partial | No |
| Zero Node / JS / Python / JVM deps | **Yes** (C99) | n/a | .NET | JVM | Python | Node |

The four things that are *genuinely* unique to Sakura, against
everything currently shipping:

1. **gcc-grade diagnostics for LSL.** Caret + range underline +
   helpful hint + "did you mean?" is table stakes in C / Rust /
   Swift; it does not exist anywhere else for LSL. This is the
   single most visible differentiator the moment a creator pastes a
   broken script in.
2. **A headless emulator you can run in CI.** Every other
   "simulator" is a GUI Windows app. `slemu` is a one-binary CLI
   that takes `.lslbc`, runs it, prints chat / dialog / HTTP
   events, and exits. That is the prerequisite for any real
   testing story.
3. **A portable compiled artefact (`.lslbc`).** Tagged-tree binary,
   reproducible, diffable, attachable to a release. Today the
   distributable unit of LSL is "a `.lsl` text file you paste into a
   prim." `.lslbc` makes LSL shippable like any other compiled
   language.
4. **Pure C99, single statically-linked binary, no runtime.**
   Builds with gcc / clang / tcc / MSVC, no `npm`, no `pip`, no
   JVM, no .NET. Long-term this is the *survival* property — the
   reason this toolchain is still going to compile in 2040.

A combined `lsltest` framework on top of `lslc + slemu` turns this
from "a nicer compiler" into **"the first LSL project that can have
a CI pipeline at all"** — and that is the headline.

---

## 3. Strategic / brand value

> The live `sakurastudios.eu` site could not be fetched in this
> session, so this section reads as recommendations, not commentary
> on existing copy.

### Why this matters to Sakura

- **Community dynamics in SL.** The SL creator community is small
  (low thousands of active scripters), tight, and very loyal to
  people who give them durable tooling. Maintainers of Firestorm,
  RLV, AVsitter, and OpenCollar are *household names* in SL despite
  none of it being commercial. A serious open toolchain buys
  permanent name recognition in that audience.
- **Open-source tooling longevity in SL.** Firestorm has outlasted
  multiple Linden Lab viewer reorgs; OpenSimulator has outlasted
  multiple grid waves. In SL, durable *open-source infrastructure*
  outlives most commercial products. A C99-only toolchain with no
  runtime deps is engineered to fit that pattern.
- **Recruitment signal.** A working LSL compiler + emulator + test
  framework is a credible "we can ship a non-trivial systems
  project" demo. For a studio that does commercial SL work, this
  is a sales asset; for a studio that hires engineers, it is the
  most useful possible job-spec advert.
- **Commercial credibility.** Anyone evaluating Sakura for paid SL
  work can see, in public, that the team has implemented the
  language *itself*. That is qualitatively different from a
  portfolio of HUDs.

### Recommended community channels

- **LSL Editor Discord** *(unverified, but historically the main
  scripting Discord)* — the most concentrated audience of SL
  scripters anywhere.
- **Second Life forums, "LSL Scripting" sub-board**
  (`community.secondlife.com`).
- **`/r/secondlife`** — generalist, but reaches creators.
- **Builder's Brewery** — long-standing in-world scripting school;
  guest classes / demos here are extremely high-signal.
- **OpenSim forums** (`opensimulator.org`) — secondary audience,
  but they care about open-source tooling more than SL does.
- **GitHub topic tags** `second-life`, `lsl`, `opensim` — cheap
  discovery channel.

---

## 4. Risks & considerations

- **Linden Lab trademark.** "Second Life", "SL", "Linden",
  "Mono-on-SL" are LL marks. Sakura should never imply endorsement.
  "Compatible with Second Life LSL" is fine; "Second Life compiler"
  is not. The current README phrasing ("If your script compiles
  here, it compiles when you upload it") is exactly the right
  register.
- **Official-compiler-parity expectations.** The moment a script
  compiles in `lslc` but the SL uploader rejects it (or vice versa),
  users will file a bug. Parity needs to be tracked as a
  first-class quality metric, ideally with a public corpus of
  "scripts the LL uploader accepts" used as a regression suite.
- **Maintenance burden as LL adds new built-ins.** LL ships new
  `ll*` functions a few times a year *(unverified)*. Each one
  needs: signature in `lslc`, stub or real impl in `slemu`. A
  single "built-ins manifest" file (one source of truth that both
  tools read) is the way to keep this from rotting.
- **License compatibility for reference data.** The LSL Wiki is
  CC-BY-SA. Function signatures themselves are facts (not
  copyrightable), but if any help text or example code is lifted
  verbatim from the wiki, attribution + SA obligations attach.
  OpenSim's source is BSD-licensed; safer to mine for behaviour.
- **Bytecode naming.** `.lslbc` is **Sakura's** bytecode, not
  Linden Lab's. LL has its own Mono CIL-based format internally.
  README / docs should say this explicitly the first time `.lslbc`
  is introduced, to head off "is this what gets uploaded?" confusion.
  One line — "`.lslbc` is an internal artefact for `slemu`; the SL
  servers re-compile from source on upload" — is enough.

---

## 5. Concrete launch recommendations

### Where to announce (priority order)

1. **GitHub release + a pinned post on the SL forums "LSL
   Scripting" board.** Single highest-signal channel.
2. **LSL Editor Discord** *(unverified — confirm invite still
   works)* announcement with a short asciinema of the "broken
   script → carat diagnostic" demo.
3. **`/r/secondlife`** text post; lead with a screenshot of a
   gcc-style error, *not* with a feature list.
4. **OpenSim mailing list / forum** once `--lso` mode is validated
   against an XEngine corpus.
5. **Builder's Brewery guest class** — 30-minute live demo:
   "writing and testing an LSL script without ever logging into SL".

### Demo video ideas

- **"Three errors before you log in."** Open a real, broken vendor
  script. Compile. Watch `lslc` produce three carated errors with
  fix hints. Fix them. Compile clean. Upload to SL. Works first
  time.
- **"Testing a vendor without buying anything."** `slemu` running a
  vendor script; harness "buys" the item, asserts the
  `transaction_result`, asserts the delivery `llGiveInventory`
  call. Zero L$ spent.
- **"A CI badge for an LSL repo."** GitHub Actions running
  `lsltest`. The badge alone is unprecedented.

### Blog-post hooks

- *"Why LSL doesn't have a real compiler — and why we wrote one."*
- *"gcc-style diagnostics for a 20-year-old scripting language."*
- *"How we emulated a Second Life region in 5 000 lines of C."*
- *"You can finally write LSL tests."*
- *"`.lslbc`: a portable artefact for a famously un-portable
  language."*

### Suggested next tools (after `lsltest`)

1. **LSP server** (`sakura-lsls`) — wraps `lslc`'s diagnostics into
   the Language Server Protocol. Drops into VS Code, Neovim,
   Helix, Zed, Sublime LSP. **Highest-leverage next step** — one
   binary, immediately useful to every editor.
2. **Formatter** (`sakura-lslfmt`) — opinionated, single-style, no
   config. `gofmt` model. Stops every SL repo's bikeshed.
3. **OBJ / Collada → LSL importer** — generate
   `llSetLinkPrimitiveParamsFast` sequences from a 3D model.
   Massive timesaver for builders; orthogonal to existing tools.
4. **`sakura-lslprof`** — profiling layer on `slemu`: per-function
   event time, memory-budget heatmap, listen-channel traffic.
5. **Package manager / include registry** — once `#include` works,
   shared libraries become possible for the first time. A simple
   git-based registry (à la Go modules) closes the loop.
6. **Web playground** — `lslc` compiled to WASM, in-browser
   diagnostics. Cheap to host, infinite top-of-funnel.

---

## 6. Tagline candidates

1. **"LSL, properly compiled."**
2. **"The compiler LSL never had."** *(safer than naming
    Second Life directly — trademark-clean.)*
3. **"Write LSL like it's 2026."**
4. **"gcc-grade diagnostics. Headless emulator. Real tests. Pure C."**
5. **"If it compiles in Sakura, it uploads in SL."**

Personal pick: **#4** for the README hero line (concrete, technical,
no marketing fluff), **#1** for the website banner, **#5** as the
under-the-fold proof line.

---

*Document length: ~1 950 words. Last revised 2026-05-15.*
