package main

/*
#cgo CFLAGS: -O3
#include <stdlib.h>  // for free
*/
import "C"

import (
	"encoding/base64"
	"io/ioutil"
	"log"
	"sync"
	"unsafe"

	"github.com/valyala/gozstd"
)

var (
	cdictStore = sync.Map{}
	ddictStore = sync.Map{}

	debug bool
)

func init() {
	log.SetFlags(log.Lshortfile | log.LstdFlags)
}

//export EnableDebug
func EnableDebug() {
	debug = true
}

//export DisableDebug
func DisableDebug() {
	debug = false
}

//export AddDict
func AddDict(name, filename string) {
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		log.Printf("AddDict(%s, %s): ioutil.ReaFile %+v", name, filename, err)

		panic(err)
	}

	data, err = base64.StdEncoding.DecodeString(string(data))
	if err != nil {
		log.Printf("AddDict(%s, %s): base64.StdEncoding.DecodeString %+v", name, filename, err)

		panic(err)
	}

	cdict, err := gozstd.NewCDict(data)
	if err != nil {
		log.Printf("AddDict(%s, %s): gozstd.NewCDict %+v", name, filename, err)

		panic(err)
	}

	ddict, err := gozstd.NewDDict(data)
	if err != nil {
		log.Printf("AddDict(%s, %s): gozstd.NewDDict %+v", name, filename, err)

		panic(err)
	}

	log.Printf("inited dict name=%s, filename=%s", name, filename)
	cdictStore.Store(name, cdict)
	ddictStore.Store(name, ddict)
}

//export ReleaseDict
func ReleaseDict() {
	cdictStore.Range(func(key, value interface{}) bool {
		if cdict, ok := value.(*gozstd.CDict); ok {
			cdict.Release()
		}

		cdictStore.Delete(key)

		return true
	})

	ddictStore.Range(func(key, value interface{}) bool {
		if ddict, ok := value.(*gozstd.DDict); ok {
			ddict.Release()
		}

		ddictStore.Delete(key)

		return true
	})

	cdictStore = sync.Map{}
	ddictStore = sync.Map{}
}

//export Compress
func Compress(src string) (*C.char, int) {
	cdata := gozstd.Compress(nil, []byte(src))
	if debug {
		log.Printf("[DEBUG] zstd.Compress(nil, %s): data=%+v, size=%d", src, cdata, len(cdata))
	}

	n := len(cdata)
	cs := C.CString(string(cdata))
	C.free(unsafe.Pointer(cs))

	return cs, n
}

//export Decompress
func Decompress(dst []byte) *C.char {
	ddata, err := gozstd.Decompress(nil, dst)
	if err != nil {
		log.Printf("zstd.Decompress(nil, %+v): %+v", dst, err)

		return C.CString("")
	}
	if debug {
		log.Printf("[DEBUG] zstd.Decompress(nil, %+v): data=%+v, size=%d", dst, ddata, len(ddata))
	}

	ds := C.CString(string(ddata))
	C.free(unsafe.Pointer(ds))

	return ds
}

//export CompressWithDict
func CompressWithDict(src, dict string) (*C.char, int) {
	n := -1
	empty := C.CString("")

	value, ok := cdictStore.Load(dict)
	if !ok {
		log.Printf("zstd.CompressDict(%s, %s): missing dict, please init first.", src, dict)

		return empty, n
	}

	cdict, ok := value.(*gozstd.CDict)
	if !ok {
		log.Printf("zstd.CompressDict(%s, %s): invalid dict.", src, dict)

		return empty, n
	}

	cdata := gozstd.CompressDict(nil, []byte(src), cdict)
	if debug {
		log.Printf("[DEBUG] zstd.CompressDict(nil, %s, %s): data=%+v, size=%d", src, dict, cdata, len(cdata))
	}

	n = len(cdata)
	cs := C.CString(string(cdata))
	C.free(unsafe.Pointer(cs))

	return cs, n
}

//export DecompressWithDict
func DecompressWithDict(dst []byte, dict string) *C.char {
	value, ok := ddictStore.Load(dict)
	if !ok {
		log.Printf("zstd.DecompressDict(%s, %s): missing dict, please init first.", dst, dict)

		return C.CString("")
	}

	ddict, ok := value.(*gozstd.DDict)
	if !ok {
		log.Printf("zstd.DecompressDict(%s, %s): invalid dict.", dst, dict)

		return C.CString("")
	}

	data, err := gozstd.DecompressDict(nil, dst, ddict)
	if err != nil {
		log.Printf("zstd.DecompressDict(nil, %s, %s): %+v", dst, dict, err)

		return C.CString("")
	}

	if debug {
		log.Printf("[DEBUG] zstd.DecompressDict(nil, %+v, %s): data=%+v, size=%d", dst, dict, data, len(data))
	}

	ds := C.CString(string(data))
	C.free(unsafe.Pointer(ds))

	return ds
}

func main() {
	// TODO
}
