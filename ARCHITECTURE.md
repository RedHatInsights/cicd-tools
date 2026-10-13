# Architecture

cicd-tools has two distinct distribution mechanisms — a **Bash script library** (sourced by caller
scripts at runtime) and a **container image** (consumed by Tekton tasks). Both share the same
underlying scripts; the image simply pre-packages them alongside all runtime dependencies.

## Repository Layout

```
src/                    # Public Bash script library (the primary deliverable)
  bootstrap.sh          # External entrypoint: clones the repo and invokes load_module.sh
  load_module.sh        # Internal entrypoint: sets CICD_LOADER_SCRIPTS_DIR, sources loader.sh
  shared/
    log.sh              # Logging module (foundation; no dependencies)
    loader.sh           # Module registry and on-demand loader
    common.sh           # Cross-cutting utilities (command presence, git hash, CI detection)
    container.sh        # Container engine abstraction (podman/docker auto-detection)
    image_builder.sh    # Container image build and push (depends on common + container)

konflux_scripts/        # Tekton/Konflux integration layer (copied into the container image)
  login.sh              # OpenShift cluster login
  reserve-ns.sh         # Ephemeral namespace reservation via bonfire
  release-ns.sh         # Namespace release
  deploy.sh             # Application deployment via bonfire
  deploy-iqe-cji.sh     # IQE ClusterJobInvocation deployment
  collect-logs.sh       # Log collection from ephemeral namespace
  upload-to-s3.sh       # Artifact upload to S3/MinIO
  minio-collect.sh      # Artifact fetch from MinIO
  parse-snapshot.py     # Konflux Snapshot → Bonfire CLI arguments (Pydantic-validated)
  check_cji_jobs.py     # CJI job status checker (reads JSON from stdin, exits 1 on failure)

image_build_scripts/    # Dockerfile setup scripts (run only at image build time)
  install_system_dependencies.sh   # microdnf: python3.12, tar, gzip, jq
  install_python_dependencies.sh   # pip: awscli, crc-bonfire[cli], pydantic (into venv)
  install_third_party_tools.sh     # oc (OpenShift CLI 4.14), mc (MinIO client)

bin/
  oc_wrapper              # Thin wrapper around oc (copied into image PATH)

test/                   # BATS unit tests + E2E tests
  bats/                 # bats-core (git submodule)
  test_helper/          # bats-support, bats-assert (git submodules)
  *.bats                # Unit tests per module (shared_common, shared_container, etc.)
  e2e/                  # End-to-end library loading tests
  generate_coverage.sh  # kcov-based coverage runner (90.01% minimum enforced)

docs/cicd_tools/        # API reference documentation per module
  container.md, image_builder.md, common.md, loader.md, log.md

examples/               # Template Jenkinsfiles and pr_check scripts for consuming projects
backends/, frontends/   # Template Jenkinsfiles (legacy Jenkins consumers)
```

## Bash Script Library: Module System

### Loading Sequence

External callers source the library through one of two paths:

```
# Path A — external project (production use)
source <(curl -sSL https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh) container
  └── bootstrap.sh
        ├── git clone → .cicd_tools/
        ├── source .cicd_tools/src/load_module.sh <module_id>
        │     ├── sets CICD_LOADER_SCRIPTS_DIR=.cicd_tools/src
        │     └── source shared/loader.sh
        │           ├── source shared/log.sh        (always first)
        │           └── cicd::loader::load_module <module_id>
        └── cleanup: rm -rf .cicd_tools/

# Path B — local development / contributor
source src/load_module.sh container
  └── sets CICD_LOADER_SCRIPTS_DIR=src
      source shared/loader.sh → cicd::loader::load_module container
```

### Module Dependency Graph

```
log.sh          ← no dependencies; loaded first by everything
loader.sh       ← depends on log.sh
common.sh       ← depends on loader.sh (guards via CICD_LOADER_MODULE_LOADED)
container.sh    ← depends on common.sh + loader.sh
image_builder.sh← depends on common.sh + container.sh
```

Each module guards against double-sourcing via a `CICD_*_MODULE_LOADED` variable checked at the
top of the file. The loader calls `source` for each module on every `load_module` invocation, but
the guard returns early if already loaded.

### Naming Convention

All public functions follow the pattern `cicd::<module>::<function>`. Private (internal) functions
use `cicd::<module>::_<function>`. This convention is enforced across all modules in `src/shared/`.

### Container Engine Abstraction (`container.sh`)

`cicd::container::cmd` is the single dispatch point for all container operations. Engine selection
happens once on first use:

1. If `CICD_CONTAINER_PREFER_ENGINE` is set and available → use it.
2. Else if `podman` is present and not emulated → use podman.
3. Else if `docker` is present and not emulated → use docker.
4. Else → error.

"Emulation" is detected by checking whether `docker --version` reports a podman version string.
Once selected, `CICD_CONTAINER_ENGINE` is set `readonly`.

