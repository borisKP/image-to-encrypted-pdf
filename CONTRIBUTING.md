# Contributing

Thanks for taking the time to contribute. This project is small and deliberately
dependency-light; please keep it that way.

## Repository layout

| Path | What it is |
| --- | --- |
| `macapp/App.swift` | Entire native macOS UI (Swift / AppKit). No storyboards, no SwiftUI, no WebView. |
| `macapp/build_macos.sh` | Reproducible build: Go helper + Swift UI, Universal 2, ad-hoc signing, DMG/ZIP. |
| `macapp/Info.plist` | Bundle metadata. Version fields are overwritten from `VERSION` at build time. |
| `imgtopdf/*.go` | Processing engine: archive decryption, image decode/repair, PDF assembly, AES-256 encryption, JSON-lines bridge. |
| `imgtopdf/msg.go` | Language-neutral `{key, args}` events. The helper never hard-codes UI text. |
| `imgtopdf/engine_test.go` | Self-contained Go unit + end-to-end tests (no fixture files needed). |
| `legacy/browser-ui/` | Abandoned v1 browser UI, **not built**. See [`legacy/README.md`](legacy/README.md). |
| `VERSION` | Single source of truth for the release version. |
| `Makefile` | `verify-version` / `fmt-check` / `engine-test` / `build` / `clean`. |
| `tests/README.md` | Test layers, environment switches and manual acceptance checklist. |
| `docs/screenshots/` | Real UI screenshots: Chinese/English x light/dark, queue and About panels. |
| `.github/` | Issue / PR templates and the macOS CI workflow. |
| `README.md` | Single bilingual README: Chinese first, then English. |

The UI launches the Go helper as a child process and talks over stdout, one JSON
object per line (`list`, `thumb`, `build`, `progress`, `log`, `report`, `result`,
`error`). `log` and `error` events carry a localization `key` plus `args`; the
UI owns every translation (`ZH` / `EN` dictionaries at the top of `App.swift`)
and re-renders the whole log history when the language changes. No HTTP server
and no network socket are involved.

Adding a language takes one `Lang` case and one dictionary; see the
"Localization" section of README.md.

## Build requirements

- macOS 11+ with Xcode command line tools (`xcrun`, `swiftc`, `codesign`, `lipo`)
- Go 1.22 or newer
- Python 3 with Pillow (optional, only for generating the app icon)

```bash
git clone <your-fork>
cd <repo>
make build          # == bash macapp/build_macos.sh
make engine-test     # fast engine-level checks
```

`make build` verifies that `VERSION`, `App.swift` and `version.go` agree and
fails early if they drift.

## Changing the version

1. Edit `VERSION` (e.g. `2.4.0`).
2. Update `UIAppVersion` / `UIAppVersionShort` at the top of `macapp/App.swift`.
3. Update `AppVersion` in `imgtopdf/version.go`.
4. Add a section to `CHANGELOG.md`.
5. Run `make build` — the script validates all three constants and injects the
   value into `Info.plist`.

## Coding conventions

- Go: `gofmt` is mandatory; no new third-party runtime binaries at app startup.
- Swift: classic AppKit delegate pattern. **Do not** annotate `AppController`
  or `RootView` with `@MainActor` — the run loop occupies the main actor and
  child-process callbacks stop being delivered (this was a real bug in 2.0).
- User-facing strings go into the `ZH` / `EN` dictionaries and are read through
  `L(key)`. Never hard-code a visible string outside those tables.
- Passwords must never be logged, persisted, or written into error reports.
- Archive entries must be read **sequentially** (RAR/7z decoders keep shared
  state); only CPU work may be parallelised.

## Pull requests

- Describe the problem and how you verified the fix (a real archive is best).
- Run `make engine-test` and, when touching the UI, the `IMGTOPDF_SELFTEST_*`
  harness described in `tests/README.md`.
- Keep commits focused; one logical change per commit.
- By opening a PR you agree your contribution is licensed under MIT.

## Reporting bugs

Use the bug report template. Please attach the generated `*_error_report.log` when
available, but **remove private paths and file names first** — the report
records source/output paths by design, but never passwords.
