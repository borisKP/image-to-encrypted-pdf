package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"golang.org/x/image/draw"
)

// The native macOS UI talks to this binary over stdout, one JSON object per
// line. Nothing is sent over the network and no browser is involved.
var emitMu sync.Mutex

func emit(v any) {
	b, err := json.Marshal(v)
	if err != nil {
		return
	}
	emitMu.Lock()
	defer emitMu.Unlock()
	_, _ = os.Stdout.Write(append(b, '\n'))
}

// emitError forwards a language-neutral key when the error carries one.
// The UI resolves the wording, so even past errors can be re-localized.
func emitError(err error) {
	if m, ok := asMsg(err); ok {
		emit(map[string]any{"type": "error", "key": m.Key, "args": m.Args})
		return
	}
	emit(map[string]any{"type": "error", "message": err.Error()})
}

func humanSize(n int64) string {
	f := float64(n)
	switch {
	case f >= 1024*1024*1024:
		return fmt.Sprintf("%.2f GB", f/1024/1024/1024)
	case f >= 1024*1024:
		return fmt.Sprintf("%.1f MB", f/1024/1024)
	case f >= 1024:
		return fmt.Sprintf("%.0f KB", f/1024)
	default:
		return fmt.Sprintf("%d B", n)
	}
}

func sourceKind(src string) string {
	if st, err := os.Stat(src); err == nil && st.IsDir() {
		return "kind.folder"
	}
	switch strings.ToLower(filepath.Ext(src)) {
	case ".zip":
		return "kind.zip"
	case ".7z":
		return "kind.7z"
	case ".rar":
		return "kind.rar"
	default:
		return "kind.unknown"
	}
}

type listItem struct {
	Index    int    `json:"index"`
	Name     string `json:"name"`
	Path     string `json:"path"`
	Size     int64  `json:"size"`
	SizeText string `json:"sizeText"`
}

