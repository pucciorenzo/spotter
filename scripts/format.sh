#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftformat >/dev/null 2>&1; then
    echo "format: SwiftFormat is not installed. Install with: brew install swiftformat" >&2
    exit 127
fi

swiftformat \
    iOSApp \
    WatchApp \
    Shared/Sources \
    Shared/Tests \
    SpotterLiveActivities \
    --config "$ROOT_DIR/.swiftformat" \
    --cache ignore
