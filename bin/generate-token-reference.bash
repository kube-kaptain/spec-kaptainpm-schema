#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Generates the token pattern definitions in the source schema:
#   $defs.tokenReference - a whole-value token: one pattern per delimiter style
#                          and token name style pair, grouped by delimiter style
#                          with the name styles in the same order in every group
#   $defs.tokenName      - a bare token name: one pattern per token name style
#
# The tables below mirror buildon-github-actions and must be kept in step
# with it:
#   delimiters  - src/scripts/plugins/token-substitution-providers/substitute-<style>-style-token
#   name styles - src/scripts/plugins/token-name-validators/<style>
#
# The block is replaced between the BEGIN/END GENERATED markers in the schema.
#
# Usage:
#   bin/generate-token-reference.bash          Rewrite the block in place
#   bin/generate-token-reference.bash --check  Exit 1 if the block is out of date

set -euo pipefail

SCHEMA="src/schema/spec-kaptainpm-schema.yaml"
BEGIN_MARKER="  # BEGIN GENERATED: token patterns"
END_MARKER="  # END GENERATED: token patterns"

# Delimiter styles: name, display form, regex prefix, regex suffix
DELIM_NAMES=(shell mustache helm erb github-actions blade stringtemplate ognl t4 swift)
DELIM_FORMS=('${Name}' '{{ Name }}' '{{ .Values.Name }}' '<%= Name %>' '${{ Name }}' '{{ $Name }}' '$Name$' '%{Name}' '<#= Name #>' '\(Name)')
DELIM_PREFIXES=('^\$\{' '^\{\{ ' '^\{\{ \.Values\.' '^<%= ' '^\$\{\{ ' '^\{\{ \$' '^\$' '^%\{' '^<#= ' '^\\\(')
DELIM_SUFFIXES=('\}$' ' \}\}$' ' \}\}$' ' %>$' ' \}\}$' ' \}\}$' '\$$' '\}$' ' #>$' '\)$')

# Name styles: name, one path segment as the validator accepts it
NAME_STYLES=(PascalCase camelCase UPPER_SNAKE lower_snake lower-kebab UPPER-KEBAB lower.dot UPPER.DOT)
NAME_SEGMENTS=(
  '[A-Z0-9][a-zA-Z0-9]*'
  '([0-9]|[a-z][a-zA-Z0-9]*|[0-9]+[A-Z][a-zA-Z0-9]*)'
  '[A-Z0-9]([A-Z0-9_]*[A-Z0-9])?'
  '[a-z0-9]([a-z0-9_]*[a-z0-9])?'
  '[a-z0-9]([a-z0-9-]*[a-z0-9])?'
  '[A-Z0-9]([A-Z0-9-]*[A-Z0-9])?'
  '[a-z0-9]([a-z0-9.]*[a-z0-9])?'
  '[A-Z0-9]([A-Z0-9.]*[A-Z0-9])?'
)

generate_block() {
  local d n segment
  echo "${BEGIN_MARKER} - do not edit, run bin/generate-token-reference.bash"
  cat << 'EOF'
  tokenReference:
    type: string
    description: >
      A whole-value token left for later substitution, in any supported
      delimiter style and token name style, e.g. ${ReplicaCount},
      {{ replica-count }} or {{ .Values.REPLICA_COUNT }}. Names follow one
      name style throughout, path segments joined by /. Values the build
      itself reads must be resolved before it does, e.g. by layer token
      substitution.
    # Grouped by delimiter style. Each group lists the name styles in order:
EOF
  echo "    # ${NAME_STYLES[*]}"
  echo "    anyOf:"
  for ((d = 0; d < ${#DELIM_NAMES[@]}; d++)); do
    echo "      # ${DELIM_NAMES[d]}: ${DELIM_FORMS[d]}"
    for ((n = 0; n < ${#NAME_STYLES[@]}; n++)); do
      segment="${NAME_SEGMENTS[n]}"
      echo "      - pattern: '${DELIM_PREFIXES[d]}${segment}(/${segment})*${DELIM_SUFFIXES[d]}'"
    done
  done
  cat << 'EOF'

  tokenName:
    type: string
    description: >
      A token name in any supported token name style, e.g. ReplicaCount,
      replica-count or VENDOR_ENVOY/REPLICAS. Names follow one name style
      throughout, path segments joined by /.
    # One pattern per name style, in order:
EOF
  echo "    # ${NAME_STYLES[*]}"
  echo "    anyOf:"
  for ((n = 0; n < ${#NAME_STYLES[@]}; n++)); do
    segment="${NAME_SEGMENTS[n]}"
    echo "      - pattern: '^${segment}(/${segment})*$'"
  done
  echo "${END_MARKER}"
}

# Print the schema with the generated block swapped in
render_schema() {
  local block_file="${1}"
  awk -v begin="${BEGIN_MARKER}" -v end="${END_MARKER}" -v block="${block_file}" '
    index($0, begin) == 1 { while ((getline line < block) > 0) print line; skipping = 1; found++; next }
    skipping && index($0, end) == 1 { skipping = 0; next }
    !skipping { print }
    END { if (found != 1 || skipping) exit 2 }
  ' "${SCHEMA}"
}

block_file="$(mktemp)"
rendered_file="$(mktemp)"
trap 'rm -f "${block_file}" "${rendered_file}"' EXIT

generate_block > "${block_file}"
if ! render_schema "${block_file}" > "${rendered_file}"; then
  echo "Expected exactly one '${BEGIN_MARKER}' ... '${END_MARKER}' block in ${SCHEMA}" >&2
  exit 1
fi

if [[ "${1:-}" == "--check" ]]; then
  if ! diff -u "${SCHEMA}" "${rendered_file}"; then
    echo "Token patterns in ${SCHEMA} are out of date - run bin/generate-token-reference.bash" >&2
    exit 1
  fi
  echo "Token patterns are up to date"
else
  cp "${rendered_file}" "${SCHEMA}"
  echo "Regenerated token patterns in ${SCHEMA}"
fi
