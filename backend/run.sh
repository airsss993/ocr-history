#!/bin/bash

# Unset problematic environment variables
unset GOROOT
unset _INTELLIJ_FORCE_SET_GOROOT

# Set CGO flags to find Tesseract and Leptonica
# CPPFLAGS is used by the gosseract library
export CGO_CPPFLAGS="-I/opt/homebrew/Cellar/leptonica/1.86.0/include -I/opt/homebrew/Cellar/tesseract/5.5.1_1/include"
export CGO_CXXFLAGS="-std=c++0x"
export CGO_LDFLAGS="-L/opt/homebrew/lib -lleptonica -ltesseract"
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig"

# Run the application
cd "$(dirname "$0")"
go run cmd/app/main.go
