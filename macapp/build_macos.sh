#!/bin/bash
# Rebuild the native macOS app from source (Universal 2).
# Needs macOS + Xcode command line tools (swiftc / codesign / iconutil / lipo) + Go 1.22+.
# Runs entirely offline; the result has no third-party runtime dependency.
#
# Layout:
#   SRCROOT      parent of this script: the source root with VERSION / macapp / imgtopdf
#   WORKROOT     destination for build intermediates and outputs; defaults to SRCROOT
#                (set IMGTOPDF_ROOT to point back at an outer workspace)
#   IMGTOPDF_OUT optional, separate output directory for the DMG / ZIP
set -euo pipefail

SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKROOT="${IMGTOPDF_ROOT:-$SRCROOT}"
OUT="${IMGTOPDF_OUT:-$WORKROOT/outputs}"
BUILD="$WORKROOT/.build/bin"
APPROOT="$WORKROOT/.build/app"
APP="$APPROOT/ImageToEncryptedPDF.app"

if command -v go >/dev/null 2>&1; then
    GO=go
elif [ -x "$WORKROOT/.build/go/bin/go" ]; then
    GO="$WORKROOT/.build/go/bin/go"
else
    echo "Go toolchain not found; install Go first" >&2
    exit 1
fi

mkdir -p "$BUILD" "$OUT" "$APPROOT"
export CGO_ENABLED=0
export IMGTOPDF_BUILD="$WORKROOT/.build"

# Single source of truth: VERSION. Fail early if any compiled constant drifts,
# so a release can never ship mismatched version strings.
VERSION="$(tr -d '[:space:]' < "$SRCROOT/VERSION")"
if [ -z "$VERSION" ]; then echo "VERSION is empty" >&2; exit 1; fi
if ! grep -q "UIAppVersion = \"$VERSION\"" "$SRCROOT/macapp/App.swift"; then
    echo "version drift: App.swift != VERSION ($VERSION)" >&2; exit 1
fi
if ! grep -q "AppVersion = \"$VERSION\"" "$SRCROOT/imgtopdf/version.go"; then
    echo "version drift: version.go != VERSION ($VERSION)" >&2; exit 1
fi
echo "source  : $SRCROOT"
echo "output  : $OUT"
echo "version : $VERSION"

echo "[1/5] Build Go engine (arm64 + amd64)"
(
    cd "$SRCROOT/imgtopdf"
    GOOS=darwin GOARCH=arm64 "$GO" build -trimpath -ldflags="-s -w" -o "$BUILD/helper_arm64" .
    GOOS=darwin GOARCH=amd64 "$GO" build -trimpath -ldflags="-s -w" -o "$BUILD/helper_amd64" .
)

echo "[2/5] Build native AppKit UI (arm64 + x86_64)"
xcrun swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macosx11.0 \
    -o "$BUILD/ui_arm64" "$SRCROOT/macapp/App.swift"
xcrun swiftc -O -swift-version 5 -parse-as-library -target x86_64-apple-macosx11.0 \
    -o "$BUILD/ui_x86_64" "$SRCROOT/macapp/App.swift"
lipo -create "$BUILD/ui_arm64" "$BUILD/ui_x86_64" -output "$BUILD/ui_universal"
lipo -create "$BUILD/helper_arm64" "$BUILD/helper_amd64" -output "$BUILD/helper_universal"

echo "[3/5] Generate app icon (optional, needs Pillow)"
if /usr/bin/python3 -c "import PIL" 2>/dev/null; then
    /usr/bin/python3 "$SRCROOT/macapp/make_icon.py" || true
elif [ -x "$WORKROOT/.build/venv/bin/python" ]; then
    "$WORKROOT/.build/venv/bin/python" "$SRCROOT/macapp/make_icon.py" || true
fi

echo "[4/5] Assemble .app and sign ad-hoc"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/ui_universal" "$APP/Contents/MacOS/imgtopdf_ui"
cp "$BUILD/helper_universal" "$APP/Contents/MacOS/imgtopdf-helper"
chmod +x "$APP/Contents/MacOS/"*
cp "$SRCROOT/macapp/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
if [ -f "$WORKROOT/.build/AppIcon.icns" ]; then
    cp "$WORKROOT/.build/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
codesign --force -s - "$APP/Contents/MacOS/imgtopdf-helper"
codesign --force --deep -s - "$APP"
codesign -vvv "$APP" 2>&1 | tail -2

echo "[5/5] Package DMG and ZIP"
# Keep an ASCII bundle name in both archives so Windows and third-party
# unarchivers do not mangle it. Finder may show a localized display name from
# CFBundleDisplayName; that is part of the shipped product.
ZIPSTAGE="$WORKROOT/.build/zipstage"
rm -rf "$ZIPSTAGE"
mkdir -p "$ZIPSTAGE"
cp -R "$APP" "$ZIPSTAGE/ImageToEncryptedPDF.app"
(cd "$ZIPSTAGE" && ditto -c -k --sequesterRsrc --keepParent ImageToEncryptedPDF.app \
    "$OUT/ImageToEncryptedPDF_macOS.zip")
STAGE="$WORKROOT/.build/dmgstage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "ImageToEncryptedPDF" -srcfolder "$STAGE" -ov -format UDZO \
    "$OUT/ImageToEncryptedPDF_macOS.dmg" >/dev/null

echo "done:"
ls -lh "$OUT/ImageToEncryptedPDF_macOS.dmg" "$OUT/ImageToEncryptedPDF_macOS.zip"
