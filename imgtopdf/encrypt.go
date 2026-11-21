package main

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"crypto/sha512"
	"encoding/binary"
	"encoding/hex"
	"fmt"
)

// pdfEncryption implements PDF 2.0 / AES-256 (V=5, R=6, AESV3).
type pdfEncryption struct {
	key []byte
}

func newPDFEncryption(userPwd, ownerPwd string) (*pdfEncryption, *pdfObj, error) {
	u := []byte(userPwd)
	o := []byte(ownerPwd)
	if len(u) > 127 {
		u = u[:127]
	}
	if len(o) > 127 {
		o = o[:127]
	}
	if len(o) == 0 {
		o = u
	}

	randBytes := func(n int) []byte {
		b := make([]byte, n)
		if _, err := rand.Read(b); err != nil {
			panic(err)
		}
		return b
	}

	fileKey := randBytes(32)
	uSalt := randBytes(16)
	oSalt := randBytes(16)
	uVal, uKey := uSalt[:8], uSalt[8:]
	oVal, oKey := oSalt[:8], oSalt[8:]

	uv := hashR6(u, uVal, nil)
	uValue := append(append(append([]byte{}, uv...), uVal...), uKey...)
	uTmpKey := hashR6(u, uKey, nil)
	ueValue := aesCBCNoPad(uTmpKey, make([]byte, 16), fileKey)

	ov := hashR6(o, oVal, uValue)
	oValue := append(append(append([]byte{}, ov...), oVal...), oKey...)
	oTmpKey := hashR6(o, oKey, uValue[:48])
	oeValue := aesCBCNoPad(oTmpKey, make([]byte, 16), fileKey)

	// Permissions: all operations allowed (0xFFFFFFFC), metadata encrypted.
	permsBlock := make([]byte, 16)
	binary.LittleEndian.PutUint32(permsBlock[0:4], 0xFFFFFFFC)
	copy(permsBlock[4:8], []byte{0xff, 0xff, 0xff, 0xff})
	copy(permsBlock[8:12], []byte{'T', 'a', 'd', 'b'})
	copy(permsBlock[12:16], randBytes(4))
	permsValue := aesECB(fileKey, permsBlock)

	hexStr := func(b []byte) string { return "<" + hex.EncodeToString(b) + ">" }
	dict := fmt.Sprintf(
		"<< /Filter /Standard /V 5 /R 6 /Length 256 "+
			"/CF << /StdCF << /Type /CryptFilter /CFM /AESV3 /Length 32 /AuthEvent /DocOpen >> >> "+
			"/StmF /StdCF /StrF /StdCF "+
			"/O %s /U %s /OE %s /UE %s /Perms %s /P -4 >>\n",
		hexStr(oValue), hexStr(uValue), hexStr(oeValue), hexStr(ueValue), hexStr(permsValue))

	return &pdfEncryption{key: fileKey}, &pdfObj{dict: dict, skipEncrypt: true}, nil
}

// hashR6 implements ISO 32000-2 Algorithm 2.B (revision 6 password hash).
func hashR6(password, salt, udata []byte) []byte {
	init := sha256.Sum256(join3(password, salt, udata))
	k := append([]byte{}, init[:]...)
	count := 0
	for {
		count++
		unit := join3(password, k, udata)
		k1 := bytes.Repeat(unit, 64)
		block, err := aes.NewCipher(k[:16])
		if err != nil {
			panic(err)
		}
		e := make([]byte, len(k1))
		cipher.NewCBCEncrypter(block, k[16:32]).CryptBlocks(e, k1)
		sum := 0
		for _, v := range e[:16] {
			sum += int(v)
		}
		switch sum % 3 {
		case 0:
			h := sha256.Sum256(e)
			k = append([]byte{}, h[:]...)
		case 1:
			h := sha512.Sum384(e)
			k = append([]byte{}, h[:]...)
		default:
			h := sha512.Sum512(e)
			k = append([]byte{}, h[:]...)
		}
		if count >= 64 && int(e[len(e)-1]) <= count-32 {
			break
		}
	}
	return k[:32]
}

func join3(a, b, c []byte) []byte {
	out := make([]byte, 0, len(a)+len(b)+len(c))
	out = append(out, a...)
	out = append(out, b...)
	out = append(out, c...)
	return out
}

func aesCBCNoPad(key, iv, data []byte) []byte {
	block, err := aes.NewCipher(key)
	if err != nil {
		panic(err)
	}
	out := make([]byte, len(data))
	cipher.NewCBCEncrypter(block, iv).CryptBlocks(out, data)
	return out
}

func aesECB(key, data []byte) []byte {
	block, err := aes.NewCipher(key)
	if err != nil {
		panic(err)
	}
	out := make([]byte, len(data))
	for i := 0; i < len(data); i += 16 {
		block.Encrypt(out[i:i+16], data[i:i+16])
	}
	return out
}

func (e *pdfEncryption) encryptStream(data []byte) []byte {
	iv := make([]byte, 16)
	if _, err := rand.Read(iv); err != nil {
		panic(err)
	}
	pad := 16 - len(data)%16
	padded := make([]byte, 0, len(data)+pad)
	padded = append(padded, data...)
	padded = append(padded, bytes.Repeat([]byte{byte(pad)}, pad)...)
	block, err := aes.NewCipher(e.key)
	if err != nil {
		panic(err)
	}
	out := make([]byte, 16+len(padded))
	copy(out, iv)
	cipher.NewCBCEncrypter(block, iv).CryptBlocks(out[16:], padded)
	return out
}
