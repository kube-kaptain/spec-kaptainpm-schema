#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Hook: hook-post-docker-tests
#
# Wraps three rounds of schema verification, fail-fast between rounds:
#   1. Examples (lightest):     verify-schemas-on-examples.bash
#   2. Numeric regex buckets:   test-numeric-bucket-regexes.bash
#   3. End-to-end fixtures:     test-fixtures-end-to-end.bash
#
# Each round accumulates its own failures and exits non-zero if any failed.
# This wrapper stops at the first round that fails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Round 1: example KaptainPM files vs generated schemas ==="
"${SCRIPT_DIR}/verify-schemas-on-examples.bash"
echo ""

echo "=== Round 2: numeric oneOf bucket regex/range checks ==="
"${SCRIPT_DIR}/test-numeric-bucket-regexes.bash"
echo ""

echo "=== Round 3: end-to-end fixture checks ==="
"${SCRIPT_DIR}/test-fixtures-end-to-end.bash"
echo ""

echo "All schema verification rounds passed."
