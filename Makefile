GOROOT = $(shell go env GOROOT)
GOPATH = $(shell go env GOPATH)
GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)
GOOS_GOARCH := $(GOOS)_$(GOARCH)
GOOS_GOARCH_NATIVE := $(shell go env GOHOSTOS)_$(shell go env GOHOSTARCH)

all: goenv

goenv:
	@echo ++++++++++++++++++++++++++
	@echo + $(shell go version)
	@echo +
	@echo + GOROOT=$(GOROOT)
	@echo + GOPATH=$(GOPATH)
	@echo ++++++++++++++++++++++++++
	@echo

test: c-share test-luajit

c-share:
	go build -o lib/libzstd-$(GOOS_GOARCH).so -buildmode=c-shared zstd/zstd.go

test-luajit:
	luajit luajit/zstd.lua
