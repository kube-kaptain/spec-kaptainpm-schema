#!/usr/bin/env bash
# SPDX-License-Identifier: CC0-1.0
# This file is released to the public domain. Use freely without attribution.
#
# Hook: hook-post-docker-tests
#
# Validates the example KaptainPM.yaml files against the generated schemas.
# Runs after token substitution so ${Version} and ${ProjectName} are resolved.
#
# Inputs (provided by build system):
#   OUTPUT_SUB_PATH  - Build output directory

set -euo pipefail

OUTPUT_SUB_PATH="${OUTPUT_SUB_PATH:?OUTPUT_SUB_PATH is required}"

yaml_dir="${OUTPUT_SUB_PATH}/specs/yaml"

echo "Validating examples against generated schemas..."
echo ""

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema.yaml" src/examples/project-full.yaml
echo "  project-full.yaml: ok"

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layer.yaml" src/examples/layer-full.yaml
echo "  layer-full.yaml: ok"

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layerset.yaml" src/examples/layerset-full.yaml
echo "  layerset-full.yaml: ok"

echo ""
echo "Example validation complete"
