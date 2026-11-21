# Tests

Verification is split into three layers, from fast to slow. The first two ship
with this repository and run in CI; the third is a set of local end-to-end UI
self-tests that need a macOS graphical session and live in the workspace
`.build/` directory, outside the repository.

## 1. Engine unit tests (Go)

```bash
make engine-test          # == cd imgtopdf && go test ./... -count=1 -v
```

`imgtopdf/engine_test.go` needs no fixture files; test images are generated in
memory with `image/jpeg`.

| Test | Coverage |
| --- | --- |
| `TestNaturalLessOrder` | Natural ordering: `photo2.jpg` before `photo10.jpg` |
| `TestPadJPEGTail` | Neutral entropy bytes inserted before EOI without damaging data |
| `TestDecodeImageRepairsTruncatedJPEG` | Reproduces a real bug: SOF height one MCU row longer than entropy data |
| `TestDecodeImageLeavesHealthyJPEGAlone` | Healthy images are not falsely marked as repaired |
| `TestClassifyDecodeError` | Error classification for HEIC / truncated JPEG / broken PNG |
| `TestProcessImageRespectsMaxEdge` | Long-edge scaling and per-page size budget |
| `TestWriteErrorReportNeverWritesPasswords` | No password in reports; stale report removed after a clean run |
| `TestRunJobEndToEnd` | 3 good + 1 bad image -> 3-page PDF, 1 warning, AES-256, bad page skipped only |

## 2. Static and build checks

```bash
make verify-version   # VERSION / App.swift / version.go / Info.plist agree
make fmt-check        # gofmt
make build            # Universal 2 .app + DMG + ZIP + ad-hoc signing
```

After building, verify architecture and signature:

```bash
APP=.build/app/ImageToEncryptedPDF.app
lipo -archs "$APP/Contents/MacOS/imgtopdf_ui"        # x86_64 arm64
lipo -archs "$APP/Contents/MacOS/imgtopdf-helper"    # x86_64 arm64
codesign -vvv "$APP"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"
```

CI (`.github/workflows/ci.yml`) runs all of the above on `macos-latest` and
uploads the DMG / ZIP as artifacts.

## 3. End-to-end UI self-tests (local, graphical session)

These scripts live in the workspace `.build/` directory and drive hidden
self-test branches in the app through environment variables — no manual
clicking. Main switches:

| Variable | Purpose |
| --- | --- |
| `IMGTOPDF_SELFTEST_SRC` | Input path (folder / ZIP / 7z / RAR) |
| `IMGTOPDF_SELFTEST_PASS` | Archive password |
| `IMGTOPDF_SELFTEST_PDFPASS` | PDF password |
| `IMGTOPDF_SELFTEST_OUT` | Output PDF path |
| `IMGTOPDF_SELFTEST_LANG=en` | English interface |
| `IMGTOPDF_SELFTEST_APPEARANCE=light\|dark` | Forced appearance |
| `IMGTOPDF_SELFTEST_SPLIT=0.62` | Splitter position |
| `IMGTOPDF_SELFTEST_NOPREVIEW=1` | Disable preview |
| `IMGTOPDF_SELFTEST_SHOWPASS=1` | Reveal passwords |
| `IMGTOPDF_SELFTEST_CONTEXT=1` | Context menu |
| `IMGTOPDF_SELFTEST_REORDER=1` | Drag reorder |
| `IMGTOPDF_SELFTEST_QUEUE=1` | Two parallel queue jobs |
| `IMGTOPDF_DEMO_SRC` | Demo mode for screenshots (does not exit) |
| `IMGTOPDF_DEMO_ABOUT=1` / `IMGTOPDF_DEMO_QUEUE=1` | Open About / queue window in demo mode |
| `IMGTOPDF_DEMO_I18N=1` | Demo mode: start Chinese, switch to English after 2 s |
| `IMGTOPDF_I18NTEST=<folder>` | Language-switch self-test: scan all visible text after switching, then exit |
| `IMGTOPDF_QUEUETEST=<folder>` | Queue self-test: append a job after start and verify scheduling |

Scripts:

| Script | Coverage |
| --- | --- |
| `.build/test_preview_toggle.py` | v2.1 preview toggle, 5 cases |
| `.build/test_v22.py` | v2.2 sorting / context menu / language / theme / password / slider / fit, 5 cases |
| `.build/test_v23.py` | v2.3 version badge / log pane / tooltip / JPEG repair / skipped-image report / parallel queue, 5 cases |
| `.build/test_v231.py` | v2.3.1 neutral engine events / English report / zero Chinese after language switch / late queue append, 4 cases |
| `.build/shots.py` | Real window screenshots via `CGWindowListCopyWindowInfo` + `screencapture -l` |

`test_v23.py` uses `pypdf` to check page count and password, and asserts that
reports never contain passwords and are not written on a clean run. Install
`python3 -m pip install pypdf pillow` first.

## Manual acceptance checklist

- [ ] Run one real 2–3 GB encrypted RAR; confirm output <= target and opens on a phone.
- [ ] With a PDF password set, a wrong password fails and the right one opens it.
- [ ] No button text is clipped in any of the four English/Chinese x light/dark combinations.
- [ ] Disabling preview creates no temporary thumbnail files.
- [ ] No password fields appear in `~/Library/Preferences` after quitting the app.
