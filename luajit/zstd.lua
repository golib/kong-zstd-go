local ffi = require("ffi")
local zstd = ffi.load("zstd/libzstd.so")

ffi.cdef([[
typedef struct { const char *p; ptrdiff_t n; } _GoString_;
typedef _GoString_ GoString;

typedef signed char GoInt8;
typedef unsigned char GoUint8;
typedef short GoInt16;
typedef unsigned short GoUint16;
typedef int GoInt32;
typedef unsigned int GoUint32;
typedef long long GoInt64;
typedef unsigned long long GoUint64;
typedef GoInt64 GoInt;
typedef GoUint64 GoUint;
typedef float GoFloat32;
typedef double GoFloat64;
typedef float _Complex GoComplex64;
typedef double _Complex GoComplex128;

typedef char _check_for_64_bit_pointer_matching_GoInt[sizeof(void*)==64/8 ? 1:-1];

typedef void *GoMap;
typedef void *GoChan;
typedef struct { void *t; void *v; } GoInterface;
typedef struct { void *data; GoInt len; GoInt cap; } GoSlice;

extern void InitDict(GoString filename, GoInt compressionLevel);
extern void ReleaseDict();
extern char* Base64Compress(GoString cs);
extern char* Base64Decompress(GoString ds);
extern char* Base64CompressWithDict(GoString cs);
extern char* Base64DecompressWithDict(GoString ds);
]])

-- define go types
local goStringType = ffi.metatype("GoString", {})

-- init dict
local filename = "luajit/zstd.dict"
local dictFilename = goStringType(filename, #filename)

zstd.InitDict(dictFilename, 3)


-- compress/decompress without dict
local actual = "Hello, world! This is a golang zstd binding for c with luajit."
local expected = "KLUv/SA+8QEASGVsbG8sIHdvcmxkISBUaGlzIGlzIGEgZ29sYW5nIHpzdGQgYmluZGluZyBmb3IgYyB3aXRoIGx1YWppdC4="

local compressInput = goStringType(actual, #actual)
local compressOutput = zstd.Base64Compress(compressInput)

io.write(string.format("Compressed without dict => %s\n", ffi.string(compressOutput)))
assert(ffi.string(compressOutput) == expected)

local data = ffi.string(compressOutput)
local decompressInput = goStringType(data, #data)
local decompressOutput = zstd.Base64Decompress(decompressInput)

io.write(string.format("Decompressed without dict => %s\n", ffi.string(decompressOutput)))
assert(ffi.string(decompressOutput) == actual)

-- compress/decompress with dict
local actualDict = "Hello, world! This is a golang zstd binding for c with luajit."
local expectedDict = "KLUv/SN7BtpvPvEBAEhlbGxvLCB3b3JsZCEgVGhpcyBpcyBhIGdvbGFuZyB6c3RkIGJpbmRpbmcgZm9yIGMgd2l0aCBsdWFqaXQu"

local compressDictInput = goStringType(actualDict, #actualDict)
local compressDictOutput = zstd.Base64CompressWithDict(compressDictInput)

io.write(string.format("Compressed with dict => %s\n", ffi.string(compressDictOutput)))
assert(ffi.string(compressDictOutput) == expectedDict)

local dataDict = ffi.string(compressDictOutput)
local decompressDictInput = goStringType(dataDict, #dataDict)
local decompressDictOutput = zstd.Base64DecompressWithDict(decompressDictInput)

io.write(string.format("Decompressed with dict => %s\n", ffi.string(decompressDictOutput)))
assert(ffi.string(decompressDictOutput) == actualDict)
