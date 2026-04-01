# Spec KaptainPM Schema for Agents

JSON Schema for KaptainPM project manifest files (`KaptainPM.yaml`).

## Purpose

Defines and validates the structure of `KaptainPM.yaml` — the project manifest
used by all Kaptain built projects. Published as a versioned OCI image as well
as 4 json and 4 yaml versioned files on the gh release for every release build.

## Project Structure

```
src/
  schema/
    spec-kaptainpm-schema.yaml          # Single source schema (superset of all four)
  examples/
    project-full.yaml                   # All fields populated - validates against project variant
    layer-full.yaml                     # All fields populated - validates against layer variant
    layerset-full.yaml                  # All fields populated - validates against layerset variant (built, pinned)
    layerset-source-full.yaml           # All fields populated - validates against layerset-source variant (ranges)
.github/
  bin/
    generate-kind-schemas.bash          # Hook: generates four schemas from the source
    verify-schemas-on-examples.bash     # Hook: validates examples against generated schemas
  workflows/
    build.yaml                          # Calls spec-check-filter-release with the hook wired in
README.md                               # For humans to understand the project
AGENTS.md                               # These instructions
CLAUDE.md                               # Redirect to AGENTS.md
```

## Four Schemas

The source schema is the superset. The hook generates four schemas from it:

| Output file                                      | Variant          | Used for                                                           |
|--------------------------------------------------|------------------|--------------------------------------------------------------------|
| `spec-kaptainpm-schema.yaml`                     | Project          | Project root `KaptainPM.yaml` and `kaptainpm/final/KaptainPM.yaml` |
| `spec-kaptainpm-schema-layer.yaml`               | Layer            | Config layer image `KaptainPM.yaml` files                          |
| `spec-kaptainpm-schema-layerset.yaml`            | Layerset         | Built/published layerset images (pinned versions, metadata required)|
| `spec-kaptainpm-schema-layerset-source.yaml`     | Layerset Source  | Source layerset before build (ranges allowed, metadata optional)    |

Differences from source:
- **Project**: `layer-payload` removed
- **Layer**: `layer-payload` removed; `spec.layers` removed (config layers cannot reference other layers)
- **Layerset**: like Layerset Source but `spec.layers` uses `artifactReferenceFixed` (no ranges); `metadata.labels` required (`kaptain.org/version`, `kaptain.org/project-name`, `kaptain.org/owner`); `metadata.annotations` required (`kaptain.org/built-by`, `kaptain.org/source-repository`, `kaptain.org/image-uri`)
- **Layerset Source**: `layer-payload` removed; `user-data` removed; all `spec.*` except `spec.layers` removed; `kind` kept (layersets typically declare the build type for their consumers)

### Artifact References

Two reference types are defined in the schema:
- **`artifactReference`** — accepts exact versions (`1.2.3`, `1.0-PRERELEASE`) AND Maven-style range syntax (`[1.0,2.0)`, `(1.0,)`, etc). Used by default in all schemas.
- **`artifactReferenceFixed`** — exact versions only, no ranges. Used only in the layerset schema (built artifacts).

These are generic artifact references, not OCI-specific — the artifact system has pluggable providers.

A **layerset** is a pure composition unit — an ordered list of layers (and/or
other layersets) that expands in-place during layer resolution. It has no config
content of its own. Presence of `spec.layers` in an OCI image's `KaptainPM.yaml`
is what the resolver uses to identify a layerset and trigger in-place expansion
rather than merging.

## Schema Build

The source schema is NOT in `src/specs/` (spec-package-prepare would pick it up directly).
It lives in `src/schema/` and the hook writes output to `${OUTPUT_SUB_PATH}/specs/yaml/`
during `hook-post-versions-and-naming`. spec-package-prepare picks those up and packages them.

## Versioning

Automatic 2-part versions (`major.minor`) by the release build on merge. The
schema version increments on any change to the allowed structure. Consumers
pin to a specific version.

## Rules

- Source schema lives in `src/schema/spec-kaptainpm-schema.yaml`
- All text files must have a trailing newline
