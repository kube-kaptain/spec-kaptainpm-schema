#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Hook: hook-post-versions-and-naming
#
# Generates the six KaptainPM schema files from the single source schema.
# Output files land in ${OUTPUT_SUB_PATH}/specs/yaml/ where spec-package-prepare
# will pick them up and convert to JSON. Version is in the file content via
# ${Version} token substitution (not the filename).
#
# All schemas enforce string types on metadata labels and annotations when present.
# Built artifact schemas (layer, layerset) additionally require those fields.
#
# Source: src/schema/spec-kaptainpm-schema.yaml  (superset of all schemas)
#
# Outputs:
#   spec-kaptainpm-schema.yaml                    Base            - project root KaptainPM.yaml files
#   spec-kaptainpm-schema-final.yaml              Final           - merged final KaptainPM.yaml (kind required)
#   spec-kaptainpm-schema-layer-source.yaml       Layer Source    - source layer before build (no metadata required)
#   spec-kaptainpm-schema-layer.yaml              Layer           - built layer images (metadata required)
#   spec-kaptainpm-schema-layerset-source.yaml    Layerset Source - source layerset before build (ranges allowed)
#   spec-kaptainpm-schema-layerset.yaml           Layerset        - built layerset images (pinned versions, metadata required)
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

# Layer-source schema: pre-build layer with no metadata requirements
# A layer has content; only a layerset composes other layers
# kind is allowed: a layer typically declares the build type
echo "Generating: ${yaml_dir}/spec-kaptainpm-schema-layer-source.yaml"
yq eval '
  del(.properties.spec.properties.layers) |
  ."$id" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layer-source-${Version}.yaml" |
  .release = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layer-source-${Version}.yaml" |
  ."validate-using" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layer-source-${Version}.json"
' "${source_schema}" | strip_source_header "layer-source" > "${yaml_dir}/spec-kaptainpm-schema-layer-source.yaml"

# Layer schema: built/published layer with required metadata for build traceability
# Like layer-source but metadata.labels and metadata.annotations are required
echo "Generating: ${yaml_dir}/spec-kaptainpm-schema-layer.yaml"
yq eval '
  del(.properties.spec.properties.layers) |
  .properties.metadata.description = "Project metadata with required build traceability fields." |
  .properties.metadata.required = ["labels", "annotations"] |
  .properties.metadata.properties.labels.required = ["kaptain.org/version", "kaptain.org/project-name", "kaptain.org/owner"] |
  .properties.metadata.properties.annotations.required = ["kaptain.org/built-by", "kaptain.org/source-repository", "kaptain.org/image-uri"]
' "${source_schema}" | strip_source_header "layer" > "${yaml_dir}/spec-kaptainpm-schema-layer.yaml"

# Layerset schema: like layerset-source but with artifactReferenceFixed (no ranges)
# and required metadata.labels and metadata.annotations for build traceability.
# Used to validate built/published layerset images where all versions are pinned.
echo "Generating: ${yaml_dir}/spec-kaptainpm-schema-layerset.yaml"
yq eval '
  del(.properties["layer-payload"]) |
  del(.properties["user-data"]) |
  .properties.spec.properties = {"layers": .properties.spec.properties.layers} |
  .properties.spec.required = ["layers"] |
  .properties.spec.properties.layers."$ref" = "#/$defs/artifactReferenceFixedList" |
  .properties.metadata.description = "Project metadata with required build traceability fields." |
  .properties.metadata.required = ["labels", "annotations"] |
  .properties.metadata.properties.labels.required = ["kaptain.org/version", "kaptain.org/project-name", "kaptain.org/owner"] |
  .properties.metadata.properties.annotations.required = ["kaptain.org/built-by", "kaptain.org/source-repository", "kaptain.org/image-uri"] |
  ."$id" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-${Version}.yaml" |
  .release = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-${Version}.yaml" |
  ."validate-using" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-${Version}.json"
' "${source_schema}" | strip_source_header "layerset" > "${yaml_dir}/spec-kaptainpm-schema-layerset.yaml"

# Final schema: same as base but kind is required and build traceability
# metadata is disallowed (stripped by kaptain-init, injected later by build steps)
echo "Generating: ${yaml_dir}/spec-kaptainpm-schema-final.yaml"
yq eval '
  del(.properties["layer-payload"]) |
  .required = (.required + ["kind"] | unique) |
  .properties.metadata.properties.labels.properties["kaptain.org/version"] = false |
  .properties.metadata.properties.labels.properties["kaptain.org/project-name"] = false |
  .properties.metadata.properties.labels.properties["kaptain.org/owner"] = false |
  .properties.metadata.properties.annotations.properties["kaptain.org/built-by"] = false |
  .properties.metadata.properties.annotations.properties["kaptain.org/source-repository"] = false |
  .properties.metadata.properties.annotations.properties["kaptain.org/image-uri"] = false |
  .name = "${ProjectName}-final" |
  ."$id" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-final-${Version}.yaml" |
  .release = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-final-${Version}.yaml" |
  ."validate-using" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-final-${Version}.json"
' "${source_schema}" | strip_source_header "final" > "${yaml_dir}/spec-kaptainpm-schema-final.yaml"

# Layerset-source schema: source/pre-build layerset with ranges allowed
# A layerset only composes - no config content, no user-data, no layer-payload
# kind is allowed: a layerset typically declares the build type for its consumers
echo "Generating: ${yaml_dir}/spec-kaptainpm-schema-layerset-source.yaml"
yq eval '
  del(.properties["layer-payload"]) |
  del(.properties["user-data"]) |
  .properties.spec.properties = {"layers": .properties.spec.properties.layers} |
  .properties.spec.required = ["layers"] |
  ."$id" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-source-${Version}.yaml" |
  .release = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-source-${Version}.yaml" |
  ."validate-using" = "https://github.com/kube-kaptain/${ProjectName}/releases/download/${Version}/${ProjectName}-layerset-source-${Version}.json"
' "${source_schema}" | strip_source_header "layerset-source" > "${yaml_dir}/spec-kaptainpm-schema-layerset-source.yaml"

echo "Schema generation complete"
