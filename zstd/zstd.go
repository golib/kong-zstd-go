package main

import (
	"log"

	"github.com/valyala/gozstd"
)

import "C"

//export Compress
func Compress(cs *C.char) *C.char {
	src := C.GoString(cs)

	cdata := gozstd.Compress(nil, []byte(src))

	return C.CString(string(cdata))
}

//export Decompress
func Decompress(ds *C.char) *C.char {
	dst := C.GoString(ds)

	ddata, err := gozstd.Decompress(nil, []byte(dst))
	if err != nil {
		log.Printf("zstd.Decompress(nil, %+v): %+v", dst, err)
		return C.CString("")
	}

	return C.CString(string(ddata))
}

func main() {

}
