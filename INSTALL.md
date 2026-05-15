# Installation guide — Sakura LSL Toolchain

Five tools, one workflow. This walk-through gets you from a fresh
machine to a green test suite.

## TL;DR

```sh
# 1. Clone the meta-repo and all five tools as submodules
git clone --recurse-submodules https://github.com/Sakura-Studios-IKE/sakura-lsl-toolchain.git
cd sakura-lsl-toolchain

# 2. Build everything (C tools) and install lsltest (Python)
make
make install-lsltest

# 3. Run the full cross-tool test matrix
make test
```

If the above worked, you're done. The rest of this document covers
toolchain prerequisites, the IntelliJ plugin, and per-OS quirks.

---

## Prerequisites

| What | Why | Install (Arch) |
|---|---|---|
| `gcc` or `clang`, `make` | sakura-lslc, sakura-slemu, sakura-lsldb (C99) | `sudo pacman -S base-devel` |
| `python3` ≥ 3.9 | sakura-lsltest framework + CLI | `sudo pacman -S python` |
| `curl` (optional) | sakura-slemu `--http-real` mode | `sudo pacman -S curl` |
| JDK 17+ + Gradle 8.7+ (optional) | sakura-intellij-lsl build | `sudo pacman -S jdk17-openjdk gradle` |

On macOS: `brew install gcc make python3` plus `brew install gradle openjdk@17` if you want to build the plugin.

On Debian/Ubuntu: `sudo apt install build-essential python3 curl` plus `sudo apt install openjdk-17-jdk gradle` for the plugin.

On Windows: install MSYS2 or MinGW + Python from python.org. IntelliJ plugin build is simplest via WSL.

---

## Step-by-step

### 1. Get the source

```sh
git clone --recurse-submodules https://github.com/Sakura-Studios-IKE/sakura-lsl-toolchain.git
cd sakura-lsl-toolchain
```

The five tools are git submodules under their own directories. If you forgot `--recurse-submodules`:

```sh
git submodule update --init --recursive
```

### 2. Build the C tools

```sh
make            # builds sakura-lslc, sakura-slemu, sakura-lsldb
```

Or build them individually:

```sh
make -C sakura-lslc     # produces sakura-lslc/lslc
make -C sakura-slemu    # produces sakura-slemu/slemu
make -C sakura-lsldb    # produces sakura-lsldb/lsldb
```

### 3. Install sakura-lsltest (Python)

```sh
make install-lsltest    # equivalent to: pip install -e sakura-lsltest

# (Optional) install the lsltest CLI globally
pip install -e sakura-lsltest
which lsltest
```

### 4. (Optional) Build & install the IntelliJ plugin

```sh
cd sakura-intellij-lsl
./gradlew buildPlugin
# Output: build/distributions/sakura-lsl-1.0.0.zip
```

Then in IntelliJ: **Settings → Plugins → ⚙ → Install Plugin from Disk… → pick the zip**.

After install, configure Tool paths under **Settings → Tools → Sakura LSL**:

* `lslc path` — point at your `sakura-lslc/lslc` binary
* `slemu path` — `sakura-slemu/slemu`
* `lsltest path` — `lsltest` (if installed in PATH) or `python3 -m lsltest`
* `Firestorm watch dir` — your Firestorm "external editor" target directory (optional, for hot reload)

### 5. (Optional) Install binaries system-wide

```sh
sudo make -C sakura-lslc install     # /usr/local/bin/lslc
sudo make -C sakura-slemu install    # /usr/local/bin/slemu
sudo make -C sakura-lsldb install    # /usr/local/bin/lsldb
```

### 6. Verify everything

```sh
make test
```

Expected output (numbers may grow over time):

```
═══ sakura-lslc ═══
  Result: 30 passing / 30 tests
  Coverage: ALL GREEN: 82 / 82 tests passed

═══ sakura-slemu ═══
  e2e: Result: 3 passing / 3 e2e tests
  coverage: Coverage result: 41 / 41 scenarios passing

═══ sakura-lsldb ═══
  All lsldb integration checks passed.

═══ sakura-lsltest ═══
  Result: 76 passing / 76 tests
```

---

## Try it

```sh
# Compile your first LSL script
echo 'default { state_entry() { llOwnerSay("hello sakura"); } }' > hello.lsl
sakura-lslc/lslc -c hello.lsl

# Run it in the emulator
sakura-slemu/slemu --volume /tmp/sakura_demo hello.lslbc

# Debug it line by line
echo -e 'break 1\ncontinue\nlocals\nquit' | sakura-lsldb/lsldb -- --volume /tmp/sakura_demo hello.lslbc
```

---

## Troubleshooting

* **"lslc: command not found"** — either run from the toolchain root with explicit paths, or `sudo make install` in each tool's directory.
* **"slemu: cannot load script.lslbc"** — your `.lslbc` was produced by an older version. Re-run `lslc -c` after rebuilding the compiler. Bytecode is currently at SLBC v2.
* **IntelliJ plugin doesn't see lslc** — open **Settings → Tools → Sakura LSL** and set the absolute paths.
* **Hot reload doesn't reload in SL** — slemu can't authenticate against the SL grid. The plugin writes to the Firestorm watch directory (configured in Firestorm: **Preferences → Build → External Editor**). Make sure Firestorm is running with that path configured. As a fallback, the **Copy Script to Clipboard** action lets you paste manually.

---

## License

MIT — see [`LICENSE`](./LICENSE).

By Sakura Studios, IKE.
