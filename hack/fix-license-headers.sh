#!/usr/bin/env bash

# Copyright 2026 The Kubernetes resource-state-metrics Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script fixes or verifies license headers in files.
# Usage: fix-license-headers.sh [--check|--dry-run] <file1> [file2] ...
#
# Modes:
#   --check   : Verify files have license headers (exit 1 if any missing)
#   --dry-run : Show which files would be fixed, but don't modify
#   (default) : Fix missing license headers
#
# Determines the boilerplate to use based on file extension:
#   .go                  -> hack/boilerplate.go.txt
#   .yaml, .yml          -> hack/boilerplate.yaml.txt
#   .jsonnet, .libsonnet -> hack/boilerplate.libsonnet.txt
#
# For YAML files starting with "---", the boilerplate is inserted after "---".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="fix"
if [[ "${1:-}" == "--check" ]]; then
    MODE="check"
    shift
elif [[ "${1:-}" == "--dry-run" ]]; then
    MODE="dry-run"
    shift
fi

if [[ $# -eq 0 ]]; then
    exit 0
fi

get_boilerplate() {
    local ext="$1"
    case "$ext" in
        go)
            echo "${REPO_ROOT}/hack/boilerplate.go.txt"
            ;;
        yaml|yml)
            echo "${REPO_ROOT}/hack/boilerplate.yaml.txt"
            ;;
        jsonnet|libsonnet)
            echo "${REPO_ROOT}/hack/boilerplate.libsonnet.txt"
            ;;
        *)
            echo ""
            ;;
    esac
}

has_license() {
    local file="$1"
    awk 'NR<=5' "$file" | grep -q "Copyright"
}

process_file() {
    local file="$1"
    local ext="${file##*.}"
    local boilerplate
    boilerplate="$(get_boilerplate "$ext")"

    if [[ -z "$boilerplate" ]]; then
        if [[ "$MODE" != "check" ]]; then
            echo "Skipping $file: unknown extension .$ext"
        fi
        return 0
    fi

    if [[ ! -f "$boilerplate" ]]; then
        echo "Error: boilerplate file not found: $boilerplate"
        return 1
    fi

    if has_license "$file"; then
        return 0
    fi

    # File is missing license
    if [[ "$MODE" == "check" ]]; then
        echo "$file"
        return 1
    fi

    echo "Fixing: $file"

    if [[ "$MODE" == "dry-run" ]]; then
        return 0
    fi

    local tmp_file
    tmp_file="$(mktemp)"

    # For YAML files, check if it starts with "---"
    if [[ "$ext" == "yaml" || "$ext" == "yml" ]]; then
        local first_line
        first_line="$(head -1 "$file")"
        if [[ "$first_line" == "---" ]]; then
            # Insert boilerplate after "---"
            echo "---" > "$tmp_file"
            cat "$boilerplate" >> "$tmp_file"
            tail -n +2 "$file" >> "$tmp_file"
        else
            # Prepend boilerplate
            cat "$boilerplate" > "$tmp_file"
            cat "$file" >> "$tmp_file"
        fi
    else
        # For other files, simply prepend
        cat "$boilerplate" > "$tmp_file"
        cat "$file" >> "$tmp_file"
    fi

    mv "$tmp_file" "$file"
}

missing_count=0
for file in "$@"; do
    if [[ -f "$file" ]]; then
        if ! process_file "$file"; then
            ((missing_count++)) || true
        fi
    fi
done

if [[ "$MODE" == "check" ]]; then
    if [[ $missing_count -gt 0 ]]; then
        echo ""
        echo "license header checking failed: $missing_count file(s) missing license"
        exit 1
    fi
elif [[ "$MODE" == "dry-run" && $missing_count -gt 0 ]]; then
    echo "Would fix $missing_count file(s)"
elif [[ $missing_count -gt 0 ]]; then
    echo "Fixed $missing_count file(s)"
fi