### Image Builder (`image_builder.sh`)

`cicd::image_builder::build_and_push` is the top-level function for CI image builds:

1. Resolves the Containerfile path and build context.
2. Assembles `build_params`: tags, labels, build args.
3. Calls `cicd::container::cmd build`.
4. If not a local build (`CICD_IMAGE_BUILDER_LOCAL_BUILD` unset and `CI=true`) → pushes to registry.

Registry login (Quay, Red Hat registry) is handled by separate `login_*` functions that read
credentials from `CICD_IMAGE_BUILDER_QUAY_USER` / `CICD_IMAGE_BUILDER_QUAY_PASSWORD` etc.
(with backward-compatible fallbacks to `QUAY_USER`, `QUAY_TOKEN`).

PR-tagged images get a `quay.expires-after` label set by `CICD_IMAGE_BUILDER_QUAY_EXPIRE_TIME`
(default: `3d`).

## Container Image

The image is built on `registry.access.redhat.com/ubi9-minimal` and runs as a non-root user
(`tools`, UID allocated at build time) with group-writable permissions on `$HOME=/tools` for
OpenShift arbitrary-UID compatibility.

**Layer order in the Dockerfile:**

```
1. FROM ubi9-minimal
2. COPY image_build_scripts/ → /setup/
3. ENV: HOME, TOOLS_DEP_LOCATION, KONFLUX_SCRIPTS_LOCATION, PYTHON_VENV, PATH
4. RUN install_system_dependencies.sh + useradd tools
5. USER tools
6. RUN install_python_dependencies.sh  (pip into $HOME/.venv)
7. RUN install_third_party_tools.sh    (oc, mc → $HOME/bin)
8. COPY konflux_scripts/ → $HOME/konflux/
9. COPY bin/oc_wrapper → $HOME/bin/
10. USER 0 → chown/chmod → USER tools
```

The `$PATH` inside the image is: `$HOME/.venv/bin : $HOME/bin : $HOME/konflux : <system PATH>`.

## Konflux Integration Layer

The `konflux_scripts/` directory provides the full ephemeral-environment lifecycle used by the
[bonfire-tekton](https://github.com/RedHatInsights/bonfire-tekton) pipeline tasks:

| Script | Purpose |
|---|---|
| `login.sh` | Logs into OpenShift using a service account token |
| `reserve-ns.sh` | Reserves an ephemeral namespace via bonfire |
| `release-ns.sh` | Releases the reservation |
| `deploy.sh` | Deploys the application snapshot via bonfire (invokes `parse-snapshot.py`) |
| `deploy-iqe-cji.sh` | Creates and waits on an IQE ClusterJobInvocation |
| `collect-logs.sh` | Collects pod logs from the ephemeral namespace |
| `upload-to-s3.sh` | Uploads collected artifacts to S3/MinIO |
| `minio-collect.sh` | Fetches artifacts from MinIO after test completion |

### `parse-snapshot.py` — Snapshot Bridge

Reads the `SNAPSHOT` environment variable (Konflux JSON format), validates it with Pydantic models
(`Snapshot → Component → ContainerImage + Source`), and emits Bonfire CLI arguments:

```
--set-template-ref <component>=<git-revision>
--set-parameter <component>/IMAGE=<image>@sha256
--set-image-tag <image>@sha256=<sha>
```

Also reads `BONFIRE_COMPONENTS_MAPPING` (JSON) for cases where Konflux component names differ from
app-interface component names. `BONFIRE_COMPONENT_NAME` is supported but deprecated.

### `check_cji_jobs.py` — CJI Status Check

Reads a CJI JSON document from stdin, inspects `status.jobMap`, and exits 1 if any job is not
`"Complete"`.

## Key Design Decisions

1. **Source-based distribution.** The library is distributed by sourcing scripts at runtime (via
   `bootstrap.sh` + `curl`), not as a packaged binary. This avoids versioning infrastructure but
   requires callers to pin to a specific git ref for stability.

2. **Guard-based idempotent loading.** Each module uses a `CICD_*_MODULE_LOADED` flag to prevent
   re-sourcing. The loader calls `source` unconditionally — the guard inside each module handles
   deduplication. This means the load order is safe to call multiple times.

3. **Single container engine dispatch.** `cicd::container::cmd` is locked to one engine per process
   lifetime (via `readonly`). Callers cannot switch engines mid-execution. This prevents subtle
   inconsistencies when the same script is used in environments with both podman and docker present.

4. **Pydantic for snapshot validation.** The Python integration layer uses Pydantic models rather
   than plain JSON parsing to catch malformed Konflux snapshots at the boundary, failing fast with
   a clear validation error rather than passing bad data downstream to bonfire.

5. **90.01% coverage gate.** The GitHub Actions `coverage` job enforces a hard minimum on BATS
   test coverage via kcov. New modules must ship with tests that meet this threshold.
