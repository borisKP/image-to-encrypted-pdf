package main

import (
	"flag"
	"fmt"
	"os"
)

const usage = `Image to Encrypted PDF — processing engine

The graphical app is the native macOS bundle built by macapp/build_macos.sh.
This binary is the processing engine (imgtopdf-helper) that the app launches as
a child process. It never opens a browser and never listens on a socket.

Subcommands (JSON lines on stdout, used by the native UI):
  list    <flags>   enumerate images inside a folder / ZIP / 7z / RAR archive
  thumb   <flags>   decode one image into a temporary preview thumbnail
  build   <flags>   build the compressed, optionally encrypted PDF

Automation / CLI:
  -cli -src <path> [-archive-pass <pw>] [-pdf-pass <pw>] -out <file.pdf>
       [-target-mb 20] [-max-edge 1600] [-quality 82] [-page fit]

Messages sent to the UI are language-neutral {key, args} events; the UI owns
all translations. Run "<binary> build -h" for the full flag list.
`

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "list":
			os.Exit(runList(os.Args[2:]))
		case "thumb":
			os.Exit(runThumb(os.Args[2:]))
		case "build":
			os.Exit(runBuild(os.Args[2:]))
		case "help", "-h", "--help":
			fmt.Print(usage)
			return
		}
	} else {
		fmt.Print(usage)
		return
	}

	cli := flag.Bool("cli", false, "run a job without the native UI")
	src := flag.String("src", "", "input: an encrypted archive (.zip/.7z/.rar) or an image folder")
	archivePass := flag.String("archive-pass", "", "archive password")
	pdfPass := flag.String("pdf-pass", "", "PDF open password (blank = no encryption)")
	out := flag.String("out", "", "output PDF path")
	maxEdge := flag.Int("max-edge", 1600, "long-edge pixel limit")
	targetMB := flag.Int("target-mb", 20, "target total size in MB")
	quality := flag.Int("quality", 82, "JPEG quality ceiling 25-95")
	pageMode := flag.String("page", "fit", "page mode: fit (no border) or a4")
	lang := flag.String("lang", "en", "language for the diagnostic report (zh/en)")
	flag.Parse()

	if !*cli {
		fmt.Print(usage)
		return
	}

	o := Options{
		Source:      *src,
		ArchivePass: *archivePass,
		PDFPass:     *pdfPass,
		OutPath:     *out,
		MaxEdge:     *maxEdge,
		TargetMB:    *targetMB,
		Quality:     *quality,
		PageMode:    *pageMode,
		Lang:        *lang,
	}
	j := newJob()
	path, size, pages, rounds, err := runJob(o, j)
	for _, l := range j.status().Logs {
		fmt.Println(l)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "Failed:", err)
		os.Exit(1)
	}
	fmt.Printf("Output: %s\nPages: %d\nSize: %.2f MB\nCompression rounds: %d\n",
		path, pages, float64(size)/1024/1024, rounds)
}
