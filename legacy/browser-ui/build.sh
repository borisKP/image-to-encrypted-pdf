#!/bin/sh
# Rebuild both platform binaries. Requires Go 1.22+ (lipo needs macOS).
set -e
cd "$(dirname "$0")"
ROOT=$(pwd)
export CGO_ENABLED=0
OUT="$ROOT/../../outputs"
mkdir -p "$OUT" /tmp/imgtopdf-build

GOOS=windows GOARCH=amd64 go build -trimpath -ldflags="-s -w -H=windowsgui" \
  -o "$OUT/ImageToEncryptedPDF_Windows.exe" .

GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags="-s -w" \
  -o /tmp/imgtopdf-build/arm64 .
GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags="-s -w" \
  -o /tmp/imgtopdf-build/amd64 .
lipo -create -output /tmp/imgtopdf-build/universal \
  /tmp/imgtopdf-build/arm64 /tmp/imgtopdf-build/amd64
chmod +x /tmp/imgtopdf-build/universal

APP=/tmp/imgtopdf-build/ImageToEncryptedPDF.app/Contents
mkdir -p "$APP/MacOS" "$APP/Resources"
cp /tmp/imgtopdf-build/universal "$APP/MacOS/imgtopdf"
cp Info.plist "$APP/Info.plist"
(cd /tmp/imgtopdf-build && zip -qry "$OUT/ImageToEncryptedPDF_Mac.zip" "ImageToEncryptedPDF.app")

echo "Built: $OUT/ImageToEncryptedPDF_Windows.exe"
echo "Built: $OUT/ImageToEncryptedPDF_Mac.zip"
