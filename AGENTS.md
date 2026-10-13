# cicd-tools

cicd-tools is a shared Bash script library and UBI9-minimal container image that provides
utilities for running smoke tests in ephemeral environments inside CI/CD pipelines. It is used
by RedHatInsights teams to standardize ephemeral-environment lifecycle management — namespace
reservation, application deployment via Bonfire, IQE test execution, log collection, and
artifact upload to S3/MinIO — across both GitHub Actions and Jenkins-based pipelines. The
library is consumed via a remote `bootstrap.sh` curl-and-source pattern and is distributed as a
SHA-tagged container image on Quay.io.

## Dependencies

**Runtime (container image)**

- `oc` — OpenShift CLI 4.14
- `mc` — MinIO client
- `awscli==1.29.28`
- Python: `crc-bonfire>=6.8.0`, `boto3`, `pydantic` (see `requirements.txt`)

**Dev / test**

- [BATS][bats] (bats-core, bats-support, bats-assert) — git submodules under `test/`
- ShellCheck — Bash linter, enforced in CI on `./src`
- kcov — coverage measurement; 90.01% minimum enforced in CI

## Development Commands

See the **Development Setup** section in the [project README][readme] for environment
prerequisites.

```bash
# Initialize submodules (required before running tests)
git submodule update --init --recursive

# Run BATS unit tests
./test/bats/bin/bats test

# Run ShellCheck linter (mirrors CI)
shellcheck ./src

# Generate kcov coverage report (requires kcov installed)
./test/generate_coverage.sh
```

CI runs ShellCheck on `./src`, BATS unit tests, E2E tests (`test/e2e/`), and kcov coverage
checks via `.github/workflows/tests.yml`. The container image is built and scanned by
Tekton/Konflux (`.tekton/`); there is no local image build target.

## Architecture

The library exposes a module system rooted in `src/shared/`. Consumers source `src/bootstrap.sh`,
which clones the repo to `.cicd_tools/` and sources `load_module.sh`; from there, individual
modules are loaded on demand via `cicd::loader::load_module <id>`. Konflux integration lives
entirely in `konflux_scripts/` as standalone shell and Python scripts. The container image
(`Dockerfile`) packages the library and its Python dependencies on UBI9-minimal with a non-root
`tools` user.

See [ARCHITECTURE.md][architecture] for module dependency graphs, loading sequence, and design
decisions.

## Code Style

- **Linter:** ShellCheck on `./src` only — CI-enforced; no pre-commit hook configured.
- **Style guide:** [Google Shell Style Guide][google-shell].
- **Function naming:** `cicd::<module>::<function>` (public), `cicd::<module>::_<function>`
  (private). Module-load guards use `CICD_*_MODULE_LOADED` variables to prevent double-sourcing.
- **No formatter** is configured.
- Python files in `konflux_scripts/` and `iqe_pod/` are not covered by any CI linter.

## Common Mistakes

1. **Skipping submodule initialization.** BATS and its helpers are git submodules under `test/`.
   Running `./test/bats/bin/bats test` without first running `git submodule update --init` will
   fail with missing binary errors.

2. **Adding functions without module-load guards.** Every module must check and set its
   `CICD_*_MODULE_LOADED` variable. Omitting the guard causes re-sourcing that silently
   overwrites `readonly` variables and breaks the container engine selection in `container.sh`.

3. **Editing `./src` without running ShellCheck.** ShellCheck is the only enforced gate on
   `./src`. There is no pre-commit hook — run `shellcheck ./src` before pushing.

4. **Hard-coding `podman` or `docker` in scripts.** `container.sh` auto-detects the engine once
   and sets the result `readonly`. Always use `cicd::container::cmd` — hard-coding either engine
   breaks on environments where only one is available.

5. **Treating `konflux_scripts/` as library modules.** Scripts under `konflux_scripts/` are
   standalone Tekton step scripts, not loadable modules. They do not follow the
   `cicd::<module>::<function>` naming convention and must not be sourced via `load_module`.

## Testing

BATS unit tests in `test/` cover modules in `src/shared/`. E2E tests in `test/e2e/` require a
live OpenShift cluster and are not expected to pass in local development without that environment.

```bash
# Unit tests (no cluster required)
./test/bats/bin/bats test

# Coverage (kcov must be installed; 90.01% minimum enforced in CI)
./test/generate_coverage.sh
```

## Deployment

The container image is built automatically by Tekton/Konflux (`.tekton/`) on every merge to
`main` and published SHA-tagged to:

```
quay.io/redhat-user-workloads/hcm-eng-prod-tenant/cicd-tools/cicd-tools
```

The pipeline includes Clair, Snyk SAST, ClamAV, and SBOM generation. There is no manual release
process.

[architecture]: ./ARCHITECTURE.md
[readme]: ./README.md
[bats]: https://github.com/bats-core/bats-core
[google-shell]: https://google.github.io/styleguide/shellguide.html
