package main

import (
	"bytes"
	"image"
	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"strings"
	"sync/atomic"

	_ "golang.org/x/image/bmp"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/tiff"
	_ "golang.org/x/image/webp"
)

type processedPage struct {
	jpeg     []byte
	w        int
	h        int
	repaired bool // decoded only after repairing a truncated JPEG stream
}

// learnedQuality remembers the JPEG quality that satisfied the size budget for
// the previous image. Images from one archive usually share similar content, so
// trying this value first turns a 6-7 step binary search into 1-2 encodes.
var learnedQuality atomic.Int64

// decodeImage decodes an image and, for truncated JPEG streams, retries after
// padding the entropy-coded data just before the EOI marker. libjpeg (Preview,
// browsers, Pillow) silently pads missing MCUs with zero bits; Go's image/jpeg
// is strict and reports "missing 0xff00 sequence" at the trailing FF D9.
// A small amount of 0x00 padding lets Go finish the final MCU row, so the page
// is kept instead of aborting the whole job.
func decodeImage(raw []byte) (image.Image, bool, error) {
	src, _, err := image.Decode(bytes.NewReader(raw))
	if err == nil {
		return src, false, nil
	}
	if !isJPEGData(raw) {
		return nil, false, classifyDecodeError(raw, err)
	}
	for _, pad := range []int{64, 256, 1024, 4096} {
		patched := padJPEGTail(raw, pad)
		if patched == nil {
			break
		}
		img, _, e := image.Decode(bytes.NewReader(patched))
		if e == nil {
			return img, true, nil
		}
	}
	return nil, false, classifyDecodeError(raw, err)
}

func isJPEGData(raw []byte) bool {
	return len(raw) >= 3 && raw[0] == 0xFF && raw[1] == 0xD8 && raw[2] == 0xFF
}

// padJPEGTail inserts n neutral (0x00) entropy bytes before the final EOI.
// 0x00 needs no byte stuffing, so the resulting stream stays valid JPEG.
func padJPEGTail(raw []byte, n int) []byte {
	idx := bytes.LastIndex(raw, []byte{0xFF, 0xD9})
	if idx < 0 {
		return nil
	}
	out := make([]byte, 0, len(raw)+n)
	out = append(out, raw[:idx]...)
	for i := 0; i < n; i++ {
		out = append(out, 0x00)
	}
	return append(out, raw[idx:]...)
}

// classifyDecodeError turns Go's low-level decoder errors into an actionable
// message. The old code blamed every failure on HEIC/HEIF, which was
// misleading: the failing file in the field report was an ordinary JPEG.
func classifyDecodeError(raw []byte, err error) error {
	msg := err.Error()
	if len(raw) >= 12 && string(raw[4:8]) == "ftyp" {
		brand := string(raw[8:12])
		switch {
		case strings.HasPrefix(brand, "hei"), strings.HasPrefix(brand, "hev"),
			brand == "mif1", brand == "msf1":
			return E("err.heic", "HEIC/HEIF is not supported; convert to JPG or PNG first (original error: {0})", A(msg)...)
		case strings.HasPrefix(brand, "avi"), brand == "avis":
			return E("err.avif", "AVIF is not supported; convert to JPG or PNG first (original error: {0})", A(msg)...)
		}
	}
	if isJPEGData(raw) {
		low := strings.ToLower(msg)
		if strings.Contains(low, "missing 0xff00") || strings.Contains(low, "bad huffman") ||
			strings.Contains(low, "unexpected eof") || strings.Contains(low, "truncat") {
			return E("err.jpegTruncated", "Incomplete JPEG data (trailing image data is missing); repair failed. Re-download the image or re-save it with Preview (original error: {0})", A(msg)...)
		}
		return E("err.jpegBroken", "Corrupt JPEG or an unsupported encoding (original error: {0})", A(msg)...)
	}
	if len(raw) >= 4 && string(raw[:4]) == "RIFF" {
		return E("err.webpBroken", "Corrupt WebP or an unsupported encoding (original error: {0})", A(msg)...)
	}
	if len(raw) >= 4 && bytes.Equal(raw[:4], []byte{0x89, 'P', 'N', 'G'}) {
		return E("err.pngBroken", "Corrupt PNG (original error: {0})", A(msg)...)
	}
	return E("err.unknownImage", "Unrecognised image format, or the file is corrupt (original error: {0})", A(msg)...)
}

