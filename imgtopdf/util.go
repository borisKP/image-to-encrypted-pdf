package main

import (
	"encoding/binary"
	"image"
	"path/filepath"
	"strconv"
	"strings"
	"unicode"
)

var imageExts = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".gif": true,
	".bmp": true, ".tif": true, ".tiff": true, ".webp": true,
}

func isImageName(name string) bool {
	return imageExts[strings.ToLower(filepath.Ext(name))]
}

// naturalLess sorts "2.jpg" before "10.jpg", case-insensitively.
func naturalLess(a, b string) bool {
	ai, bi := 0, 0
	for ai < len(a) && bi < len(b) {
		ca, cb := rune(a[ai]), rune(b[bi])
		if unicode.IsDigit(ca) && unicode.IsDigit(cb) {
			as, bs := ai, bi
			for ai < len(a) && unicode.IsDigit(rune(a[ai])) {
				ai++
			}
			for bi < len(b) && unicode.IsDigit(rune(b[bi])) {
				bi++
			}
			av, _ := strconv.ParseUint(strings.TrimLeft(a[as:ai], "0"), 10, 64)
			bv, _ := strconv.ParseUint(strings.TrimLeft(b[bs:bi], "0"), 10, 64)
			la, lb := ai-as, bi-bs
			if av != bv {
				return av < bv
			}
			if la != lb {
				return la < lb
			}
			continue
		}
		ua, ub := unicode.ToLower(ca), unicode.ToLower(cb)
		if ua != ub {
			return ua < ub
		}
		ai++
		bi++
	}
	return len(a)-ai < len(b)-bi
}

// exifOrientation reads the JPEG APP1/EXIF orientation tag (0x0112).
func exifOrientation(data []byte) int {
	if len(data) < 4 || data[0] != 0xFF || data[1] != 0xD8 {
		return 1
	}
	pos := 2
	for pos+4 < len(data) && pos < 131072 {
		if data[pos] != 0xFF {
			break
		}
		marker := data[pos+1]
		if marker == 0xDA || marker == 0xD9 {
			break
		}
		if marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7) {
			pos += 2
			continue
		}
		segLen := int(binary.BigEndian.Uint16(data[pos+2 : pos+4]))
		if segLen < 2 || pos+2+segLen > len(data) {
			break
		}
		seg := data[pos+4 : pos+2+segLen]
		if marker == 0xE1 && len(seg) >= 8 && string(seg[:6]) == "Exif\x00\x00" {
			return parseTiffOrientation(seg[6:])
		}
		pos += 2 + segLen
	}
	return 1
}

func parseTiffOrientation(t []byte) int {
	if len(t) < 8 {
		return 1
	}
	var bo binary.ByteOrder = binary.BigEndian
	switch {
	case t[0] == 'I' && t[1] == 'I':
		bo = binary.LittleEndian
	case t[0] == 'M' && t[1] == 'M':
	default:
		return 1
	}
	if bo.Uint16(t[2:4]) != 42 {
		return 1
	}
	off := int(bo.Uint32(t[4:8]))
	if off+2 > len(t) {
		return 1
	}
	count := int(bo.Uint16(t[off : off+2]))
	for i := 0; i < count; i++ {
		e := off + 2 + i*12
		if e+12 > len(t) {
			break
		}
		if bo.Uint16(t[e:e+2]) == 0x0112 {
			o := int(bo.Uint16(t[e+8 : e+10]))
			if o >= 1 && o <= 8 {
				return o
			}
			return 1
		}
	}
	return 1
}

// applyOrientation applies EXIF orientations 1-8.
func applyOrientation(src image.Image, o int) image.Image {
	if o <= 1 || o > 8 {
		return src
	}
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	ow, oh := w, h
	if o >= 5 && o <= 8 {
		ow, oh = h, w
	}
	dst := image.NewRGBA(image.Rect(0, 0, ow, oh))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			c := src.At(b.Min.X+x, b.Min.Y+y)
			switch o {
			case 2:
				dst.Set(w-1-x, y, c)
			case 3:
				dst.Set(w-1-x, h-1-y, c)
			case 4:
				dst.Set(x, h-1-y, c)
			case 5: // transpose
				dst.Set(y, x, c)
			case 6: // rotate 90 CW
				dst.Set(h-1-y, x, c)
			case 7: // transverse
				dst.Set(oh-1-y, ow-1-x, c)
			case 8: // rotate 270 CW
				dst.Set(y, w-1-x, c)
			}
		}
	}
	return dst
}
