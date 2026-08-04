#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Validates the example KaptainPM.yaml files against the generated schemas.
# Runs after token substitution so ${Version} and ${ProjectName} are resolved.
#
# Accumulates all failures across all examples then exits non-zero at the end.
#
# Inputs (provided by build system):
#   OUTPUT_SUB_PATH  - Build output directory
#   VERSION          - Schema version
#   DOCKER_PLATFORM  - Docker platform(s); first is used for multi-platform

set -euo pipefail

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:?OUTPUT_SUB_PATH is required}"
VERSION="${VERSION:?VERSION is required}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

# Use substituted schemas (tokens resolved) from the docker build context.
# Multi-platform builds have per-platform dirs; content is identical so use the first.
if [[ "${DOCKER_PLATFORM}" == *,* ]]; then
  first_platform="${DOCKER_PLATFORM%%,*}"
  yaml_dir="${OUTPUT_SUB_PATH}/docker-${first_platform//\//-}/substituted/yaml"
else
  yaml_dir="${OUTPUT_SUB_PATH}/docker/substituted/yaml"
fi

FAILED=()
ERR_TMP="$(mktemp)"
trap 'rm -f "${ERR_TMP}"' EXIT

check_example() {
  local schema="$1"
  local example="$2"
  if check-jsonschema --schemafile "${yaml_dir}/${schema}" "src/examples/${example}" >"${ERR_TMP}" 2>&1; then
    echo "  ${example}: ok"
  else
    echo "  ${example}: FAIL (schema=${schema})"
    sed 's/^/      /' "${ERR_TMP}"
    FAILED+=("${example} vs ${schema}")
  fi
}

echo "Validating examples against generated schemas..."
echo ""

check_example "spec-kaptainpm-schema-${VERSION}.yaml"                  "project-full.yaml"
check_example "spec-kaptainpm-schema-${VERSION}.yaml"                  "project-min.yaml"
check_example "spec-kaptainpm-schema-${VERSION}.yaml"                  "env-full.yaml"
check_example "spec-kaptainpm-schema-${VERSION}.yaml"                  "env-min.yaml"
check_example "spec-kaptainpm-schema-${VERSION}.yaml"                  "runplatform-full.yaml"
check_example "spec-kaptainpm-schema-${VERSION}.yaml"                  "runplatform-min.yaml"
check_example "spec-kaptainpm-schema-final-${VERSION}.yaml"            "final-full.yaml"
check_example "spec-kaptainpm-schema-final-${VERSION}.yaml"            "final-min.yaml"
check_example "spec-kaptainpm-schema-layer-source-${VERSION}.yaml"     "layer-source-full.yaml"
check_example "spec-kaptainpm-schema-layer-source-${VERSION}.yaml"     "layer-source-min.yaml"
check_example "spec-kaptainpm-schema-layer-${VERSION}.yaml"            "layer-full.yaml"
check_example "spec-kaptainpm-schema-layer-${VERSION}.yaml"            "layer-min.yaml"
check_example "spec-kaptainpm-schema-layerset-${VERSION}.yaml"         "layerset-full.yaml"
check_example "spec-kaptainpm-schema-layerset-${VERSION}.yaml"         "layerset-min.yaml"
check_example "spec-kaptainpm-schema-layerset-source-${VERSION}.yaml"  "layerset-source-full.yaml"
check_example "spec-kaptainpm-schema-layerset-source-${VERSION}.yaml"  "layerset-source-min.yaml"

echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Example validation: ${#FAILED[@]} failure(s)"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi

echo "Example validation: all passed"
