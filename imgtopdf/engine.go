package main

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/image/draw"
)

// Options configures one conversion: source archive, output path, size and
// quality budgets, page layout, worker count and report language.
type Options struct {
	Source       string `json:"source"`
	ArchivePass  string `json:"archivePass"`
	PDFPass      string `json:"pdfPass"`
	OutPath      string `json:"outPath"`
	MaxEdge      int    `json:"maxEdge"`
	TargetMB     int    `json:"targetMB"`
	Quality      int    `json:"quality"`
	PageMode     string `json:"pageMode"`
	Workers      int    `json:"workers"`
	ErrorLogPath string `json:"errorLogPath"`
	// Lang selects the language of the on-disk diagnostic report.
	Lang string `json:"lang"`
	// Order holds original entry indexes in the exact sequence the user wants
	// as PDF pages. An empty slice means natural path order.
	Order []int `json:"order,omitempty"`
}

// JobStatus is the progress snapshot serialized to the UI as JSON lines.
type JobStatus struct {
	Running    bool     `json:"running"`
	Done       bool     `json:"done"`
	Failed     bool     `json:"failed"`
	Percent    int      `json:"percent"`
	Message    string   `json:"message"`
	Logs       []string `json:"logs"`
	ResultPath string   `json:"resultPath"`
	ResultSize int64    `json:"resultSize"`
	Pages      int      `json:"pages"`
	Elapsed    string   `json:"elapsed"`
	Rounds     int      `json:"rounds"`
}

// Job owns one conversion run, its progress state and its event emitter.
type Job struct {
	mu            sync.Mutex
	st            JobStatus
	opt           Options
	emit          func(any)
	warnings      []Msg
	repairedCount int
}

func newJob() *Job {
	return &Job{st: JobStatus{Logs: []string{}}}
}

// setEmitter lets a host (the native macOS UI) receive progress as JSON lines
// on stdout. The browser UI simply polls status() and leaves emit nil.
func (j *Job) setEmitter(f func(any)) {
	j.mu.Lock()
	j.emit = f
	j.mu.Unlock()
}

func (j *Job) status() JobStatus {
	j.mu.Lock()
	defer j.mu.Unlock()
	cp := j.st
	cp.Logs = append([]string{}, j.st.Logs...)
	return cp
}

func (j *Job) update(percent int, msg string) {
	j.mu.Lock()
	defer j.mu.Unlock()
	j.st.Percent = percent
	j.st.Message = msg
	if j.emit != nil {
		j.emit(map[string]any{"type": "progress", "percent": percent, "message": msg})
	}
}

func (j *Job) log(s string) {
	j.logEvent(time.Now().Format("15:04:05"), s, nil)
}

// logMsg emits a structured, language-neutral message. `ts` is kept separate
// from the arguments so the UI can prefix it without translating it.
func (j *Job) logMsg(m Msg) {
	j.logEvent(time.Now().Format("15:04:05"), m.localize(), &m)
}

func (j *Job) logEvent(ts, fallback string, m *Msg) {
	j.mu.Lock()
	defer j.mu.Unlock()
	line := ts + "  " + fallback
	j.st.Logs = append(j.st.Logs, line)
	if len(j.st.Logs) > 60 {
		j.st.Logs = j.st.Logs[len(j.st.Logs)-60:]
	}
	if j.emit != nil {
		if m != nil {
			j.emit(map[string]any{"type": "log", "key": m.Key, "args": m.Args, "ts": ts})
		} else {
			j.emit(map[string]any{"type": "log", "message": fallback, "ts": ts})
		}
	}
}

// updateMsg emits a structured progress message alongside the percentage.
func (j *Job) updateMsg(percent int, m Msg) {
	j.mu.Lock()
	defer j.mu.Unlock()
	j.st.Percent = percent
	j.st.Message = m.localize()
	if j.emit != nil {
		j.emit(map[string]any{"type": "progress", "percent": percent,
			"key": m.Key, "args": m.Args, "message": m.localize()})
	}
}

// addWarning records a per-image failure without aborting the whole job.
func (j *Job) addWarning(m Msg) {
	j.logMsg(m)
	j.mu.Lock()
	j.warnings = append(j.warnings, m)
	j.mu.Unlock()
}

func (j *Job) getWarnings() []Msg {
	j.mu.Lock()
	defer j.mu.Unlock()
	return append([]Msg{}, j.warnings...)
}

func (j *Job) addRepaired(n int) {
	j.mu.Lock()
	j.repairedCount += n
	j.mu.Unlock()
}

func (j *Job) getRepaired() int {
	j.mu.Lock()
	defer j.mu.Unlock()
	return j.repairedCount
}

