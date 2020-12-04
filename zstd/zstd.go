package main

import "C"

import (
	"encoding/base64"
	"io/ioutil"
	"log"
	"sync"

	"github.com/valyala/gozstd"
)

var (
	cdict *gozstd.CDict
	ddict *gozstd.DDict

	dictLocker sync.Mutex
)

//export InitDict
func InitDict(filename string, compressionLevel int) {
	dictLocker.Lock()
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		panic(err)
	}

	data, err = base64.StdEncoding.DecodeString(string(data))
	if err != nil {
		panic(err)
	}

	cdict, err = gozstd.NewCDict(data)
	if err != nil {
		panic(err)
	}

	ddict, err = gozstd.NewDDict(data)
	if err != nil {
		panic(err)
	}
	dictLocker.Unlock()
}

//export ReleaseDict
func ReleaseDict() {
	dictLocker.Lock()
	if cdict != nil {
		cdict.Release()
	}

	if ddict != nil {
		ddict.Release()
	}
	dictLocker.Unlock()
}

//export Base64Compress
func Base64Compress(cs string) *C.char {
	cdata := gozstd.Compress(nil, []byte(cs))

	return C.CString(base64.StdEncoding.EncodeToString(cdata))
}

//export Base64Decompress
func Base64Decompress(ds string) *C.char {
	ddata, err := base64.StdEncoding.DecodeString(ds)
	if err != nil {
		log.Printf("base64.StdEncoding.DecodeString(%s): %+v", ds, err)

		return C.CString("")
	}

	data, err := gozstd.Decompress(nil, ddata)
	if err != nil {
		log.Printf("zstd.Decompress(nil, %+v): %+v", ds, err)

		return C.CString("")
	}

	return C.CString(string(data))
}

//export Base64CompressWithDict
func Base64CompressWithDict(cs string) *C.char {
	if cdict == nil {
		log.Printf("zstd.CompressDict(%s): please init dict first.", cs)

		return C.CString("")
	}

	cdata := gozstd.CompressDict(nil, []byte(cs), cdict)

	return C.CString(base64.StdEncoding.EncodeToString(cdata))
}

//export Base64DecompressWithDict
func Base64DecompressWithDict(ds string) *C.char {
	if ddict == nil {
		log.Printf("zstd.DecompressDict(%s): please init dict first.", ds)

		return C.CString("")
	}

	ddata, err := base64.StdEncoding.DecodeString(ds)
	if err != nil {
		log.Printf("base64.StdEncoding.DecodeString(%s): %+v", ds, err)

		return C.CString("")
	}

	data, err := gozstd.DecompressDict(nil, ddata, ddict)
	if err != nil {
		log.Printf("zstd.DecompressDict(nil, %+v): %+v", ds, err)

		return C.CString("")
	}

	return C.CString(string(data))
}

func main() {
	// TODO
}
