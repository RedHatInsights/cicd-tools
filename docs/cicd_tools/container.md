# Container module

This module provides functions to help write container-engine agnostic Bash scripts. It does so by
invoking one of the supported container engines found in the user's PATH.

## Definition

The module ID is `container`

All functions exposed by this module will use the namespaced prefix:

```
cicd::container::
```

## Usage

Use the `container` id to load the module via the `loader` module, using either the `load_module.sh`
or the `bootstrap.sh` script

```
CICD_TOOLS_URL="https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh"
# shellcheck source=/dev/null
source <(curl -sSL "$CICD_TOOLS_URL") container
```

This should load the function:

```
cicd::container::cmd
```

which serves as a wrapper to the container engine of choice. You should be able to safely replace
your invocations to `docker` or `podman` commands with this function

### Container engine detection and order choice

The library favors `podman` in case both container engines are available in the user's PATH.

### Override container engine selection

If you want to force the library to stick to a preferred container engine, you can do so by setting
the `CICD_TOOLS_CONTAINER_PREFER_ENGINE` to one of the supported container engines available *
*before** loading the library.

The container engine is selected when the library is loaded and is not possible to update it
afterward.

```
export CICD_TOOLS_CONTAINER_PREFER_ENGINE=docker
```

**Please note:** If you set your preference to be `docker` and the library detects that `docker` is
actually mocked as a wrapper to `podman` the library will ignore the preference and will try to
set `podman` as the selected container engine.

## Dependencies

This module requires one of the supported container engines to be present in the session's `PATH`.
The currently supported container engines are:

- `docker`
- `podman`

### Public functions

#### cicd::container::cmd

Should be used instead of a container engine command to support container-engine agnostic commands (
among the supported container engines)