# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 2.3.x | ✅ |
| 2.2 and older | ❌ |

## Design guarantees

- **Offline by design.** The app contains no network client. The UI and the
  processing engine communicate through a local child process over stdout.
- **Passwords stay in memory.** The archive password and PDF password are passed
  as arguments to the local helper and are never written to disk, never logged,
  and never included in diagnostic reports. Reports record only whether a
  password was set.
- **No temporary full-size images.** Previews are downscaled JPEGs in a
  per-process temp directory that is removed on exit. Originals are never
  extracted to disk.
- **PDF encryption** is implemented in Go as PDF 2.0 AES-256 (R=6), with a
  user (open) password. An owner password is derived from it; there is no
  separate permissions policy yet.

## Reporting a vulnerability

Please **do not** open a public issue for a security problem. Open a private
security advisory on the repository (Security → Report a vulnerability) or
contact the maintainer directly. Include:

- the version and macOS version,
- a minimal reproduction (a small archive is ideal; please never send real
  passwords or private photos),
- the expected versus observed behaviour.

You should receive an acknowledgement within 7 days. Once a fix is available,
the release notes in `CHANGELOG.md` will describe the issue without exposing
reporter details.

## Known limitations

- The binaries are ad-hoc signed, not notarised with an Apple Developer ID.
  macOS Gatekeeper will ask for a manual "Open" on first launch.
- Encrypted PDFs may not render inside WeChat's built-in preview; download and
  open with a dedicated PDF reader if that happens.
- HEIC/HEIF and AVIF are not supported by the pure-Go decoder; convert them to
  JPEG first.
- The archive/PDF passwords are passed to the local helper as command-line
  arguments. They never touch disk, but on a **shared multi-user Mac** another
  local account could in principle see them in a process listing. Use a private
  macOS account when handling sensitive archives.
- Diagnostic reports record source/output paths and file names. Remove those
  before attaching a report to a public issue; passwords are never recorded.
