package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/bodgit/sevenzip"
	rardecode "github.com/nwaples/rardecode/v2"
	yekazip "github.com/yeka/zip"
)

// srcEntry describes one image, wherever it lives. path is the full path inside
// the archive (or the absolute path on disk) and is shown in the native UI.
type srcEntry struct {
	name string
	path string
	size int64
	open func() (io.ReadCloser, error)
}

// collectSources returns image entries in natural path order.
// The returned cleanup must be called after all entries are consumed.
func collectSources(src, password string) ([]srcEntry, func(), error) {
	st, err := os.Stat(src)
	if err != nil {
		return nil, nil, EW("err.inputPath", "Input path not found: {0}", err, A(err)...)
	}
	if st.IsDir() {
		var out []srcEntry
		err = filepath.WalkDir(src, func(p string, d os.DirEntry, e error) error {
			if e != nil {
				return e
			}
			if d.IsDir() || !isImageName(d.Name()) {
				return nil
			}
			full := p
			var size int64
			if fi, e2 := d.Info(); e2 == nil {
				size = fi.Size()
			}
			out = append(out, srcEntry{
				name: d.Name(),
				path: p,
				size: size,
				open: func() (io.ReadCloser, error) {
					return os.Open(full)
				},
			})
			return nil
		})
		if err != nil {
			return nil, nil, err
		}
		sortEntries(out)
		return out, func() {}, nil
	}

	switch strings.ToLower(filepath.Ext(src)) {
	case ".zip":
		return collectZip(src, password)
	case ".7z":
		return collect7z(src, password)
	case ".rar":
		return collectRar(src, password)
	default:
		return nil, nil, E("err.format", "Unsupported archive format {0}; use an encrypted .zip / .7z / .rar or an image folder",
			A(fmt.Sprintf("%q", filepath.Ext(src)))...)
	}
}

func sortEntries(e []srcEntry) {
	sort.SliceStable(e, func(i, j int) bool { return naturalLess(e[i].path, e[j].path) })
}

func collectZip(path, password string) ([]srcEntry, func(), error) {
	r, err := yekazip.OpenReader(path)
	if err != nil {
		return nil, nil, EW("err.zipOpen", "Could not open ZIP: {0}", err, A(err)...)
	}
	var out []srcEntry
	for _, f := range r.File {
		if f.FileInfo().IsDir() || !isImageName(f.Name) {
			continue
		}
		if f.IsEncrypted() {
			if password == "" {
				_ = r.Close()
				return nil, nil, E("err.zipEncrypted", "This archive is encrypted; enter its password")
			}
			f.SetPassword(password)
		}
		file := f
		out = append(out, srcEntry{
			name: filepath.Base(file.Name),
			path: file.Name,
			size: int64(file.UncompressedSize64),
			open: func() (io.ReadCloser, error) {
				rc, e := file.Open()
				if e != nil {
					return nil, EW("err.extract", "Extraction failed (the archive password may be wrong): {0}", e, A(e)...)
				}
				return rc, nil
			},
		})
	}
	sortEntries(out)
	return out, func() { _ = r.Close() }, nil
}

func collect7z(path, password string) ([]srcEntry, func(), error) {
	r, err := sevenzip.OpenReaderWithPassword(path, password)
	if err != nil {
		// Retry without a password for unencrypted archives.
		r2, err2 := sevenzip.OpenReader(path)
		if err2 != nil {
			return nil, nil, EW("err.7zOpen", "Could not open 7z (the password may be wrong): {0}", err, A(err)...)
		}
		r = r2
	}
	var out []srcEntry
	for _, f := range r.File {
		if f.FileInfo().IsDir() || !isImageName(f.Name) {
			continue
		}
		file := f
		out = append(out, srcEntry{
			name: filepath.Base(file.Name),
			path: file.Name,
			size: file.FileInfo().Size(),
			open: func() (io.ReadCloser, error) {
				rc, e := file.Open()
				if e != nil {
					return nil, EW("err.extract", "Extraction failed (the archive password may be wrong): {0}", e, A(e)...)
				}
				return rc, nil
			},
		})
	}
	sortEntries(out)
	return out, func() { _ = r.Close() }, nil
}

// collectRar handles RAR 4.x and RAR 5, including AES-encrypted archives.
// rardecode is pure Go, so no unrar binary is needed inside the app.
func collectRar(path, password string) ([]srcEntry, func(), error) {
	list := func(pass string) ([]*rardecode.File, error) {
		opts := []rardecode.Option{}
		if pass != "" {
			opts = append(opts, rardecode.Password(pass))
		}
		return rardecode.List(path, opts...)
	}

	files, err := list(password)
	if err != nil && password != "" {
		// An archive may be plain even when a password was supplied.
		files, err = list("")
	}
	if err != nil {
		if errors.Is(err, rardecode.ErrBadPassword) {
			return nil, nil, E("err.rarPass", "Incorrect RAR archive password")
		}
		return nil, nil, EW("err.rarOpen", "Could not open RAR (wrong password, unsupported encryption, or missing volumes): {0}", err, A(err)...)
	}

	var out []srcEntry
	for _, f := range files {
		if f.IsDir || !isImageName(f.Name) {
			continue
		}
		file := f
		out = append(out, srcEntry{
			name: filepath.Base(file.Name),
			path: file.Name,
			size: file.UnPackedSize,
			open: func() (io.ReadCloser, error) {
				rc, e := file.Open()
				if e != nil {
					return nil, EW("err.extract", "Extraction failed (the archive password may be wrong): {0}", e, A(e)...)
				}
				return rc, nil
			},
		})
	}
	sortEntries(out)
	return out, func() {}, nil
}
