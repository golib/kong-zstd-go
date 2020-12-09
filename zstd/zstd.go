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
func Compress(src string) (unsafe.Pointer, int) {
	cdata := gozstd.Compress(nil, []byte(src))
	if debug {
		log.Printf("[DEBUG] zstd.Compress(nil, %s): data=%s, size=%d", src, base64.StdEncoding.EncodeToString(cdata), len(cdata))
	}

	n := len(cdata)
	cb := C.CBytes(cdata)
	//C.free(cb)

	return cb, n
}

//export Decompress
func Decompress(ptr unsafe.Pointer, size C.int) *C.char {
	dst := C.GoBytes(ptr, size)

	ddata, err := gozstd.Decompress(nil, dst)
	if err != nil {
		log.Printf("zstd.Decompress(nil, %+v): %+v", base64.StdEncoding.EncodeToString(dst), err)

		return C.CString("")
	}
	if debug {
		log.Printf("[DEBUG] zstd.Decompress(nil, %+v): data=%s, size=%d", base64.StdEncoding.EncodeToString(dst), ddata, len(ddata))
	}

	ds := C.CString(string(ddata))
	//C.free(unsafe.Pointer(ds))

	return ds
}

//export CompressWithDict
func CompressWithDict(src, dict string) (unsafe.Pointer, int) {
	n := -1
	empty := C.CBytes([]byte(""))

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
		log.Printf("[DEBUG] zstd.CompressDict(nil, %s, %s): data=%+v, size=%d", src, dict, base64.StdEncoding.EncodeToString(cdata), len(cdata))
	}

	n = len(cdata)
	cb := C.CBytes(cdata)
	//C.free(cb)

	return cb, n
}

//export DecompressWithDict
func DecompressWithDict(ptr unsafe.Pointer, size C.int, dict string) *C.char {
	dst := C.GoBytes(ptr, size)

	value, ok := ddictStore.Load(dict)
	if !ok {
		log.Printf("zstd.DecompressDict(%s, %s): missing dict, please init first.", base64.StdEncoding.EncodeToString(dst), dict)

		return C.CString("")
	}

	ddict, ok := value.(*gozstd.DDict)
	if !ok {
		log.Printf("zstd.DecompressDict(%s, %s): invalid dict.", base64.StdEncoding.EncodeToString(dst), dict)

		return C.CString("")
	}

	data, err := gozstd.DecompressDict(nil, dst, ddict)
	if err != nil {
		log.Printf("zstd.DecompressDict(nil, %s, %s): %+v", base64.StdEncoding.EncodeToString(dst), dict, err)

		return C.CString("")
	}

	if debug {
		log.Printf("[DEBUG] zstd.DecompressDict(nil, %s, %s): data=%s, size=%d", base64.StdEncoding.EncodeToString(dst), dict, data, len(data))
	}

	ds := C.CString(string(data))
	//C.free(unsafe.Pointer(ds))

	return ds
}

func main() {
	// TODO
}
