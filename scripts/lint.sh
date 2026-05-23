#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

swift_files="$(mktemp)"
trap 'rm -f "$swift_files"' EXIT

git ls-files '*.swift' > "$swift_files"

if [ ! -s "$swift_files" ]; then
    echo "lint: no Swift files found"
    exit 1
fi

status=0

report_check() {
    local title="$1"
    local output="$2"

    if [ -n "$output" ]; then
        printf '\n%s\n' "$title"
        printf '%s\n' "$output"
        status=1
    fi
}

check_awk() {
    local title="$1"
    local script="$2"
    local output=""

    while IFS= read -r file; do
        [ -f "$file" ] || continue
        result="$(awk "$script" "$file")"
        if [ -n "$result" ]; then
            output="${output}${result}"$'\n'
        fi
    done < "$swift_files"

    report_check "$title" "$output"
}

check_grep() {
    local title="$1"
    local pattern="$2"
    local output=""

    while IFS= read -r file; do
        [ -f "$file" ] || continue
        result="$(grep -nEH "$pattern" "$file" || true)"
        if [ -n "$result" ]; then
            output="${output}${result}"$'\n'
        fi
    done < "$swift_files"

    report_check "$title" "$output"
}

check_grep "lint: unresolved merge conflict markers" '^(<<<<<<<|=======|>>>>>>>)'
check_awk "lint: trailing whitespace" '/[[:blank:]]$/ { printf "%s:%d: trailing whitespace\n", FILENAME, FNR }'
check_awk "lint: leading tab indentation" '/^\t+/ { printf "%s:%d: leading tab indentation\n", FILENAME, FNR }'
check_grep "lint: unsafe force try/cast" '(^|[^[:alnum:]_])(try!|as!)([^[:alnum:]_]|$)'
check_grep "lint: debug print statements" '(^|[^[:alnum:]_])print[[:space:]]*\('

if [ "$status" -eq 0 ]; then
    echo "lint: passed"
fi

exit "$status"
