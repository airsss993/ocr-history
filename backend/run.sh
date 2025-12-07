#!/bin/bash

# Unset problematic environment variables
unset GOROOT
unset _INTELLIJ_FORCE_SET_GOROOT

# Run the application
cd "$(dirname "$0")"
go run cmd/app/main.go
