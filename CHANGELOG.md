# sakura-lsl-toolchain — Changelog

All notable changes are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [SemVer](https://semver.org/).
The `[Unreleased]` section is what's on `main`; the release pipeline
promotes it to a numbered version on tag.

## [Unreleased]

## [1.0.0] — 2026-05-15

### Added
- Initial release of the Sakura LSL toolchain umbrella repo: a single
  super-project that pulls together the five component repos as git
  submodules — `sakura-lslc`, `sakura-slemu`, `sakura-lsldb`,
  `sakura-lsltest`, and `sakura-intellij-lsl` (see `.gitmodules`).
- Top-level `Makefile` that builds, tests, and installs every
  component with one invocation.
- `INSTALL.md` with end-to-end setup instructions across Linux,
  macOS, and Windows (WSL).
- `DEBUGGING_GUIDE.md` walking through compile-run-debug across
  `lslc` -> `slemu` -> `lsldb`, plus how the IntelliJ plugin wires
  the same flow.
- `SL_COMPATIBILITY.md` documenting Sakura's compatibility with the
  Linden / Firestorm LSL implementation: covered builtins, behavioural
  differences, and known gaps.
- `SAKURA_TOOLCHAIN_BRAND.md` covering the project's naming, scope,
  and component boundaries.
- `COMPLETION_REPORT.md` summarising the v1.0.0 milestone.
