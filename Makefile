# Image to Encrypted PDF — developer entry points.
# Run from the repository root (the directory that contains VERSION).
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Resolve the Go toolchain: prefer a vendored SDK in the parent workspace
# (used by offline builds), otherwise rely on whatever `go` is on PATH
# (CI installs it with actions/setup-go). Mirrors macapp/build_macos.sh.
VENDORED_GO := $(abspath $(CURDIR)/../.build/go/bin)
ifneq ($(wildcard $(VENDORED_GO)/go),)
export PATH := $(VENDORED_GO):$(PATH)
endif

.PHONY: help version verify-version fmt-check engine-test test build clean

help: ## List all available commands
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

version: ## Print the current version (single source: VERSION)
	@cat VERSION

verify-version: ## Check that VERSION / App.swift / version.go / Info.plist agree
	@V=$$(tr -d '[:space:]' < VERSION); \
	 [ -n "$$V" ] || { echo "VERSION is empty" >&2; exit 1; }; \
	 grep -q "UIAppVersion = \"$$V\"" macapp/App.swift || { echo "version drift: macapp/App.swift != $$V" >&2; exit 1; }; \
	 grep -q "AppVersion = \"$$V\"" imgtopdf/version.go || { echo "version drift: imgtopdf/version.go != $$V" >&2; exit 1; }; \
	 grep -q "<string>$$V</string>" macapp/Info.plist || { echo "version drift: macapp/Info.plist != $$V" >&2; exit 1; }; \
	 echo "version $$V OK"

fmt-check: ## Check Go formatting
	@command -v gofmt >/dev/null || { echo "gofmt not found; install Go or add it to PATH" >&2; exit 1; }; \
	 out=$$(gofmt -l imgtopdf/*.go); \
	 if [ -n "$$out" ]; then echo "gofmt needed:"; echo "$$out"; exit 1; fi; \
	 echo "gofmt clean"

engine-test: ## Run Go engine unit and end-to-end tests
	cd imgtopdf && go test ./... -count=1 -v

test: verify-version fmt-check engine-test ## Full fast check (no app build)

build: verify-version fmt-check ## Build Universal 2 .app / DMG / ZIP
	bash macapp/build_macos.sh

clean: ## Remove build intermediates (does not touch delivered files)
	rm -rf .build/app .build/dmgstage .build/AppIcon.iconset
	rm -f .build/bin/ui_* .build/bin/helper_*