// runList enumerates images without decoding them (only a tiny read of the
// first entry is done to validate the archive password early).
func runList(args []string) int {
	fs := flag.NewFlagSet("list", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	src := fs.String("src", "", "")
	pass := fs.String("archive-pass", "", "")
	if err := fs.Parse(args); err != nil {
		emitError(err)
		return 2
	}
	entries, cleanup, err := collectSources(*src, *pass)
	if err != nil {
		emitError(err)
		return 1
	}
	defer cleanup()
	if len(entries) == 0 {
		emitError(E("err.noImages", "No supported images found (JPG/PNG/GIF/BMP/TIFF/WebP)"))
		return 1
	}
	// Validate decryption up front so a wrong password is reported in the
	// list view rather than halfway through a long conversion.
	if rc, e := entries[0].open(); e == nil {
		buf := make([]byte, 32)
		_, _ = rc.Read(buf)
		_ = rc.Close()
	} else {
		emitError(EW("err.listImages", "Could not read images from the archive (usually a wrong password or a corrupt file): {0}", e, A(e)...))
		return 1
	}

	items := make([]listItem, 0, len(entries))
	for i, e := range entries {
		items = append(items, listItem{
			Index:    i,
			Name:     e.name,
			Path:     e.path,
			Size:     e.size,
			SizeText: humanSize(e.size),
		})
	}
	emit(map[string]any{
		"type":   "list",
		"source": *src,
		"kind":   sourceKind(*src),
		"count":  len(items),
		"items":  items,
	})
	return 0
}

// runThumb extracts one image, applies EXIF orientation and writes a
// screen-sized JPEG preview to out. The original is never written to disk.
func runThumb(args []string) int {
	fs := flag.NewFlagSet("thumb", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	src := fs.String("src", "", "")
	pass := fs.String("archive-pass", "", "")
	index := fs.Int("index", 0, "")
	out := fs.String("out", "", "")
	maxEdge := fs.Int("max-edge", 1200, "")
	if err := fs.Parse(args); err != nil {
		emitError(err)
		return 2
	}
	entries, cleanup, err := collectSources(*src, *pass)
	if err != nil {
		emitError(err)
		return 1
	}
	defer cleanup()
	if *index < 0 || *index >= len(entries) {
		emitError(E("err.pageRange", "Image index out of range"))
		return 1
	}
	rc, err := entries[*index].open()
	if err != nil {
		emitError(err)
		return 1
	}
	raw, err := io.ReadAll(rc)
	_ = rc.Close()
	if err != nil {
		emitError(err)
		return 1
	}
	img, repaired, err := decodeImage(raw)
	if err != nil {
		emitError(EW("err.preview", "Could not preview this image: {0}", err, A(err)...))
		return 1
	}
	if repaired {
		emit(map[string]any{"type": "log", "key": "msg.thumbRepaired"})
	}
	orient := exifOrientation(raw)
	img = applyOrientation(img, orient)
	b := img.Bounds()
	ow, oh := b.Dx(), b.Dy()

	base := image.NewRGBA(image.Rect(0, 0, ow, oh))
	draw.Draw(base, base.Bounds(), &image.Uniform{C: color.White}, image.Point{}, draw.Src)
	draw.Draw(base, base.Bounds(), img, b.Min, draw.Over)
	img = base

	long := ow
	if oh > long {
		long = oh
	}
	w, h := ow, oh
	if long > *maxEdge {
		s := float64(*maxEdge) / float64(long)
		w = int(float64(ow)*s + 0.5)
		h = int(float64(oh)*s + 0.5)
		dst := image.NewRGBA(image.Rect(0, 0, w, h))
		draw.CatmullRom.Scale(dst, dst.Bounds(), img, img.Bounds(), draw.Src, nil)
		img = dst
	}
	if err := os.MkdirAll(filepath.Dir(*out), 0755); err != nil {
		emitError(err)
		return 1
	}
	f, err := os.Create(*out)
	if err != nil {
		emitError(err)
		return 1
	}
	err = jpeg.Encode(f, img, &jpeg.Options{Quality: 86})
	_ = f.Close()
	if err != nil {
		emitError(err)
		return 1
	}
	emit(map[string]any{
		"type":     "thumb",
		"file":     *out,
		"width":    ow,
		"height":   oh,
		"rotation": orient,
		"bytes":    len(raw),
	})
	return 0
}

// runBuild streams progress events while producing the PDF.
func runBuild(args []string) int {
	fs := flag.NewFlagSet("build", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	src := fs.String("src", "", "")
	ap := fs.String("archive-pass", "", "")
	pp := fs.String("pdf-pass", "", "")
	out := fs.String("out", "", "")
	edge := fs.Int("max-edge", 1600, "")
	mb := fs.Int("target-mb", 20, "")
	q := fs.Int("quality", 82, "")
	page := fs.String("page", "fit", "")
	workers := fs.Int("workers", 0, "parallel image workers; 0 = auto")
	elog := fs.String("error-log", "", "write a diagnostic report here on failure/skips")
	lang := fs.String("lang", "en", "interface language for the on-disk report (zh/en)")
	order := fs.String("order", "", "comma-separated original image indexes = PDF page order")
	if err := fs.Parse(args); err != nil {
		emitError(err)
		return 2
	}
	o := Options{
		Source:       *src,
		ArchivePass:  *ap,
		PDFPass:      *pp,
		OutPath:      *out,
		MaxEdge:      *edge,
		TargetMB:     *mb,
		Quality:      *q,
		PageMode:     *page,
		Workers:      *workers,
		ErrorLogPath: *elog,
		Lang:         *lang,
	}
	if *order != "" {
		for _, part := range strings.Split(*order, ",") {
			part = strings.TrimSpace(part)
			if part == "" {
				continue
			}
			if v, e := strconv.Atoi(part); e == nil && v >= 0 {
				o.Order = append(o.Order, v)
			}
		}
	}
	j := newJob()
	j.setEmitter(emit)
	path, size, pages, rounds, err := runJob(o, j)
	warnings := j.getWarnings()
	repaired := j.getRepaired()

	reportPath := ""
	if *elog != "" {
		if err != nil || len(warnings) > 0 {
			if e := writeErrorReport(*elog, o, warnings, repaired, err); e == nil {
				reportPath = *elog
			} else {
				emit(map[string]any{"type": "log", "key": "msg.reportWriteFailed", "args": A(e)})
			}
		} else {
			removeStaleReport(*elog)
		}
	}
	if reportPath != "" {
		emit(map[string]any{"type": "report", "path": reportPath})
	}
	if err != nil {
		emitError(err)
		return 1
	}
	emit(map[string]any{
		"type":       "result",
		"path":       path,
		"size":       size,
		"sizeText":   humanSize(size),
		"pages":      pages,
		"rounds":     rounds,
		"elapsed":    j.status().Elapsed,
		"warnings":   warnings,
		"repaired":   repaired,
		"errorLog":   reportPath,
		"appVersion": AppVersion,
	})
	return 0
}
