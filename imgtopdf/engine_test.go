package main

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// testJPEG builds a small deterministic gradient JPEG so tests never depend on
// fixture files in the repository.
func testJPEG(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			img.Set(x, y, color.RGBA{
				R: uint8(x * 255 / w),
				G: uint8(y * 255 / h),
				B: uint8((x + y) * 255 / (w + h)),
				A: 255,
			})
		}
	}
	var b bytes.Buffer
	if err := jpeg.Encode(&b, img, &jpeg.Options{Quality: 80}); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

// TestNaturalLessOrder checks that photo2 sorts before photo10.
func TestNaturalLessOrder(t *testing.T) {
	got := []string{"photo10.jpg", "photo2.jpg", "photo1.jpg", "Photo3.JPG"}
	sortByName(got)
	want := []string{"photo1.jpg", "photo2.jpg", "Photo3.JPG", "photo10.jpg"}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("natural order: got %v, want %v", got, want)
		}
	}
}

// sortByName is a tiny wrapper so the test documents the production sort.
func sortByName(names []string) {
	for i := 1; i < len(names); i++ {
		for j := i; j > 0 && naturalLess(names[j], names[j-1]); j-- {
			names[j], names[j-1] = names[j-1], names[j]
		}
	}
}

// TestPadJPEGTail checks EOI padding without corrupting image data.
func TestPadJPEGTail(t *testing.T) {
	raw := testJPEG(t, 32, 32)
	patched := padJPEGTail(raw, 64)
	if patched == nil {
		t.Fatal("padJPEGTail returned nil for a valid JPEG")
	}
	if len(patched) != len(raw)+64 {
		t.Fatalf("padded length = %d, want %d", len(patched), len(raw)+64)
	}
	if !bytes.HasSuffix(patched, []byte{0xFF, 0xD9}) {
		t.Fatal("EOI marker is no longer at the end")
	}
	if !bytes.Equal(patched[:len(raw)-2], raw[:len(raw)-2]) {
		t.Fatal("bytes before EOI were modified")
	}
	if got := padJPEGTail([]byte("not a jpeg"), 64); got != nil {
		t.Fatal("padJPEGTail should return nil when there is no EOI")
	}
}

// brokenHeightJPEG reproduces the real 2.8 GB RAR5 bug: SOF declares one extra
// MCU row (8 px) while the entropy stream ends early. libjpeg pads silently,
// Go's strict decoder reports "missing 0xff00 sequence".
func brokenHeightJPEG(t *testing.T, w, h int) []byte {
	t.Helper()
	raw := testJPEG(t, w, h)
	for i := 0; i+9 < len(raw); i++ {
		if raw[i] != 0xFF || (raw[i+1] != 0xC0 && raw[i+1] != 0xC2) {
			continue
		}
		old := binary.BigEndian.Uint16(raw[i+5 : i+7])
		binary.BigEndian.PutUint16(raw[i+5:i+7], old+8)
		return raw
	}
	t.Fatal("SOF0/SOF2 marker not found")
	return nil
}

// TestDecodeImageRepairsTruncatedJPEG reproduces a real truncated-JPEG bug.
func TestDecodeImageRepairsTruncatedJPEG(t *testing.T) {
	raw := brokenHeightJPEG(t, 64, 64)
	if _, _, err := image.Decode(bytes.NewReader(raw)); err == nil {
		t.Fatal("fixture should fail strict decoding, otherwise the test is meaningless")
	}
	img, repaired, err := decodeImage(raw)
	if err != nil {
		t.Fatalf("decodeImage could not repair the stream: %v", err)
	}
	if !repaired {
		t.Fatal("expected repaired=true")
	}
	if img.Bounds().Dy() != 72 {
		t.Fatalf("repaired height = %d, want 72", img.Bounds().Dy())
	}
}

// TestDecodeImageLeavesHealthyJPEGAlone guards against false repair flags.
func TestDecodeImageLeavesHealthyJPEGAlone(t *testing.T) {
	raw := testJPEG(t, 48, 24)
	img, repaired, err := decodeImage(raw)
	if err != nil || repaired {
		t.Fatalf("healthy JPEG: repaired=%v err=%v", repaired, err)
	}
	if img.Bounds().Dx() != 48 || img.Bounds().Dy() != 24 {
		t.Fatalf("unexpected bounds %v", img.Bounds())
	}
}

