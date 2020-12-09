GOROOT = $(shell go env GOROOT)
GOPATH = $(shell go env GOPATH)

all: goenv

goenv:
	@echo ++++++++++++++++++++++++++
	@echo + $(shell go version)
	@echo +
	@echo + GOROOT=$(GOROOT)
	@echo + GOPATH=$(GOPATH)
	@echo ++++++++++++++++++++++++++
	@echo

c-share:
	go build -o zstd/libzstd.so -buildmode=c-shared zstd/zstd.go


test-lua:
	luajit luajit/zstd.lua