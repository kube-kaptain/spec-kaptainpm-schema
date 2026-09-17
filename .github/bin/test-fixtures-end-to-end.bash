#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Layer 2: end-to-end fixture tests against the real (substituted) schemas.
# Walks two expectation directories:
#
#   src/test-fixtures/should-pass/  - must validate clean
#   src/test-fixtures/should-fail/  - must FAIL validation
#
# Fixtures sitting directly in an expectation directory are validated against
# the project schema. Fixtures in a subdirectory are validated against the
# schema variant the subdirectory is named after, so the subdirectory name is
# the variant infix in the generated filename:
#
#   should-pass/foo.yaml            -> spec-kaptainpm-schema-${VERSION}.yaml
#   should-pass/layerset/foo.yaml   -> spec-kaptainpm-schema-layerset-${VERSION}.yaml
#   should-fail/layer-source/x.yaml -> spec-kaptainpm-schema-layer-source-${VERSION}.yaml
#
# Variants that only exist in a non-project schema (artifactReferenceFixed is
# the motivating case - it is used by the layerset schema and nowhere else)
# have no coverage at all without this routing.
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

FAILED=()
ERR_TMP="$(mktemp)"
trap 'rm -f "${ERR_TMP}"' EXIT

FIXTURES_ROOT="src/test-fixtures"

# Generated schema file for a variant. Empty variant means the project schema,
# which carries no infix.
schema_for_variant() {
  local variant="$1"
  if [[ -z "${variant}" ]]; then
    echo "${yaml_dir}/spec-kaptainpm-schema-${VERSION}.yaml"
  else
    echo "${yaml_dir}/spec-kaptainpm-schema-${variant}-${VERSION}.yaml"
  fi
}

# Validate every *.yaml directly inside <dir> against <schema>, asserting the
# outcome named by <expectation>. Nested directories are handled by the caller,
# not recursed into here.
#
# Usage: validate_dir <dir> <schema> <should-pass|should-fail> <label>
validate_dir() {
  local dir="$1"
  local schema="$2"
  local expectation="$3"
  local label="$4"

  if [[ ! -f "${schema}" ]]; then
    echo "  ${label}: FAIL (schema not found: ${schema})"
    FAILED+=("${label} (missing schema $(basename "${schema}"))")
    return 0
  fi

  local found=0
  local fixture name
  shopt -s nullglob
  for fixture in "${dir}"/*.yaml; do
    found=1
    name="$(basename "${fixture}")"
    if check-jsonschema --schemafile "${schema}" "${fixture}" >"${ERR_TMP}" 2>&1; then
      if [[ "${expectation}" == "should-pass" ]]; then
        echo "  ${label}/${name}: ok"
      else
        echo "  ${label}/${name}: FAIL (expected fail, got pass)"
        FAILED+=("${label}/${name}")
      fi
    else
      if [[ "${expectation}" == "should-fail" ]]; then
        echo "  ${label}/${name}: ok (correctly rejected)"
      else
        echo "  ${label}/${name}: FAIL (expected pass, got fail)"
        sed 's/^/      /' "${ERR_TMP}"
        FAILED+=("${label}/${name}")
      fi
    fi
  done
  shopt -u nullglob

  if [[ ${found} -eq 0 ]]; then
    echo "  ${label}: (no fixtures)"
  fi
}

for expectation in should-pass should-fail; do
  base="${FIXTURES_ROOT}/${expectation}"
  echo ""
  if [[ "${expectation}" == "should-pass" ]]; then
    echo "Validating should-pass fixtures (must validate clean)..."
  else
    echo "Validating should-fail fixtures (must FAIL validation)..."
  fi

  if [[ ! -d "${base}" ]]; then
    echo "  (no ${expectation} directory)"
    continue
  fi

  validate_dir "${base}" "$(schema_for_variant "")" "${expectation}" "${expectation}"

  shopt -s nullglob
  for variant_dir in "${base}"/*/; do
    variant="$(basename "${variant_dir}")"
    validate_dir "${variant_dir%/}" "$(schema_for_variant "${variant}")" \
      "${expectation}" "${expectation}/${variant}"
  done
  shopt -u nullglob
done

echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "End-to-end fixture tests: ${#FAILED[@]} failure(s)"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi

echo "End-to-end fixture tests: all passed"
