#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Layer 2: end-to-end fixture tests against the real (substituted) project
# schema. Walks two directories:
#
#   src/test-fixtures/should-pass/*.yaml  - must validate clean
#   src/test-fixtures/should-fail/*.yaml  - must FAIL validation
#
# Accumulates all failures and exits non-zero at the end.
#
# Inputs (provided by build system):
#   OUTPUT_SUB_PATH  - Build output directory
#   VERSION          - Schema version
#   DOCKER_PLATFORM  - Docker platform(s); first is used for multi-platform

set -euo pipefail

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:?OUTPUT_SUB_PATH is required}"
VERSION="${VERSION:?VERSION is required}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

if [[ "${DOCKER_PLATFORM}" == *,* ]]; then
  first_platform="${DOCKER_PLATFORM%%,*}"
  yaml_dir="${OUTPUT_SUB_PATH}/docker-${first_platform//\//-}/substituted/yaml"
else
  yaml_dir="${OUTPUT_SUB_PATH}/docker/substituted/yaml"
fi

SCHEMA="${yaml_dir}/spec-kaptainpm-schema-${VERSION}.yaml"

FAILED=()
ERR_TMP="$(mktemp)"
trap 'rm -f "${ERR_TMP}"' EXIT

PASS_DIR="src/test-fixtures/should-pass"
FAIL_DIR="src/test-fixtures/should-fail"

echo "Validating should-pass fixtures (must validate clean)..."
if [[ -d "${PASS_DIR}" ]]; then
  shopt -s nullglob
  for fixture in "${PASS_DIR}"/*.yaml; do
    name="$(basename "${fixture}")"
    if check-jsonschema --schemafile "${SCHEMA}" "${fixture}" >"${ERR_TMP}" 2>&1; then
      echo "  ${name}: ok"
    else
      echo "  ${name}: FAIL (expected pass, got fail)"
      sed 's/^/      /' "${ERR_TMP}"
      FAILED+=("should-pass/${name}")
    fi
  done
  shopt -u nullglob
else
  echo "  (no should-pass directory)"
fi

echo ""
echo "Validating should-fail fixtures (must FAIL validation)..."
if [[ -d "${FAIL_DIR}" ]]; then
  shopt -s nullglob
  for fixture in "${FAIL_DIR}"/*.yaml; do
    name="$(basename "${fixture}")"
    if check-jsonschema --schemafile "${SCHEMA}" "${fixture}" >"${ERR_TMP}" 2>&1; then
      echo "  ${name}: FAIL (expected fail, got pass)"
      FAILED+=("should-fail/${name}")
    else
      echo "  ${name}: ok (correctly rejected)"
    fi
  done
  shopt -u nullglob
else
  echo "  (no should-fail directory)"
fi

echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "End-to-end fixture tests: ${#FAILED[@]} failure(s)"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi

echo "End-to-end fixture tests: all passed"
