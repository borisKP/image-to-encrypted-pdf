# Legacy code

This directory holds earlier implementations that **no longer take part in the
current build**. It is kept for reference so new contributors do not assume the
project maintains two interfaces.

## `browser-ui/` (v1.0, unmaintained)

The first version combined the Go engine with a local browser UI: launching the
app started an HTTP service on `127.0.0.1` and opened a browser. Users reported
that they "still had to open a web page", so from v2.0 onward the app uses a
native Swift/AppKit window. **The current app starts no browser, listens on no
port and contains no networking code.**

| File | What it is |
| --- | --- |
| `web.go` | Old local HTTP service and `/api/*` handlers (including `serveUI`). |
| `ui.html` | Old browser UI, formerly embedded with `//go:embed`. |
| `build.sh` | Old cross-build script (Windows EXE plus the old Mac bundle). |
| `Info.plist` | Metadata of the old browser-shell app, frozen at 1.0.0. |
| `LICENSE` | Duplicate MIT copy in the old source tree; **only the root [`LICENSE`](../LICENSE) applies**. |

These files are deliberately excluded from `make build` and `go test ./...`:
`web.go` is outside the `imgtopdf/` package, and `main.go` prints usage instead
of starting an HTTP server when called without a subcommand.

### Restoring the Windows build later

The native Windows edition is on hold. To reuse the old browser UI:

1. Copy `web.go` and `ui.html` back into `imgtopdf/`.
2. Restore the `serveUI(...)` call in the default branch of
   `imgtopdf/main.go` (currently it prints `usage`).
3. Cross-compile with the `GOOS=windows` flow in `build.sh`.
4. Prefer a separate `windows/` branch or directory; do not let the old web UI
   back into the macOS main build.

## Compatibility notes

- The old Windows EXE still runs on its own, unrelated to the current build chain.
- The `1.0.0` in the old `Info.plist` is historical, **not** the current
  version; the root [`VERSION`](../VERSION) is authoritative.
