# Image to Encrypted PDF

![Version](https://img.shields.io/badge/version-2.3.1-blue)
![Platform](https://img.shields.io/badge/macOS-11%2B-lightgrey)
![Arch](https://img.shields.io/badge/arch-arm64%20%7C%20x86__64-green)
![License](https://img.shields.io/badge/license-MIT-orange)
![Offline](https://img.shields.io/badge/network-none-success)

A **fully native macOS app** that turns hundreds of photos inside an encrypted
archive into one small, password-protected PDF for sharing on WeChat — without
uploading anything anywhere.

> 2–3 GB of images → a ~20 MB PDF, on your Mac, in under a minute.

[Chinese README](README.zh-CN.md) · [Changelog](CHANGELOG.md) ·
[Contributing](CONTRIBUTING.md) · [Security](SECURITY.md) · [Tests](tests/README.md) ·
[Code of Conduct](CODE_OF_CONDUCT.md)

All repository documentation is in English. The app itself ships English and
Simplified Chinese interfaces; the translation tables are product data, not
repository prose. Archived code under `legacy/` is kept verbatim.

---

## Why this exists

A 2.8 GB archive with 212 photos cannot be sent over WeChat, and a plain PDF
made from it is still huge. This app reads the archive directly, scales and
re-encodes every image to a per-image byte budget derived from the target size,
embeds each JPEG losslessly into a PDF whose pages follow the image aspect
ratio (no A4 white borders), and encrypts the result with AES-256.

Everything runs locally. The UI is Swift/AppKit; the engine is a Go helper
spawned as a child process. They exchange JSON lines on stdout. There is no
browser, no local HTTP server and no network code.

## Features

- **Encrypted input**: 7z, ZIP (AES) and RAR / RAR5 (including header
  encryption) are read directly. Passwords are used in memory only.
- **Your order**: drag rows, use the four move buttons or the context menu to
  pin, move, remove or reverse images. The list order *is* the PDF page order.
- **Preview & location**: click a row to see the image (EXIF auto-rotated),
  its original dimensions, size and full path inside the archive; copy the path
  or reveal it in Finder. Preview can be switched off entirely.
- **Precise size control**: set a target in MB; the engine computes a per-image
  budget and binary-searches the highest JPEG quality that fits.
- **Parallel**: image work runs in a bounded worker pool, and several
  independent jobs can run at once from the Task Queue window.
- **Resilient**: truncated JPEGs are repaired automatically; an unrecoverable
  image only skips its own page, never aborts the batch. A diagnostic `.log`
  report can be written next to the output on failure.
- **PDF encryption**: PDF 2.0 AES-256 (R=6) open password, implemented in pure Go.
- **Bilingual & themed**: English / Simplified Chinese UI, system / light / dark
  appearance, draggable list–preview splitter and draggable log pane.

## Install

Download `ImageToEncryptedPDF_macOS.dmg` from Releases, open it and drag the app into
Applications. On first launch use **right-click → Open → Open** (the binary is
ad-hoc signed, not notarised with a Developer ID).

Both archives contain an ASCII bundle name, `ImageToEncryptedPDF.app`, so
third-party unarchivers cannot mangle it. Finder may still show a localized
display name from `CFBundleDisplayName`; that is a shipped product feature.

Requires macOS 11+. The bundle is Universal 2: native on Apple Silicon
(M1–M4) and Intel, no Rosetta needed. Verify with:

```bash
lipo -archs "/Applications/ImageToEncryptedPDF.app/Contents/MacOS/imgtopdf_ui"
# x86_64 arm64
```

## Build from source

```bash
make build        # bash macapp/build_macos.sh
make engine-test  # engine-level regression tests
```

Needs macOS with Xcode command line tools, Go 1.22+, and Python 3 + Pillow for
the optional app icon. By default build artefacts land in `.build/` and
`outputs/` inside the checkout; override with `IMGTOPDF_ROOT` / `IMGTOPDF_OUT`
if you keep them elsewhere. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
layout and versioning rules. The abandoned v1 browser UI is kept, unbuilt, in
[`legacy/`](legacy/README.md).

## Architecture

```
Swift / AppKit  (macapp/App.swift)
  native window · list · preview · queue
        | child process, JSON lines on stdout
Go engine  (imgtopdf/)
  list · thumb · build -> progress/log/result
  archive -> decode/repair -> scale -> JPEG
  -> PDF (fit pages) -> AES-256 encrypt
```

`build` also accepts a CLI form, useful for automation:

```bash
imgtopdf-helper build \
  --src "photos.rar" --archive-pass '...' \
  --out "out.pdf" --pdf-pass '...' \
  --target-mb 20 --max-edge 1600 --quality 82 \
  --page fit --workers 4 --error-log "out_error_report.log"
```

## Localization

All user-visible strings live in the `ZH` / `EN` dictionaries at the top of
`macapp/App.swift` — the single source of truth. `Lang.allCases` drives the
language picker, the saved preference, and the `--lang` value handed to the
helper. The Go engine never produces UI-ready text: it emits language-neutral
`{key, args}` events (`imgtopdf/msg.go`) that the UI resolves at render time.
Log lines are stored as renderers instead of rendered strings, so a language
switch re-translates the entire history, including past engine messages. An
English interface contains no Chinese characters at all.

To add a language: add one case to `Lang`, one dictionary to `STRINGS`, and the
matching `lang.*` display names. No other code changes are needed.

Generated file names follow the interface language as well (for example
`_encrypted` / `_error_report.log` in English) and refresh on a switch, but a
name the user typed or picked is never overwritten.

## Task queue at any time

The primary button becomes **Add to Queue** while a conversion is running, the
queue window has a permanent **Add Current Job** button, and enqueuing opens the
queue window for feedback. Jobs appended after the queue has started are picked
up automatically; output names are made unique so two processes never write the
same PDF.

## Benchmark

212 photos, 2.8 GB RAR5, target 20 MB, Apple M4:

| Workers | Time | Output | Notes |
| --- | --- | --- | --- |
| 1 | 150.2 s | 18.8 MB / 212 pages | 1 truncated JPEG repaired |
| 4 | **44.1 s** | 18.8 MB / 212 pages | 3.4× faster, 400% CPU |

## Known limitations

- HEIC/HEIF and AVIF are not decodable by the pure-Go engine — convert to JPEG.
- 7z archives that also encrypt file names, split RAR volumes, and encrypted
  PDFs inside WeChat's built-in preview may need workarounds.
- No linearization yet; very large PDFs may download before displaying on phones.
- The Windows build is still the older browser-UI version and is not actively
  developed in this branch.

## Privacy

No telemetry, no analytics, no network requests, no cloud. Passwords are never
logged or written to reports. See [SECURITY.md](SECURITY.md).

## License

MIT © 2026 aibanana. See [LICENSE](LICENSE).
