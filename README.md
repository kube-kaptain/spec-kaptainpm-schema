# Spec KaptainPM Schema

JSON Schema for three variants of `KaptainPM.yaml` - the project manifest that drives all Kaptain build processes.


## Project, Layer, and Layerset

A single source schema at `src/schema/spec-kaptainpm-schema.yaml` generates three output schemas at build time:

| Schema                                | Used for                                                           | Differs from source by                                                        |
|---------------------------------------|--------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `spec-kaptainpm-schema.yaml`          | Project root `KaptainPM.yaml` and `kaptainpm/final/KaptainPM.yaml` | `layer-payload` removed                                                       |
| `spec-kaptainpm-schema-layer.yaml`    | Configuration and tooling reusable layer `KaptainPM.yaml` files    | `spec.layers` removed — config layers cannot reference other layers           |
| `spec-kaptainpm-schema-layerset.yaml` | Composite layers i.e. reusable layerset `KaptainPM.yaml` files     | `layer-payload` and `user-data` removed; `spec` reduced to `spec.layers` only |

A **config layer** carries configuration values. A **layerset** carries only an ordered list of other layers to expand in-place during resolution — no configuration of its own.

## Build

The hook `.github/bin/generate-kind-schemas.bash` runs after the `versions-and-naming` part
of the build process and writes all three output schemas to `${OUTPUT_SUB_PATH}/specs/yaml/`.
The gh actions workflow (`spec-check-filter-release`) converts them to JSON and publishes
them as a versioned OCI image as well as individually to the gh release for the project.
