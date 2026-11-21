## What

<!-- One-line summary. Link the issue: Closes #___ -->

## Why

<!-- Background; for bugs, include a minimal reproduction. -->

## How verified

- [ ] `make verify-version`
- [ ] `make engine-test` (`cd imgtopdf && go test ./...`)
- [ ] The .app produced by `make build` launches
- [ ] One real end-to-end conversion was run
- [ ] If the UI changed: both languages and both light/dark themes checked
- [ ] If the PDF output changed: page count and password verified with pypdf / MuPDF or on a phone

Measured results (image count, source size, target size, output size, elapsed time):

```
Paste logs or self-test output
```

## Checklist

- [ ] Go code is `gofmt`-clean
- [ ] User-visible strings live in the `ZH` / `EN` dictionaries and are read through `L(key)`
- [ ] `AppController` / `RootView` are **not** annotated `@MainActor`
- [ ] No password is written to logs, UserDefaults or error reports
- [ ] Archive entries are still read sequentially; only CPU work is parallel
- [ ] No networking code, WebView or local HTTP server was introduced
- [ ] If the version changed: `VERSION`, `App.swift`, `version.go` and `CHANGELOG.md` are in sync
- [ ] No private photos, archives, passwords or build outputs were committed

Opening a PR means you agree to license your contribution under MIT.