func (j *Job) start(o Options) bool {
	j.mu.Lock()
	if j.st.Running {
		j.mu.Unlock()
		return false
	}
	j.st = JobStatus{Running: true, Logs: []string{}, Message: "Preparing…"}
	j.opt = o
	j.mu.Unlock()
	go func() {
		path, size, pages, rounds, err := runJob(o, j)
		j.mu.Lock()
		defer j.mu.Unlock()
		j.st.Running = false
		j.st.Done = err == nil
		j.st.Failed = err != nil
		j.st.Percent = 100
		if err != nil {
			j.st.Message = "Failed: " + err.Error()
			j.st.Logs = append(j.st.Logs, "Error: "+err.Error())
		} else {
			j.st.Message = "Done"
			j.st.ResultPath = path
			j.st.ResultSize = size
			j.st.Pages = pages
			j.st.Rounds = rounds
		}
	}()
	return true
}

func runJob(o Options, j *Job) (string, int64, int, int, error) {
	start := time.Now()
	defer func() {
		j.mu.Lock()
		j.st.Elapsed = time.Since(start).Round(100 * time.Millisecond).String()
		j.mu.Unlock()
	}()

	if o.MaxEdge <= 0 {
		o.MaxEdge = 1600
	}
	if o.TargetMB <= 0 {
		o.TargetMB = 20
	}
	if o.Quality <= 0 {
		o.Quality = 82
	}
	if o.PageMode == "" {
		// Default: page box follows the image aspect ratio, no border/margin.
		o.PageMode = "fit"
	}
	if o.OutPath == "" {
		return "", 0, 0, 0, E("err.outRequired", "Specify an output file path")
	}
	targetBytes := int64(o.TargetMB) * 1024 * 1024

	j.logMsg(M("engine.reading", "Reading input…"))
	entries, cleanup, err := collectSources(o.Source, o.ArchivePass)
	if err != nil {
		return "", 0, 0, 0, err
	}
	defer cleanup()

	// Apply the user-defined order / selection from the native list view.
	if len(o.Order) > 0 {
		ordered := make([]srcEntry, 0, len(o.Order))
		seen := make(map[int]bool, len(o.Order))
		for _, idx := range o.Order {
			if idx < 0 || idx >= len(entries) || seen[idx] {
				continue
			}
			seen[idx] = true
			ordered = append(ordered, entries[idx])
		}
		if len(ordered) == 0 {
			return "", 0, 0, 0, E("err.orderInvalid", "Custom image order is invalid: no usable images")
		}
		entries = ordered
		j.logMsg(M("engine.ordered", "{0} images arranged in list order", A(len(entries))...))
	}

	n := len(entries)
	if n == 0 {
		return "", 0, 0, 0, E("err.noImages", "No supported images found (JPG/PNG/GIF/BMP/TIFF/WebP)")
	}
	j.logMsg(M("engine.found", "{0} images found", A(n)...))

	// Reserve 1 MB for PDF structure, xref and encryption overhead.
	perImage := int((targetBytes - 1024*1024) / int64(n))
	if perImage < 20*1024 {
		perImage = 20 * 1024
	}

	// Archive readers (RAR/7z) keep shared decoder state, so entries must be
	// read sequentially. Decoding/scaling/encoding is CPU-bound and runs in a
	// bounded worker pool; results are stored by index to preserve page order.
	workers := o.Workers
	if workers <= 0 {
		workers = runtime.NumCPU() / 2
		if workers < 2 {
			workers = 2
		}
		if workers > 4 {
			workers = 4
		}
	}
	if workers > 8 {
		workers = 8
	}
	if workers > n {
		workers = n
	}
	j.logMsg(M("engine.workers", "Parallel processing with {0} workers", A(workers)...))

	type imageTask struct {
		idx  int
		name string
		raw  []byte
		err  error
	}
	type pageResult struct {
		page *processedPage
		err  error
	}

	tasks := make(chan imageTask, workers*2)
	results := make([]pageResult, n)
	var doneCount atomic.Int64
	var lastPercent atomic.Int64
	var wg sync.WaitGroup

	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for t := range tasks {
				if t.err != nil {
					results[t.idx] = pageResult{err: t.err}
				} else {
					p, e := processImage(t.raw, o.MaxEdge, perImage, o.Quality)
					results[t.idx] = pageResult{page: p, err: e}
				}
				d := int(doneCount.Add(1))
				pct := 5 + int(70*float64(d)/float64(n))
				prev := int(lastPercent.Load())
				if (pct >= prev+2 || d == n) && lastPercent.CompareAndSwap(int64(prev), int64(pct)) {
					j.updateMsg(pct, M("engine.progress", "Processed {0} / {1}", A(d, n)...))
				}
			}
		}()
	}

	for i, e := range entries {
		rc, err := e.open()
		if err != nil {
			tasks <- imageTask{idx: i, name: e.name, err: EW("err.readImage", "Could not read “{0}”: {1}", err, A(e.name, err)...)}
			continue
		}
		raw, err := io.ReadAll(rc)
		_ = rc.Close()
		if err != nil {
			tasks <- imageTask{idx: i, name: e.name, err: EW("err.readImageBody", "Could not decode “{0}”: {1}", err, A(e.name, err)...)}
			continue
		}
		tasks <- imageTask{idx: i, name: e.name, raw: raw}
	}
	close(tasks)
	wg.Wait()

	pages := make([]processedPage, 0, n)
	repaired := 0
	for i, r := range results {
		if r.err != nil {
			j.addWarning(M("engine.skipped", "Image {0} “{1}” skipped: {2}", A(i+1, entries[i].name, r.err)...))
			continue
		}
		if r.page.repaired {
			repaired++
		}
		pages = append(pages, *r.page)
	}
	if repaired > 0 {
		j.addRepaired(repaired)
		j.logMsg(M("engine.repaired", "Repaired and kept {0} truncated JPEG file(s)", A(repaired)...))
	}
	if len(pages) == 0 {
		return "", 0, 0, 0, E("err.allFailed", "Every image failed; no PDF was produced (see the error report)")
	}
	j.logMsg(M("engine.processed", "Processed {0} / {1} images, about {2} MB so far",
		A(len(pages), n, fmt.Sprintf("%.1f", float64(totalJPEG(pages))/1024/1024))...))

	j.updateMsg(82, M("engine.assembling", "Assembling PDF…"))
	rounds := 0
	var final []byte
	for attempt := 0; attempt < 4; attempt++ {
		rounds++
		objs := buildPDF(pages, o.PageMode)
		encObjNum := 0
		if o.PDFPass != "" {
			enc, encDict, e := newPDFEncryption(o.PDFPass, o.PDFPass+"-owner")
			if e != nil {
				return "", 0, 0, 0, e
			}
			encObjNum = len(objs) + 1
			objs = append(objs, *encDict)
			final, err = renderPDF(objs, enc, encObjNum)
		} else {
			final, err = renderPDF(objs, nil, 0)
		}
		if err != nil {
			return "", 0, 0, 0, err
		}
		if int64(len(final)) <= targetBytes || attempt == 3 {
			break
		}
		ratio := float64(targetBytes) / float64(len(final)) * 0.94
		j.logMsg(M("engine.recompress", "{0} MB exceeds the target; recompressing (factor {1})",
			A(fmt.Sprintf("%.1f", float64(len(final))/1024/1024), fmt.Sprintf("%.2f", ratio))...))
		newPer := int(float64(perImage) * ratio)
		if newPer < 12*1024 {
			newPer = 12 * 1024
		}
		perImage = newPer
		for i := range pages {
			pages[i] = recompressPage(pages[i], perImage, o.Quality)
		}
	}

	j.updateMsg(95, M("engine.writing", "Writing output file…"))
	if err := os.MkdirAll(filepath.Dir(o.OutPath), 0755); err != nil {
		return "", 0, 0, 0, err
	}
	if err := os.WriteFile(o.OutPath, final, 0644); err != nil {
		return "", 0, 0, 0, EW("err.writeOut", "Could not write the output file: {0}", err, A(err)...)
	}
	st, _ := os.Stat(o.OutPath)
	var sz int64
	if st != nil {
		sz = st.Size()
	}
	j.logMsg(M("engine.done", "Done: {0} pages, {1} MB, in {2}",
		A(len(pages), fmt.Sprintf("%.2f", float64(sz)/1024/1024),
			time.Since(start).Round(100*time.Millisecond))...))
	if o.PDFPass != "" {
		j.logMsg(M("engine.encrypted", "PDF encrypted with an AES-256 open password"))
	} else {
		j.logMsg(M("engine.plain", "No PDF password set (plain output)"))
	}
	return o.OutPath, sz, len(pages), rounds, nil
}

func totalJPEG(pages []processedPage) int {
	t := 0
	for _, p := range pages {
		t += len(p.jpeg)
	}
	return t
}

// recompressPage shrinks an already-processed page without re-reading the source.
func recompressPage(p processedPage, maxBytes, quality int) processedPage {
	img, err := jpeg.Decode(bytes.NewReader(p.jpeg))
	if err != nil {
		return p
	}
	data, _, err := encodeTarget(img, maxBytes, quality)
	if err != nil || len(data) >= len(p.jpeg) {
		// Shrink dimensions to guarantee a smaller result.
		w, h := p.w, p.h
		nw, nh := int(float64(w)*0.85), int(float64(h)*0.85)
		if nw < 16 || nh < 16 {
			return p
		}
		dst := image.NewRGBA(image.Rect(0, 0, nw, nh))
		draw.CatmullRom.Scale(dst, dst.Bounds(), img, img.Bounds(), draw.Src, nil)
		data, _, err = encodeTarget(dst, maxBytes, quality)
		if err != nil {
			return p
		}
		return processedPage{jpeg: data, w: nw, h: nh}
	}
	return processedPage{jpeg: data, w: p.w, h: p.h}
}