// TestClassifyDecodeError verifies error classification for damaged images.
func TestClassifyDecodeError(t *testing.T) {
	heic := append([]byte{0, 0, 0, 0x18, 'f', 't', 'y', 'p'}, []byte("heic0000")...)
	if msg := classifyDecodeError(heic, fmt.Errorf("boom")).Error(); !strings.Contains(msg, "HEIC") {
		t.Fatalf("HEIC misclassified: %s", msg)
	}
	badJPEG := []byte{0xFF, 0xD8, 0xFF, 0xE0, 0, 0}
	if msg := classifyDecodeError(badJPEG, fmt.Errorf("missing 0xff00 sequence")).Error(); !strings.Contains(msg, "Incomplete JPEG") {
		t.Fatalf("truncated JPEG misclassified: %s", msg)
	}
	png := []byte{0x89, 'P', 'N', 'G', 0, 0}
	if msg := classifyDecodeError(png, fmt.Errorf("boom")).Error(); !strings.Contains(msg, "PNG") {
		t.Fatalf("PNG misclassified: %s", msg)
	}
}

// TestProcessImageRespectsMaxEdge verifies long-edge scaling and byte budgets.
func TestProcessImageRespectsMaxEdge(t *testing.T) {
	raw := testJPEG(t, 400, 200)
	p, err := processImage(raw, 200, 200*1024, 82)
	if err != nil {
		t.Fatal(err)
	}
	if p.w != 200 || p.h != 100 {
		t.Fatalf("scaled to %dx%d, want 200x100", p.w, p.h)
	}
	if p.repaired || len(p.jpeg) == 0 || len(p.jpeg) > 200*1024 {
		t.Fatalf("unexpected page: repaired=%v bytes=%d", p.repaired, len(p.jpeg))
	}
}

// TestWriteErrorReportNeverWritesPasswords guards the no-secrets policy.
func TestWriteErrorReportNeverWritesPasswords(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "out_error_report.log")
	o := Options{
		Source:      "/private/photos.rar",
		ArchivePass: "Archive-Secret-Do-Not-Leak",
		PDFPass:     "PDF-Secret-Do-Not-Leak",
		OutPath:     "/private/out.pdf",
		TargetMB:    20,
		MaxEdge:     1600,
		Quality:     82,
		PageMode:    "fit",
		Workers:     4,
	}
	if err := writeErrorReport(path, o, []Msg{M("engine.skipped", "Image 2 skipped: corrupt")}, 1, fmt.Errorf("fatal")); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	s := string(data)
	for _, secret := range []string{o.ArchivePass, o.PDFPass} {
		if strings.Contains(s, secret) {
			t.Fatalf("password leaked into report: %s", secret)
		}
	}
	for _, want := range []string{"Archive password", "set", "Repaired", "fatal", AppVersion} {
		if !strings.Contains(s, want) {
			t.Fatalf("report missing %q", want)
		}
	}
	removeStaleReport(path)
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("removeStaleReport did not delete the report")
	}
}

// TestRunJobEndToEnd checks that one bad image only skips its own page.
func TestRunJobEndToEnd(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "images")
	if err := os.MkdirAll(src, 0755); err != nil {
		t.Fatal(err)
	}
	for i, size := range []struct{ w, h int }{{320, 160}, {160, 320}, {200, 200}} {
		name := fmt.Sprintf("photo%d.jpg", i+1)
		if err := os.WriteFile(filepath.Join(src, name), testJPEG(t, size.w, size.h), 0644); err != nil {
			t.Fatal(err)
		}
	}
	// One unrecoverable file must only skip its own page, never abort the job.
	if err := os.WriteFile(filepath.Join(src, "photo4.jpg"), []byte("definitely not an image"), 0644); err != nil {
		t.Fatal(err)
	}

	out := filepath.Join(dir, "result.pdf")
	o := Options{
		Source:   src,
		PDFPass:  "OpenSesame",
		OutPath:  out,
		MaxEdge:  200,
		TargetMB: 5,
		Quality:  82,
		PageMode: "fit",
		Workers:  2,
	}
	j := newJob()
	path, size, pages, _, err := runJob(o, j)
	if err != nil {
		t.Fatalf("runJob failed: %v", err)
	}
	if path != out || pages != 3 {
		t.Fatalf("path=%s pages=%d, want %s / 3", path, pages, out)
	}
	if warnings := j.getWarnings(); len(warnings) != 1 {
		t.Fatalf("warnings = %v, want exactly one skipped image", warnings)
	}
	if size <= 0 || size > int64(o.TargetMB)*1024*1024 {
		t.Fatalf("output size %d outside budget", size)
	}
	data, err := os.ReadFile(out)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"%PDF-", "/Encrypt", "/DCTDecode", "/MediaBox"} {
		if !bytes.Contains(data, []byte(want)) {
			t.Fatalf("PDF missing %q", want)
		}
	}
}
