local ffi = require("ffi")
local encoding = require("luajit/base64")

io.write(string.format("Running os=%s, arch=%s\n", jit.os, jit.arch))

local zstd
if jit.os == 'OSX' then
    zstd = ffi.load("lib/libzstd-darwin_amd64.so")
elseif jit.os == 'Linux' then
    zstd = ffi.load("lib/libzstd-linux_amd64.so")
end

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
typedef struct GoCompressResult { void* data; GoInt size; } GoCompressResult;

extern void EnableDebug();
extern void DisableDebug();
extern void AddDict(GoString name, GoString filename);
extern void ReleaseDict();
extern struct GoCompressResult Compress(GoString src);
extern char* Decompress(void* ptr, int size);
extern struct GoCompressResult CompressWithDict(GoString src, GoString dict);
extern char* DecompressWithDict(void* ptr, int size, GoString dict);

]])

-- define go types
local goStringType = ffi.metatype("GoString", {})
local goCompressResultType = ffi.metatype("GoCompressResult", {})

-- init dict
local name = "testing"
local filename = "luajit/zstd.dict"

local dictName = goStringType(name, #name)
local dictFilename = goStringType(filename, #filename)

zstd.EnableDebug()
zstd.AddDict(dictName, dictFilename)

-- compress/decompress without dict
io.write("\n-- compress/decompress without dict\n")
local actual = "Hello, world! This is a golang zstd binding for c with luajit."

-- compress with GoString
local compressInput = goStringType(actual, #actual)
local compressOutput = zstd.Compress(compressInput)
io.write(string.format("Compressed without dict output => lua type=%s, ffi type=%s, ffi size=%d\n", type(compressOutput), ffi.typeof(compressOutput), ffi.sizeof(compressOutput)))

local compressResult = ffi.new("struct GoCompressResult", compressOutput)
io.write(string.format("Compressed without dict result => lua type=%s, ffi type=%s, size=%d\n", type(compressResult.data), ffi.typeof(compressResult.data), tonumber(compressResult.size)))

-- decompress with char* and int
local decompressOutput = zstd.Decompress(compressResult.data, compressResult.size)
io.write(string.format("Decompressed without dict output => %s\n", ffi.string(decompressOutput)))
assert(ffi.string(decompressOutput) == actual)

-- compress/decompress with dict
io.write("\n-- compress/decompress with dict\n")
local dictActual = "Hello, world! This is a golang zstd binding for c with luajit and dict."

-- compress with GoString by dict
local dictCompressInput = goStringType(dictActual, #dictActual)
local dictCompressOutput = zstd.CompressWithDict(dictCompressInput, dictName)
io.write(string.format("Compressed with dict output => lua type=%s, ffi type=%s, ffi size=%d\n", type(dictCompressOutput), ffi.typeof(dictCompressOutput), ffi.sizeof(dictCompressOutput)))

local dictCompressResult = ffi.new("struct GoCompressResult", dictCompressOutput)
io.write(string.format("Compressed with dict result => lua type=%s, ffi type=%s, size=%d\n", type(dictCompressResult.data), ffi.typeof(dictCompressResult.data), tonumber(dictCompressResult.size)))

-- decompress with char* and int by dict
local dedictCompressOutput = zstd.DecompressWithDict(dictCompressResult.data, dictCompressResult.size, dictName)
io.write(string.format("Decompressed with dict output => %s\n", ffi.string(dedictCompressOutput)))
assert(ffi.string(dedictCompressOutput) == dictActual)

-- for ngx
io.write("\n-- for ngx\n")
local ngData = from_base64("KLUv/SA+8QEASGVsbG8sIHdvcmxkISBUaGlzIGlzIGEgZ29sYW5nIHpzdGQgYmluZGluZyBmb3IgYyB3aXRoIGx1YWppdC4=")
io.write(string.format("ngdata => data=%s, size=%d\n", type(ngData), #ngData))

local ngResult = goCompressResultType(ffi.new("char[?]", #ngData, ngData), #ngData)

local ngOutput = zstd.Decompress(ngResult.data, ngResult.size)
io.write(string.format("Decompressed without dict => %s\n", ffi.string(ngOutput)))
