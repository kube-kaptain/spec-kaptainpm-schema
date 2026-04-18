#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Layer 1: standalone tests for the four numeric oneOf buckets used by the
# KaptainPM schema. Each bucket has an integer branch with minimum/maximum and
# a string branch with a bounded regex. This script proves both branches agree.
#
# Test instances are written as JSON so the integer vs string distinction is
# unambiguous (YAML 1.1 type coercion would muddle bare numerics).
#
# Accumulates all failures and exits non-zero at the end.

set -euo pipefail

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

FAILED=()

write_schema() {
  local name="$1"
  local body="$2"
  cat > "${TMPDIR}/schema-${name}.json" <<EOF
{
  "type": "object",
  "properties": {
    "value": ${body}
  },
  "required": ["value"]
}
EOF
}

# Run one validation. Args: <description> <bucket-name> <expected pass|fail> <json-instance-body>
run_case() {
  local desc="$1"
  local bucket="$2"
  local expected="$3"
  local body="$4"
  printf '%s\n' "${body}" > "${TMPDIR}/instance.json"
  local actual
  if check-jsonschema --schemafile "${TMPDIR}/schema-${bucket}.json" "${TMPDIR}/instance.json" >/dev/null 2>&1; then
    actual=pass
  else
    actual=fail
  fi
  if [[ "${actual}" == "${expected}" ]]; then
    echo "  ok: ${desc}"
  else
    echo "  FAIL: ${desc} (expected ${expected}, got ${actual})"
    FAILED+=("${bucket}: ${desc}")
  fi
}

# Bucket 1: minimum 0, no max. String branch unchanged from the existing schema.
write_schema "b1" '{
  "oneOf": [
    {"type": "integer", "minimum": 0},
    {"type": "string", "pattern": "^[0-9]+$"}
  ]
}'

echo "Bucket 1 (minimum 0, no max):"
run_case "int -1 should fail"               b1 fail '{"value": -1}'
run_case "int 0 should pass"                b1 pass '{"value": 0}'
run_case "int 1000 should pass"             b1 pass '{"value": 1000}'
run_case "int 2147483647 should pass"       b1 pass '{"value": 2147483647}'
run_case "str \"-1\" should fail"           b1 fail '{"value": "-1"}'
run_case "str \"0\" should pass"            b1 pass '{"value": "0"}'
run_case "str \"1000\" should pass"         b1 pass '{"value": "1000"}'
run_case "str \"01\" should pass (leading zero allowed)"  b1 pass '{"value": "01"}'

# Bucket 2: minimum 1, no max. String branch tightened to reject 0 and leading zeros.
write_schema "b2" '{
  "oneOf": [
    {"type": "integer", "minimum": 1},
    {"type": "string", "pattern": "^[1-9][0-9]*$"}
  ]
}'

echo "Bucket 2 (minimum 1, no max):"
run_case "int 0 should fail"                b2 fail '{"value": 0}'
run_case "int 1 should pass"                b2 pass '{"value": 1}'
run_case "int 100 should pass"              b2 pass '{"value": 100}'
run_case "int 2147483647 should pass"       b2 pass '{"value": 2147483647}'
run_case "str \"0\" should fail"            b2 fail '{"value": "0"}'
run_case "str \"1\" should pass"            b2 pass '{"value": "1"}'
run_case "str \"100\" should pass"          b2 pass '{"value": "100"}'
run_case "str \"01\" should fail (leading zero rejected)"  b2 fail '{"value": "01"}'

# Bucket 3: 1-65535 (TCP/UDP port range).
write_schema "b3" '{
  "oneOf": [
    {"type": "integer", "minimum": 1, "maximum": 65535},
    {"type": "string", "pattern": "^([1-9]|[1-9][0-9]|[1-9][0-9]{2}|[1-9][0-9]{3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"}
  ]
}'

echo "Bucket 3 (1-65535):"
run_case "int 0 should fail"                b3 fail '{"value": 0}'
run_case "int 1 should pass"                b3 pass '{"value": 1}'
run_case "int 8080 should pass"             b3 pass '{"value": 8080}'
run_case "int 65535 should pass"            b3 pass '{"value": 65535}'
run_case "int 65536 should fail"            b3 fail '{"value": 65536}'
run_case "str \"0\" should fail"            b3 fail '{"value": "0"}'
run_case "str \"1\" should pass"            b3 pass '{"value": "1"}'
run_case "str \"8080\" should pass"         b3 pass '{"value": "8080"}'
run_case "str \"65535\" should pass"        b3 pass '{"value": "65535"}'
run_case "str \"65536\" should fail"        b3 fail '{"value": "65536"}'

# Bucket 4: 30000-32767 (k8s nodePort range).
write_schema "b4" '{
  "oneOf": [
    {"type": "integer", "minimum": 30000, "maximum": 32767},
    {"type": "string", "pattern": "^(30[0-9]{3}|31[0-9]{3}|32[0-6][0-9]{2}|327[0-5][0-9]|3276[0-7])$"}
  ]
}'

echo "Bucket 4 (30000-32767):"
run_case "int 29999 should fail"            b4 fail '{"value": 29999}'
run_case "int 30000 should pass"            b4 pass '{"value": 30000}'
run_case "int 31000 should pass"            b4 pass '{"value": 31000}'
run_case "int 32767 should pass"            b4 pass '{"value": 32767}'
run_case "int 32768 should fail"            b4 fail '{"value": 32768}'
run_case "str \"29999\" should fail"        b4 fail '{"value": "29999"}'
run_case "str \"30000\" should pass"        b4 pass '{"value": "30000"}'
run_case "str \"31000\" should pass"        b4 pass '{"value": "31000"}'
run_case "str \"32767\" should pass"        b4 pass '{"value": "32767"}'
run_case "str \"32768\" should fail"        b4 fail '{"value": "32768"}'

echo ""
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Numeric bucket regex tests: ${#FAILED[@]} failure(s)"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi

echo "Numeric bucket regex tests: all passed"
