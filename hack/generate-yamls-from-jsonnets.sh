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

set -euo pipefail

BOILERPLATE="hack/boilerplate.yaml.txt"
CONTROLLER_GEN_VERSION="${CONTROLLER_GEN_VERSION:-v0.16.5}"
GOJSONTOYAML="${GOJSONTOYAML:-gojsontoyaml}"
JSONNET="${JSONNET:-jsonnet}"
NAMESPACE="${NAMESPACE:-default}"
OUTPUT_DIR="jsonnet/manifests"
PROJECT_NAME="${PROJECT_NAME:-resource-state-metrics}"
VERSION="${VERSION:-0.0.1}"
YQ="${YQ:-yq}"

mkdir -p "$OUTPUT_DIR"

add_boilerplate() {
    local file="$1"
    local tmp
    tmp=$(mktemp)
    cat "$BOILERPLATE" > "$tmp"
    echo "---" >> "$tmp"
    cat "$file" >> "$tmp"
    mv "$tmp" "$file"
}

GENERATOR_JSONNET="
local rsm = (import \"jsonnet/resource-state-metrics/resource-state-metrics.libsonnet\") + {
  name:: \"${PROJECT_NAME}\",
  namespace:: \"${NAMESPACE}\",
  version:: \"${VERSION}\",
  image:: \"registry.k8s.io/${PROJECT_NAME}/${PROJECT_NAME}:v${VERSION}\",
};
{
  \"cluster-role\": rsm.clusterRole,
  \"cluster-role-binding\": rsm.clusterRoleBinding,
  \"custom-resource-definition\": rsm.customResourceDefinition,
  \"deployment\": rsm.deployment,
  \"service\": rsm.service,
  \"service-account\": rsm.serviceAccount,
}
"

# Convert to and from base64 to handle keys with special characters
echo "Generating YAML manifests from jsonnet/"
$JSONNET -e "$GENERATOR_JSONNET" | \
    jq -r 'to_entries[] | @base64' | \
    while read -r entry; do
        key=$(echo "$entry" | base64 -d | jq -r '.key')
        value=$(echo "$entry" | base64 -d | jq -c '.value')
        echo "$value" | $GOJSONTOYAML > "${OUTPUT_DIR}/${key}.yaml"
        add_boilerplate "${OUTPUT_DIR}/${key}.yaml"
        echo "  ${key}.yaml"
    done

# Post-process manifests to ensure controller-gen and jsonnet outputs match.
# Add labels to controller-gen cluster-role.yaml (jsonnet output has them).
$YQ -i ".metadata.labels = {
  \"app.kubernetes.io/component\": \"exporter\",
  \"app.kubernetes.io/name\": \"${PROJECT_NAME}\",
  \"app.kubernetes.io/version\": \"${VERSION}\"
}" "manifests/cluster-role.yaml"
# Add controller-gen version annotation to jsonnet CRD (controller-gen output has it).
$YQ -i ".metadata.annotations.\"controller-gen.kubebuilder.io/version\" = \"${CONTROLLER_GEN_VERSION}\"" \
    "${OUTPUT_DIR}/custom-resource-definition.yaml"

# Generate alerts
echo "  alerts.yaml"
$JSONNET -e "(import 'jsonnet/resource-state-metrics-mixin/mixin.libsonnet').prometheusAlerts" | \
    $GOJSONTOYAML > "${OUTPUT_DIR}/alerts.yaml"
add_boilerplate "${OUTPUT_DIR}/alerts.yaml"