// processImage scales, flattens and encodes one image to a size-bounded JPEG.
// It takes bytes instead of an io.Reader so the caller can read archives
// sequentially while decoding happens in parallel workers.
func processImage(raw []byte, maxEdge, maxBytes, maxQuality int) (*processedPage, error) {
	src, repaired, err := decodeImage(raw)
	if err != nil {
		return nil, err
	}
	src = applyOrientation(src, exifOrientation(raw))

	b := src.Bounds()
	edge := maxEdge
	for attempt := 0; attempt < 4; attempt++ {
		w, h := b.Dx(), b.Dy()
		if w <= 0 || h <= 0 {
			return nil, E("err.imageDims", "Invalid image dimensions")
		}
		long := w
		if h > long {
			long = h
		}
		nw, nh := w, h
		if long > edge {
			s := float64(edge) / float64(long)
			nw = int(float64(w)*s + 0.5)
			nh = int(float64(h)*s + 0.5)
			if nw < 16 {
				nw = 16
			}
			if nh < 16 {
				nh = 16
			}
		}
		// Scale straight into a small RGBA buffer. Flattening happens on the
		// scaled image, avoiding a full-resolution RGBA copy (~96 MB for a
		// 4000x6000 photo) on every single page.
		dst := image.NewRGBA(image.Rect(0, 0, nw, nh))
		draw.CatmullRom.Scale(dst, dst.Bounds(), src, b, draw.Src, nil)
		flattenAlpha(dst)

		data, _, err := encodeTarget(dst, maxBytes, maxQuality)
		if err != nil {
			return nil, err
		}
		out := &processedPage{jpeg: data, w: nw, h: nh, repaired: repaired}
		if len(data) <= maxBytes || attempt == 3 {
			return out, nil
		}
		edge = edge * 3 / 4
		if edge < 400 {
			edge = 400
		}
	}
	return nil, E("err.encode", "Image encoding failed")
}

// flattenAlpha composites semi-transparent pixels onto white so the embedded
// JPEG is always DeviceRGB. It scans the alpha channel first and returns
// immediately for opaque images (the overwhelmingly common case).
func flattenAlpha(dst *image.RGBA) {
	p := dst.Pix
	opaque := true
	for i := 3; i < len(p); i += 4 {
		if p[i] != 0xFF {
			opaque = false
			break
		}
	}
	if opaque {
		return
	}
	for i := 0; i+3 < len(p); i += 4 {
		a := uint32(p[i+3])
		switch a {
		case 0xFF:
			continue
		case 0:
			p[i], p[i+1], p[i+2], p[i+3] = 255, 255, 255, 255
		default:
			inv := 255 - a
			p[i] = uint8((uint32(p[i])*a + 255*inv) / 255)
			p[i+1] = uint8((uint32(p[i+1])*a + 255*inv) / 255)
			p[i+2] = uint8((uint32(p[i+2])*a + 255*inv) / 255)
			p[i+3] = 255
		}
	}
}

func encodeAt(img image.Image, q int) ([]byte, error) {
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: q}); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// encodeTarget finds the highest JPEG quality that stays within maxBytes.
// A learned quality from the previous image usually short-circuits the search.
func encodeTarget(img image.Image, maxBytes, maxQuality int) ([]byte, int, error) {
	if maxQuality > 95 {
		maxQuality = 95
	}
	if maxQuality < 25 {
		maxQuality = 25
	}
	lo, hi := 20, maxQuality
	bestQ := 20
	var best []byte

	if h := int(learnedQuality.Load()); h > 20 && h <= maxQuality {
		if b, e := encodeAt(img, h); e == nil {
			if len(b) <= maxBytes {
				best, bestQ, lo = b, h, h+1
			} else {
				hi = h - 1
			}
		}
	}

	for lo <= hi {
		mid := (lo + hi) / 2
		b, e := encodeAt(img, mid)
		if e != nil {
			return nil, 0, e
		}
		if len(b) <= maxBytes {
			bestQ, best = mid, b
			lo = mid + 1
		} else {
			hi = mid - 1
		}
	}
	if best == nil {
		b, e := encodeAt(img, 20)
		if e != nil {
			return nil, 0, e
		}
		learnedQuality.Store(20)
		return b, 20, nil
	}
	learnedQuality.Store(int64(bestQ))
	return best, bestQ, nil
}
