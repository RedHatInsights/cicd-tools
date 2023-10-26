# Common module

Helper functions that are shared and used by other modules

## Definition

The module ID is `common`

All functions exposed by this module will use the namespaced prefix:

```
cicd::common::
```

## Usage

Use the `common` id to load the module

```
CICD_TOOLS_URL="https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh"
# shellcheck source=/dev/null
source <(curl -sSL "$CICD_TOOLS_URL") common
```

## Dependencies

This module requires one of the supported container engines to be present in the session's `PATH`.
The currently supported container engines are:

- `docker`
- `podman`

### Public functions

#### cicd::common::command_is_present

returns 0 (true) if the command passed as a parameter is found in the session's PATH

#### cicd::common::get_7_chars_commit_hash

Returns the first 7 characters from the latest commit of current directory's git HEAD

#### cicd::common::is_ci_context

Returns 0 (true) if the current context is considered a CI context (i.e - running in a job on a CI
system)



