#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Hook: hook-post-versions-and-naming
#
# Generates the three KaptainPM schema files from the single source schema.
# Output files land in ${OUTPUT_SUB_PATH}/specs/yaml/ where spec-package-prepare
# will pick them up and convert to JSON. Version is in the file content via
# ${Version} token substitution (not the filename).
#
# Source: src/schema/spec-kaptainpm-schema.yaml  (superset of all three schemas)
#
# Outputs:
#   spec-kaptainpm-schema.yaml          Base     - project root and final merged files
#   spec-kaptainpm-schema-layer.yaml    Layer    - layer image KaptainPM.yaml files
#   spec-kaptainpm-schema-layerset.yaml Layerset - composite layer image KaptainPM.yaml files
#
# Inputs (provided by build system):
#   OUTPUT_SUB_PATH  - Build output directory

set -euo pipefail

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:?OUTPUT_SUB_PATH is required}"

source_schema="src/schema/spec-kaptainpm-schema.yaml"
yaml_dir="${OUTPUT_SUB_PATH}/specs/yaml"
mkdir -p "${yaml_dir}"

# Strip the source file header comment block (lines up to and including the blank line
# before $schema:) and prepend a generated-file comment instead.
# The source comment describes the source file; generated files need their own header.
strip_source_header() {
  local variant="${1}"
  # Drop the source file header comment block; prepend generated-file header.
  # sed: print from the first '$schema:' line to end of file.
  {
    printf '# SPDX-License-Identifier: CC-BY-SA-4.0\n'
    printf '# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)\n'
    printf '#\n'
    printf '# KaptainPM %s schema (generated - do not edit directly).\n' "${variant}"
    printf '# Source: spec-kaptainpm-schema / src/schema/spec-kaptainpm-schema.yaml\n'
    printf '#\n'
    printf '# Token substitution: ${Version} is replaced at build time.\n'
    printf '\n'
    sed -n '/^\$schema:/,$p'
  }
}

# Base schema: everything in source minus layer-payload
# Used for project root KaptainPM.yaml and kaptainpm/final/KaptainPM.yaml
echo "Generating: ${yaml_dir}/spec-kaptainpm-schema.yaml"
yq eval '
  del(.properties["layer-payload"]) |
  ."$id" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-${Version}.yaml" |
  .release = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-${Version}.yaml" |
  ."validate-using" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-${Version}.json"
' "${source_schema}" | strip_source_header "base" > "${yaml_dir}/spec-kaptainpm-schema.yaml"

# Layer schema: source minus spec.layers (config layers cannot reference other layers)
# A layer has content; only a layerset composes other layers
# $id and release already correct in source (point to the layer schema)
echo "Generating: ${yaml_dir}/spec-kaptainpm-schema-layer.yaml"
yq eval '
  del(.properties.spec.properties.layers)
' "${source_schema}" | strip_source_header "layer" > "${yaml_dir}/spec-kaptainpm-schema-layer.yaml"

# Layerset schema: base minus user-data, with spec reduced to layers only
# A layerset only composes - no config content, no user-data, no layer-payload
# kind is allowed: a layerset typically declares the build type for its consumers
echo "Generating: ${yaml_dir}/spec-kaptainpm-schema-layerset.yaml"
yq eval '
  del(.properties["layer-payload"]) |
  del(.properties["user-data"]) |
  .properties.spec.properties = {"layers": .properties.spec.properties.layers} |
  ."$id" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-${Version}.yaml" |
  .release = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-${Version}.yaml" |
  ."validate-using" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-${Version}.json"
' "${source_schema}" | strip_source_header "layerset" > "${yaml_dir}/spec-kaptainpm-schema-layerset.yaml"

echo "Schema generation complete"
