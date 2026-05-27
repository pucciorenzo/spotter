#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "lint: SwiftLint is not installed. Install with: brew install swiftlint" >&2
    exit 127
fi

swiftlint lint --strict --no-cache --config "$ROOT_DIR/.swiftlint.yml"
