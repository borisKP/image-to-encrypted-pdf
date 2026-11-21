package main

// writeErrorReport writes a diagnostic report next to the output PDF when
// something went wrong. Passwords are deliberately never written to disk.
// The report follows the interface language at the moment the job was queued:
// `--lang zh` produces Chinese, anything else produces English.

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

func writeErrorReport(path string, o Options, warnings []Msg, repaired int, fatal error) error {
	if path == "" {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	en := o.Lang != "zh"
	tr := func(zh, e string) string {
		if en {
			return e
		}
		return zh
	}
	var b strings.Builder
	b.WriteString(tr("图片合集转加密 PDF — 错误报告",
		"Image to Encrypted PDF — Error report") + "\n")
	b.WriteString("============================================================\n")
	fmt.Fprintf(&b, "%-18s: %s\n", tr("版本", "Version"), AppVersion)
	fmt.Fprintf(&b, "%-18s: %s\n", tr("时间", "Time"), time.Now().Format("2006-01-02 15:04:05 -0700"))
	fmt.Fprintf(&b, "%-18s: %s / %s\n", tr("系统", "Platform"), runtime.GOOS, runtime.GOARCH)
	fmt.Fprintf(&b, "%-18s: %s\n", tr("运行时", "Runtime"), runtime.Version())
	fmt.Fprintf(&b, "%-18s: %d\n", tr("CPU 核心", "CPU cores"), runtime.NumCPU())
	b.WriteString("\n--- " + tr("任务参数（不含密码）", "Job parameters (passwords excluded)") + " ---\n")
	fmt.Fprintf(&b, "%-18s: %s\n", tr("输入", "Source"), o.Source)
	fmt.Fprintf(&b, "%-18s: %s\n", tr("输出", "Output"), o.OutPath)
	fmt.Fprintf(&b, "%-18s: %d MB\n", tr("目标体积", "Target size"), o.TargetMB)
	fmt.Fprintf(&b, "%-18s: %d px\n", tr("长边", "Max edge"), o.MaxEdge)
	fmt.Fprintf(&b, "%-18s: %d\n", tr("画质上限", "Quality ceiling"), o.Quality)
	fmt.Fprintf(&b, "%-18s: %s\n", tr("页面模式", "Page mode"), o.PageMode)
	fmt.Fprintf(&b, "%-18s: %d\n", tr("并发", "Workers"), o.Workers)
	fmt.Fprintf(&b, "%-18s: %s\n", tr("压缩包密码", "Archive password"), yesNo(o.ArchivePass != "", en))
	fmt.Fprintf(&b, "%-18s: %s\n", tr("PDF 密码", "PDF password"), yesNo(o.PDFPass != "", en))
	fmt.Fprintf(&b, "%-18s: %d\n", tr("自定义页序", "Custom page order"), len(o.Order))
	b.WriteString("\n--- " + tr("问题明细", "Issues") + " ---\n")
	if fatal != nil {
		fmt.Fprintf(&b, "[%s] %v\n", tr("致命错误", "Fatal"), fatal)
	}
	if repaired > 0 {
		fmt.Fprintf(&b, "[%s] %d %s\n", tr("已自动补齐", "Repaired"), repaired,
			tr("张 JPEG 尾部数据不完整，已补齐并保留（不影响成品）",
				"truncated JPEG file(s) repaired and kept (output unaffected)"))
	}
	if len(warnings) == 0 && fatal == nil {
		b.WriteString(tr("（无）", "(none)") + "\n")
	}
	for i, w := range warnings {
		fmt.Fprintf(&b, "%3d. %s\n", i+1, w.localize())
	}
	b.WriteString("\n--- " + tr("建议", "Suggestions") + " ---\n")
	if en {
		b.WriteString("1. Truncated JPEG: re-download the image, or re-save it as JPG with Preview.\n")
		b.WriteString("2. HEIC/HEIF: batch-convert to JPG on macOS before adding it to the list.\n")
		b.WriteString("3. Many failures: check that the archive is complete, the password is correct, and no volumes are missing.\n")
		b.WriteString("4. When filing an issue, attach this report after removing private paths and filenames.\n")
	} else {
		b.WriteString("1. 若提示 JPEG 尾部数据不完整：重新下载该图片，或用「预览」打开后另存为 JPG。\n")
		b.WriteString("2. 若提示 HEIC/HEIF：先在 macOS 上批量转换成 JPG 再加入清单。\n")
		b.WriteString("3. 若大量图片失败：检查压缩包是否完整、密码是否正确、是否缺少分卷。\n")
		b.WriteString("4. 提交 issue 时请附上本报告，但务必删除其中的个人路径与文件名。\n")
	}
	return os.WriteFile(path, []byte(b.String()), 0644)
}

func yesNo(v bool, en bool) string {
	switch {
	case v && en:
		return "set"
	case v:
		return "已设置"
	case en:
		return "not set"
	default:
		return "未设置"
	}
}

// removeStaleReport deletes a previous report when a job finishes cleanly.
// Only our own known suffixes are removed, so an unrelated user file is safe.
func removeStaleReport(path string) {
	if path == "" {
		return
	}
	for _, suffix := range []string{"_错误报告.log", "_error_report.log", "_error.log"} {
		if strings.HasSuffix(path, suffix) {
			_ = os.Remove(path)
			return
		}
	}
}
