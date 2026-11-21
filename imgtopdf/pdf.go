package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"
)

type pdfObj struct {
	dict        string // may contain %LEN% placeholder
	stream      []byte
	skipEncrypt bool
}

func buildPDF(pages []processedPage, pageMode string) []pdfObj {
	n := len(pages)
	kids := make([]string, 0, n)
	for i := 0; i < n; i++ {
		kids = append(kids, fmt.Sprintf("%d 0 R", 3+i*3))
	}
	objs := make([]pdfObj, 0, 2+3*n)
	objs = append(objs, pdfObj{dict: "<< /Type /Catalog /Pages 2 0 R >>\n"})
	objs = append(objs, pdfObj{
		dict: fmt.Sprintf("<< /Type /Pages /Kids [%s] /Count %d >>\n", strings.Join(kids, " "), n),
	})

	for i, p := range pages {
		pageNum := 3 + i*3
		contentNum := pageNum + 1
		imageNum := pageNum + 2

		var pageW, pageH, drawW, drawH, x, y float64
		if pageMode == "fit" {
			pageW, pageH = float64(p.w)*0.75, float64(p.h)*0.75
			drawW, drawH, x, y = pageW, pageH, 0, 0
		} else {
			// A4, orientation follows the image, with a small margin.
			const a4w, a4h, margin = 595.28, 841.89, 8.0
			if p.w >= p.h {
				pageW, pageH = a4h, a4w
			} else {
				pageW, pageH = a4w, a4h
			}
			availW, availH := pageW-2*margin, pageH-2*margin
			s := availW / float64(p.w)
			if s*float64(p.h) > availH {
				s = availH / float64(p.h)
			}
			drawW, drawH = float64(p.w)*s, float64(p.h)*s
			x, y = (pageW-drawW)/2, (pageH-drawH)/2
		}

		pageDict := fmt.Sprintf(
			"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] "+
				"/Resources << /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>\n",
			pageW, pageH, imageNum, contentNum)
		objs = append(objs, pdfObj{dict: pageDict})

		content := fmt.Sprintf("q\n%.4f 0 0 %.4f %.4f %.4f cm\n/Im0 Do\nQ\n", drawW, drawH, x, y)
		objs = append(objs, pdfObj{
			dict:   "<< /Length %LEN% >>\n",
			stream: []byte(content),
		})

		imageDict := fmt.Sprintf(
			"<< /Type /XObject /Subtype /Image /Width %d /Height %d "+
				"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length %%LEN%% >>\n",
			p.w, p.h)
		objs = append(objs, pdfObj{dict: imageDict, stream: p.jpeg})
	}
	return objs
}

func renderPDF(objs []pdfObj, enc *pdfEncryption, encryptObjNum int) ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteString("%PDF-1.7\n%\xe2\xe3\xcf\xd3\n")
	offsets := make([]int, 0, len(objs)+1)
	offsets = append(offsets, 0)

	for i, o := range objs {
		offsets = append(offsets, buf.Len())
		data := o.stream
		if enc != nil && !o.skipEncrypt && data != nil {
			data = enc.encryptStream(data)
		}
		dict := o.dict
		if strings.Contains(dict, "%LEN%") {
			dict = strings.ReplaceAll(dict, "%LEN%", fmt.Sprintf("%d", len(data)))
		}
		fmt.Fprintf(&buf, "%d 0 obj\n%s", i+1, dict)
		if data != nil {
			buf.WriteString("stream\n")
			buf.Write(data)
			buf.WriteString("\nendstream\n")
		}
		buf.WriteString("endobj\n")
	}

	xref := buf.Len()
	fmt.Fprintf(&buf, "xref\n0 %d\n", len(objs)+1)
	buf.WriteString("0000000000 65535 f \n")
	for _, off := range offsets[1:] {
		fmt.Fprintf(&buf, "%010d 00000 n \n", off)
	}

	id1, id2 := make([]byte, 16), make([]byte, 16)
	if _, err := rand.Read(id1); err != nil {
		return nil, err
	}
	if _, err := rand.Read(id2); err != nil {
		return nil, err
	}
	encRef := ""
	if encryptObjNum > 0 {
		encRef = fmt.Sprintf(" /Encrypt %d 0 R", encryptObjNum)
	}
	fmt.Fprintf(&buf, "trailer\n<< /Size %d /Root 1 0 R /ID [<%s><%s>]%s >>\nstartxref\n%d\n%%%%EOF\n",
		len(objs)+1, hex.EncodeToString(id1), hex.EncodeToString(id2), encRef, xref)
	return buf.Bytes(), nil
}
