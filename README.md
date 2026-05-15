<p align="center">
  <img src="assets/branding/sakura-studios-mark.svg" alt="Sakura Studios" width="120"/>
</p>

# Sakura Studios LSL Toolchain

[![lslc](https://github.com/Sakura-Studios-IKE/sakura-lslc/actions/workflows/ci.yml/badge.svg)](https://github.com/Sakura-Studios-IKE/sakura-lslc/actions/workflows/ci.yml)
[![slemu](https://github.com/Sakura-Studios-IKE/sakura-slemu/actions/workflows/ci.yml/badge.svg)](https://github.com/Sakura-Studios-IKE/sakura-slemu/actions/workflows/ci.yml)
[![lsldb](https://github.com/Sakura-Studios-IKE/sakura-lsldb/actions/workflows/ci.yml/badge.svg)](https://github.com/Sakura-Studios-IKE/sakura-lsldb/actions/workflows/ci.yml)
[![lsltest](https://github.com/Sakura-Studios-IKE/sakura-lsltest/actions/workflows/ci.yml/badge.svg)](https://github.com/Sakura-Studios-IKE/sakura-lsltest/actions/workflows/ci.yml)
[![intellij](https://github.com/Sakura-Studios-IKE/sakura-intellij-lsl/actions/workflows/ci.yml/badge.svg)](https://github.com/Sakura-Studios-IKE/sakura-intellij-lsl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> A complete open-source toolchain for Linden Scripting Language (LSL) development.
> Five independently-installable tools, one coherent workflow.
> MIT-licensed.  ·  By Sakura Studios, IKE.

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

## The tools

| Repo | What it is |
|---|---|
| [**sakura-lslc**](https://github.com/Sakura-Studios-IKE/sakura-lslc) | Offline LSL Mono compiler in pure C99. gcc-style diagnostics ("did you mean?", carets, range underlines), full C-style preprocessor, LSO/Mono dual-target with memory-budget checking. Emits portable `.lslbc` bytecode. |
| [**sakura-slemu**](https://github.com/Sakura-Studios-IKE/sakura-slemu) | Headless Second Life region emulator. Runs `.lslbc` with the full LSL event loop, listen routing, link-message routing across linked scripts, L$ economy, linkset-data persistence, HUD/menu/dialog/chat simulation, HTTP backend (real `curl` or JSON fixture), project volume for cross-run state. |
| [**sakura-lsldb**](https://github.com/Sakura-Studios-IKE/sakura-lsldb) | gdb-style CLI debugger. Source-level breakpoints, single-step, print/locals/globals/backtrace, catchpoints on chat/money/dialog/etc., snapshot. Drives the emulator over a JSON line-protocol. |
| [**sakura-lsltest**](https://github.com/Sakura-Studios-IKE/sakura-lsltest) | Pytest-style test framework. `@compile_ok` / `@compile_fails` decorators, `@scene` fixture with `world.touch(...)`, `world.dialog_reply(...)`, `world.money_in(...)`, `world.http_in(...)`, plus rich post-run inspection. |
| [**sakura-intellij-lsl**](https://github.com/Sakura-Studios-IKE/sakura-intellij-lsl) | IntelliJ Platform plugin. Syntax highlighting, completion from the lslc built-in table, live diagnostics via background `lslc`, run configurations for slemu and lsltest, hot-reload via Firestorm's external-editor watch directory. |

## Get the whole toolchain in one go

```sh
git clone --recurse-submodules https://github.com/Sakura-Studios-IKE/sakura-lsl-toolchain.git
cd sakura-lsl-toolchain
make            # builds every C/C++ tool
make test       # runs every test suite across every tool
```

The `Makefile` at the root delegates to each subproject's own build system.
See [`INSTALL.md`](./INSTALL.md) for the from-scratch installation guide
including the IntelliJ plugin.

## Install pre-built packages

### Arch Linux (AUR)

```sh
yay -S sakura-lslc sakura-slemu sakura-lsldb sakura-lsltest
```

`-git` variants (`sakura-lslc-git`, …) follow `main`.

### IntelliJ plugin

In your IDE: **Settings → Plugins → Marketplace → search "Sakura LSL"**,
or download the latest zip from the
[plugin's GitHub Releases page](https://github.com/Sakura-Studios-IKE/sakura-intellij-lsl/releases)
and install via **Install Plugin from Disk…**.

### PyPI

```sh
pip install sakura-lsltest
```

### Pre-built binaries

Every tagged release publishes Linux / macOS / Windows binaries on the
GitHub Releases page of each tool.

## Headline numbers (last verified)

| Tool | Build status | Tests passing |
|---|---|---|
| sakura-lslc | clean | **30/30 acceptance + 82/82 language coverage** |
| sakura-slemu | clean | **3/3 e2e + 41/41 builtin/event coverage** |
| sakura-lsldb | clean | **10/10 lifecycle integration checks** |
| sakura-lsltest | n/a (Python) | **76/76 scenarios** |
| sakura-intellij-lsl | (Gradle build) | structure-complete, ~1700 LOC Kotlin |

**242 automated checks across the four runnable tools, all green.**

## Documentation

* [`INSTALL.md`](./INSTALL.md) — install all five tools from scratch on Arch / Debian / Ubuntu / macOS / Windows.
* [`COMPLETION_REPORT.md`](./COMPLETION_REPORT.md) — what was built, when, and what the headline coverage looks like.
* [`SL_COMPATIBILITY.md`](./SL_COMPATIBILITY.md) — exhaustive audit of where (if anywhere) the Sakura toolchain diverges from real Second Life behaviour, classified IDENTICAL / APPROXIMATED / STUBBED / DIVERGES.
* [`DEBUGGING_GUIDE.md`](./DEBUGGING_GUIDE.md) — the full developer-facing observability catalogue: every CLI flag, every JSON event type, every recipe.
* [`SAKURA_TOOLCHAIN_BRAND.md`](./SAKURA_TOOLCHAIN_BRAND.md) — landscape & positioning brief for the LSL tooling ecosystem.
* [`RELEASE.md`](./RELEASE.md) — how releases are cut and published across the five repos (AUR, PyPI, JetBrains Marketplace, GitHub Releases).

Per-tool reference docs live in each tool's own `DOCUMENTATION.md`.

## Author / Attribution

Authored and maintained by **Shiho Sakura**
([@ShihoSakura](https://github.com/ShihoSakura)) on behalf of
**Sakura Studios, IKE**.

The LSL language, built-in function set, constants, and event signatures
are © Linden Research, Inc. — referenced as factual data, nothing claimed
under licence.

## License

MIT — see [`LICENSE`](./LICENSE).
