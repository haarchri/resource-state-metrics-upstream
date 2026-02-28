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

# This script verifies that files have license headers.
# Usage: verify-license-headers.sh [--allow-generated] <file1> [file2] ...
#
# By default, checks for "Copyright" in the first 5 lines.
# With --allow-generated, also allows "generated" or "GENERATED".

set -euo pipefail

pattern="Copyright"

if [[ "${1:-}" == "--allow-generated" ]]; then
    pattern="(Copyright|generated|GENERATED)"
    shift
fi

if [[ $# -eq 0 ]]; then
    exit 0
fi

bad_files=()
for file in "$@"; do
    if [[ -f "$file" ]] && ! awk 'NR<=5' "$file" | grep -Eq "$pattern"; then
        bad_files+=("$file")
    fi
done

if [[ ${#bad_files[@]} -gt 0 ]]; then
    echo "license header checking failed:"
    printf '%s\n' "${bad_files[@]}"
    exit 1
fi
