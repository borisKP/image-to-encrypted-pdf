package main

import (
	"crypto/rand"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

//go:embed ui.html
var uiHTML string

var sessionToken string

func serveUI(openBrowser bool) error {
	tok := make([]byte, 16)
	if _, err := rand.Read(tok); err != nil {
		return err
	}
	sessionToken = hex.EncodeToString(tok)
	job := newJob()

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(uiHTML))
	})
	mux.HandleFunc("/api/status", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, job.status())
	})
	mux.HandleFunc("/api/start", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		var o Options
		if err := json.NewDecoder(r.Body).Decode(&o); err != nil {
			writeJSON(w, map[string]any{"ok": false, "error": err.Error()})
			return
		}
		o.Source = strings.TrimSpace(o.Source)
		o.OutPath = strings.TrimSpace(o.OutPath)
		if o.Source == "" {
			writeJSON(w, map[string]any{"ok": false, "error": "Select an archive or folder first"})
			return
		}
		if o.OutPath == "" {
			writeJSON(w, map[string]any{"ok": false, "error": "Enter an output file name"})
			return
		}
		writeJSON(w, map[string]any{"ok": job.start(o)})
	})
	mux.HandleFunc("/api/browse", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		kind := r.URL.Query().Get("kind")
		p, err := browse(kind)
		if err != nil {
			writeJSON(w, map[string]any{"ok": false, "error": err.Error()})
			return
		}
		writeJSON(w, map[string]any{"ok": true, "path": p})
	})
	mux.HandleFunc("/api/save", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		p, err := browse("save")
		if err != nil {
			writeJSON(w, map[string]any{"ok": false, "error": err.Error()})
			return
		}
		if !strings.HasSuffix(strings.ToLower(p), ".pdf") {
			p += ".pdf"
		}
		writeJSON(w, map[string]any{"ok": true, "path": p})
	})
	mux.HandleFunc("/api/default-out", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		var req struct {
			Source string `json:"source"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		writeJSON(w, map[string]any{"path": defaultOutPath(req.Source)})
	})
	mux.HandleFunc("/api/reveal", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		var req struct {
			Path string `json:"path"`
		}
		_ = json.NewDecoder(r.Body).Decode(&req)
		go reveal(req.Path)
		writeJSON(w, map[string]any{"ok": true})
	})
	mux.HandleFunc("/api/quit", func(w http.ResponseWriter, r *http.Request) {
		if !auth(r) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		writeJSON(w, map[string]any{"ok": true})
		go func() {
			os.Exit(0)
		}()
	})

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return err
	}
	url := fmt.Sprintf("http://127.0.0.1:%d/?t=%s", ln.Addr().(*net.TCPAddr).Port, sessionToken)
	writeStartupInfo(url)
	fmt.Println("Image to Encrypted PDF is running")
	fmt.Println("Open this URL in your browser: " + url)
	fmt.Println("Click Quit in the page top-right corner to stop.")
	if openBrowser {
		go openURL(url)
	}
	return http.Serve(ln, mux)
}

func auth(r *http.Request) bool {
	return r.Header.Get("X-Token") == sessionToken || r.URL.Query().Get("t") == sessionToken
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(v)
}

func defaultOutPath(src string) string {
	src = strings.TrimSpace(src)
	if src == "" {
		return filepath.Join(homeDir(), "images_encrypted.pdf")
	}
	base := src
	if st, err := os.Stat(src); err == nil && !st.IsDir() {
		base = filepath.Dir(src)
	} else if st, err := os.Stat(src); err == nil && st.IsDir() {
		base = filepath.Dir(src)
	}
	return filepath.Join(base, "images_encrypted.pdf")
}

func homeDir() string {
	h, err := os.UserHomeDir()
	if err != nil {
		return "."
	}
	return h
}

func openURL(url string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", url)
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", url)
	default:
		cmd = exec.Command("xdg-open", url)
	}
	_ = cmd.Start()
}

func reveal(path string) {
	if path == "" {
		return
	}
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		cmd = exec.Command("open", "-R", path)
	case "windows":
		cmd = exec.Command("explorer", "/select,"+path)
	default:
		cmd = exec.Command("xdg-open", filepath.Dir(path))
	}
	_ = cmd.Start()
}

func writeStartupInfo(url string) {
	info := "Image to Encrypted PDF is running.\n\n" +
		"If the browser did not open automatically, paste this URL into the address bar:\n" + url + "\n\n" +
		"Click Quit in the page top-right corner or stop this process.\n" +
		"This file is refreshed on every launch and can be deleted.\n"
	exe, err := os.Executable()
	dir := "."
	if err == nil {
		dir = filepath.Dir(exe)
	}
	if err := os.WriteFile(filepath.Join(dir, "start_url.txt"), []byte(info), 0644); err != nil {
		_ = os.WriteFile(filepath.Join(homeDir(), "start_url.txt"), []byte(info), 0644)
	}
}

func browse(kind string) (string, error) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		switch kind {
		case "folder":
			cmd = exec.Command("osascript", "-e", `POSIX path of (choose folder with prompt "Select the folder containing images")`)
		case "save":
			cmd = exec.Command("osascript", "-e", `POSIX path of (choose file name with prompt "Save PDF to" default name "images_encrypted.pdf")`)
		default:
			cmd = exec.Command("osascript", "-e", `POSIX path of (choose file with prompt "Select an encrypted archive (.zip / .7z)")`)
		}
	case "windows":
		var script string
		switch kind {
		case "folder":
			script = `Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description = 'Select the image folder'; if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { [Console]::WriteLine($d.SelectedPath) }`
		case "save":
			script = `Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.SaveFileDialog; $d.Filter = 'PDF files (*.pdf)|*.pdf'; $d.FileName = 'images_encrypted.pdf'; $d.Title = 'Save PDF to'; if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { [Console]::WriteLine($d.FileName) }`
		default:
			script = `Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Filter = 'Archives (*.zip;*.7z)|*.zip;*.7z|All files (*.*)|*.*'; $d.Title = 'Select an encrypted archive'; if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { [Console]::WriteLine($d.FileName) }`
		}
		cmd = exec.Command("powershell", "-NoProfile", "-STA", "-Command", script)
	default:
		return "", fmt.Errorf("No file picker on this platform; paste the full path instead")
	}
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("Selection cancelled or failed: %v", err)
	}
	p := strings.TrimSpace(string(out))
	if p == "" {
		return "", fmt.Errorf("Nothing selected")
	}
	return p, nil
}
