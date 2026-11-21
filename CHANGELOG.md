# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The authoritative
version string lives in [`VERSION`](VERSION).

## [2.3.1] - 2026-11-08

### Fixed
- **Language leakage.** Switching the interface to English could still leave
  Chinese behind: the generated output name was hard-coded to
  a hard-coded localized output suffix, the log pane stored already-rendered Chinese lines, the
  status line / About panel / completion row / fallback errors contained
  literal Chinese, and the Go helper emitted all progress and error text in
  Chinese. An English interface now contains no Chinese characters at all,
  including the language picker labels.
- **Queued jobs stuck in "Waiting".** `addJob` never woke the scheduler, so a
  job appended after "Start Queue" stayed pending until Start Queue was pressed
  again. The queue now stays in started mode and picks up late jobs at once.
- Two processes could target the same output path when a job was queued while
  another was already running. Enqueued output names are now made unique
  (`_2`, `_3`, ...) and the report path follows suit.
- `make fmt-check` silently passed when `gofmt` was not on `PATH`. The Makefile
  now resolves the Go toolchain the same way as the build script (vendored SDK
  in the parent workspace, else `PATH`) and fails loudly when it is absent.

### Added
- Table-driven localization with a single dictionary source. `Lang.allCases`
  drives the picker, the saved preference, and the `--lang` value handed to the
  helper. Adding a language takes one enum case and one dictionary — no other
  code changes.
- The Go helper now emits language-neutral `{key, args}` events. The UI renders
  them and re-renders the entire log history on a language switch, so even
  past engine messages change language. Templates use numbered `{0}`
  placeholders so future languages can reorder arguments freely.
- Generated output and report suffixes follow the interface language
  (localized suffixes such as `_encrypted` / `_error_report.log`) and
  refresh on a language switch, but never overwrite a name the user typed.
- The on-disk diagnostic report is written in the interface language.
- **Three ways to enqueue a job at any time**: the primary button becomes
  "Add to Queue" while a conversion runs, the queue window has a permanent
  "Add Current Job" button, and enqueuing opens the queue window for feedback.
- Hidden self-tests `IMGTOPDF_I18NTEST` / `IMGTOPDF_QUEUETEST` plus
  `.build/test_v231.py`, covering engine events, full UI re-localization,
  English reports, and late job scheduling.

### Changed
- Version is now 2.3.1; `VERSION` remains the single source of truth and is
  validated against both compiled constants at build time.

## [2.3.0] - 2026-11-07

### Fixed
- A real-world crash on `Yeha (예하) - Pure.rar`: one JPEG's entropy stream was
  short by about one MCU row. Go's strict `image/jpeg` rejected the trailing
  `FF D9` with `invalid JPEG format: missing 0xff00 sequence`, while libjpeg
  based viewers displayed the photo fine. The error message wrongly blamed
  HEIC/HEIF. A truncated JPEG is now repaired by inserting neutral bytes before
  EOI and kept in the PDF; if repair still fails, only that page is skipped
  instead of aborting all 212 pages.
- Error messages are now classified (unsupported format / incomplete JPEG /
  damaged PNG or WebP / decryption failure) instead of a single misleading hint.
- Selecting an encrypted archive no longer fires a premature password-less
  list request that produced a bogus "password required" log line.

### Added
- Version badge in the main window and a proper About panel showing version
  `2.3.0` and `Developer: aibanana`.
- Draggable log pane (48–320 pt, double-click to reset) with colour-coded
  status: green success, red failure, orange skipped/repaired.
- Optional diagnostic report written next to the output PDF when a job fails
  or pages are skipped. Never written on a clean run; never contains passwords.
- Tooltip on the long-edge field explaining what it does and how to choose a
  value for photos versus documents with fine print.
- **Task queue window**: enqueue several independent jobs and run them in
  parallel (1–4 at once), each with its own progress, output and failure state.
- GitHub-ready repository layout: README (English), LICENSE, CHANGELOG,
  CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, issue/PR templates, CI workflow,
  Makefile and test documentation.
- Eight self-contained Go tests (`imgtopdf/engine_test.go`) covering natural
  sorting, JPEG tail repair, error classification, size budgets, the
  no-password-in-report guarantee, and an end-to-end "one bad photo only skips
  its own page" job.
- macOS CI (`ci.yml`) runs version checks, `gofmt`, `go vet`, engine tests, a
  Universal 2 build, architecture/signature/bundle-version verification, and
  uploads the DMG/ZIP as artifacts.
- Single source of truth for the version: `VERSION` is validated against the
  compiled Swift/Go constants and injected into `Info.plist` at build time.

### Changed / Performance
- Image decoding, scaling and encoding now run in a bounded worker pool while
  archive entries are still read sequentially (RAR/7z readers are stateful).
  Results are stored by index, so PDF page order is preserved exactly.
- `encodeTarget` learns the quality that satisfied the previous image, cutting
  a 6–7 step binary search to 1–2 encodes for typical batches.
- Transparency is flattened onto the scaled image instead of allocating a
  full-resolution RGBA copy (~96 MB for a 4000×6000 photo) per page.
- Real-world benchmark, 212 photos / 2.8 GB RAR / target 20 MB on Apple M4:
  **150.2 s with 1 worker → 44.1 s with 4 workers (3.4× faster)**, 18.8 MB,
  212 pages, one truncated JPEG repaired.
- `build_macos.sh` is now location-independent: it resolves sources relative to
  itself and accepts `IMGTOPDF_ROOT` / `IMGTOPDF_OUT`, so a fresh GitHub clone
  builds with a plain `make build` and no hard-coded workspace path.
- The abandoned v1 browser UI (`web.go`, `ui.html`, old build script, duplicate
  LICENSE and stale `Info.plist`) was moved to `legacy/browser-ui/` and is no
  longer compiled. `main.go` prints usage instead of starting an HTTP server
  when launched without a subcommand. Removing `net/http` also shrank the
  helper binary and the installers by roughly 1.5 MB.
- The ZIP now contains an ASCII bundle name (`ImageToEncryptedPDF.app`) so
  Windows and third-party unarchivers do not mangle it; Finder still shows the
  Chinese name via `CFBundleDisplayName`. The DMG keeps the Chinese name.

## [2.2.0] - 2026-11-07

- Drag-to-reorder image list with top/up/down/bottom buttons and a full context
  menu; list order is the PDF page order, and removed images are skipped.
- Draggable splitter between list and preview; bilingual (English / Simplified Chinese) UI;
  light/dark/system appearance switch; show-password toggles.
- Quality slider with six named grades instead of a number field.
- PDF pages now follow each image's aspect ratio with zero margins (`fit`),
  replacing the old A4-with-white-borders default.

## [2.1.0] - 2026-11-07

- Image preview can be switched off completely (no decoding, no temp files)
  while location information stays available. State is persisted.
- Verified Universal 2 binaries (`x86_64` + `arm64`), native on Apple Silicon.

## [2.0.0] - 2026-11-07

- First fully native macOS AppKit application (no browser, no local HTTP
  server, no network).
- Direct reading of encrypted 7z / ZIP / RAR (including RAR5 and header
  encryption), image preview and per-image path/location information.

## [1.0.0] - 2026-11-06

- Initial cross-platform browser-UI prototype (Windows EXE and macOS app),
  Go engine with AES-256 PDF encryption and size-targeted JPEG compression.
