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

/* Return type for Compress */
struct GoCompressResult {
	char* data;
	GoInt size;
};

extern void EnableDebug();
extern void DisableDebug();
extern void AddDict(GoString name, GoString filename);
extern void ReleaseDict();
extern struct GoCompressResult Compress(GoString src);
extern char* Decompress(GoSlice dst);
extern struct GoCompressResult CompressWithDict(GoString src, GoString dict);
extern char* DecompressWithDict(GoSlice dst, GoString dict);

]])

-- define go types
local goStringType = ffi.metatype("GoString", {})
local goSliceType = ffi.metatype("GoSlice", {})

-- init dict
local name = "testing"
local filename = "luajit/zstd.dict"

local dictName = goStringType(name, #name)
local dictFilename = goStringType(filename, #filename)

zstd.EnableDebug()
zstd.AddDict(dictName, dictFilename)

-- compress/decompress without dict
local actual = "Hello, world! This is a golang zstd binding for c with luajit."

local compressInput = goStringType(actual, #actual)

local compressOutput = zstd.Compress(compressInput)
io.write(string.format("Compressed without dict => type=%s, size=%d\n", ffi.typeof(compressOutput), ffi.sizeof(compressOutput)))

local compressResult = ffi.new("struct GoCompressResult", compressOutput)
io.write(string.format("Compressed without dict => type=%s, size=%d\n", ffi.typeof(compressResult), ffi.sizeof(compressResult)))
io.write(string.format("Compressed without dict => data=%s, size=%d\n", ffi.typeof(compressResult.data), tonumber(compressResult.size)))

local decompressInput = goSliceType(compressResult.data, compressResult.size, compressResult.size)
local decompressOutput = zstd.Decompress(decompressInput)

io.write(string.format("Decompressed without dict => %s\n", ffi.string(decompressOutput)))
assert(ffi.string(decompressOutput) == actual)

-- compress/decompress with dict
local actualDict = "Hello, world! This is a golang zstd binding for c with luajit."

local compressDictInput = goStringType(actualDict, #actualDict)

local compressDictOutput = zstd.CompressWithDict(compressDictInput, dictName)
io.write(string.format("Compressed with dict => type=%s, size=%d\n", ffi.typeof(compressDictOutput), ffi.sizeof(compressDictOutput)))

local compressDictResult = ffi.new("struct GoCompressResult", compressDictOutput)
io.write(string.format("Compressed with dict => type=%s, size=%d\n", ffi.typeof(compressDictResult), ffi.sizeof(compressDictResult)))
io.write(string.format("Compressed with dict => data=%s, size=%d\n", ffi.typeof(compressDictResult.data), tonumber(compressDictResult.size)))

local decompressDictInput = goSliceType(compressDictResult.data, compressDictResult.size, compressDictResult.size)
local decompressDictOutput = zstd.DecompressWithDict(decompressDictInput, dictName)

io.write(string.format("Decompressed with dict => %s\n", ffi.string(decompressDictOutput)))
assert(ffi.string(decompressDictOutput) == actualDict)
