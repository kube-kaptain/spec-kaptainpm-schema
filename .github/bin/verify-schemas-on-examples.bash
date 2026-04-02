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
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

# Use substituted schemas (tokens resolved) from the docker build context.
# Multi-platform builds have per-platform dirs; content is identical so use the first.
if [[ "${DOCKER_PLATFORM}" == *,* ]]; then
  first_platform="${DOCKER_PLATFORM%%,*}"
  yaml_dir="${OUTPUT_SUB_PATH}/docker-${first_platform//\//-}/substituted/yaml"
else
  yaml_dir="${OUTPUT_SUB_PATH}/docker/substituted/yaml"
fi

echo "Validating examples against generated schemas..."
echo ""

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema.yaml" src/examples/project-full.yaml
echo "  project-full.yaml: ok"
check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema.yaml" src/examples/project-min.yaml
echo "  project-min.yaml: ok"

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-final.yaml" src/examples/final-full.yaml
echo "  final-full.yaml: ok"
check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-final.yaml" src/examples/final-min.yaml
echo "  final-min.yaml: ok"

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layer-source.yaml" src/examples/layer-source-full.yaml
echo "  layer-source-full.yaml: ok"
check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layer-source.yaml" src/examples/layer-source-min.yaml
echo "  layer-source-min.yaml: ok"

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layer.yaml" src/examples/layer-full.yaml
echo "  layer-full.yaml: ok"
check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layer.yaml" src/examples/layer-min.yaml
echo "  layer-min.yaml: ok"

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layerset.yaml" src/examples/layerset-full.yaml
echo "  layerset-full.yaml: ok"
check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layerset.yaml" src/examples/layerset-min.yaml
echo "  layerset-min.yaml: ok"

check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layerset-source.yaml" src/examples/layerset-source-full.yaml
echo "  layerset-source-full.yaml: ok"
check-jsonschema --schemafile "${yaml_dir}/spec-kaptainpm-schema-layerset-source.yaml" src/examples/layerset-source-min.yaml
echo "  layerset-source-min.yaml: ok"

echo ""
echo "Example validation complete"
