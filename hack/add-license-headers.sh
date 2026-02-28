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

# This script adds license headers to files that are missing them.

set -euo pipefail

BOILERPLATE_GO="hack/boilerplate.go.txt"
BOILERPLATE_LIBSONNET="hack/boilerplate.libsonnet.txt"
BOILERPLATE_YAML="hack/boilerplate.yaml.txt"

# add_header_if_missing adds a license header to a file if it doesn't have one.
# Args: $1 = file path, $2 = boilerplate file path
add_header_if_missing() {
    local file="$1"
    local boilerplate="$2"

    # Check if file already has Copyright in first 5 lines
    if head -5 "$file" | grep -qE "Copyright"; then
        return 0
    fi

    echo "Adding license header to: $file"
    local tmp
    tmp=$(mktemp)
    cat "$boilerplate" > "$tmp"
    echo "" >> "$tmp"  # Add blank line after header
    cat "$file" >> "$tmp"
    mv "$tmp" "$file"
}

# Process files based on type
process_files() {
    local file_type="$1"
    shift
    local files=("$@")

    local boilerplate
    case "$file_type" in
        go)
            boilerplate="$BOILERPLATE_GO"
            ;;
        jsonnet|libsonnet)
            boilerplate="$BOILERPLATE_LIBSONNET"
            ;;
        yaml|yml)
            boilerplate="$BOILERPLATE_YAML"
            ;;
        *)
            echo "Unknown file type: $file_type"
            return 1
            ;;
    esac

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            add_header_if_missing "$file" "$boilerplate"
        fi
    done
}

# Main
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file-type> <file1> [file2] ..."
    echo "  file-type: go, jsonnet, libsonnet, yaml, yml"
    exit 1
fi

file_type="$1"
shift
process_files "$file_type" "$@"
