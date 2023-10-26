# Log module

This module provides functions to help write log messages.

## Definition

The module ID is `log`

All functions exposed by this module will use the namespaced prefix:

```
cicd::log::
```

## Usage

Use the `log` id to load the module via the `loader` module, using either the `load_module.sh`
or the `bootstrap.sh` script

### Enabling debug output

enabling the debug output requires to export the `CICD_LOG_DEBUG` variable with a non-empty value.

```
export CICD_LOG_DEBUG=1
```

## Configuration and public functions

### Dependencies

None

### Configuration Variables

- `CICD_LOG_DEBUG` if defined to a non-empty value enables the messages printed through
  the `cicd::log::debug` function

### Public functions

#### cicd::log::debug

echoes a message via standard output (STDOUT) with the timestamp if the environment
varible `CICD_DEBUG_LOG` is defined and not empty

#### cicd::log::info

echoes a message via standard output stream (STDOUT) with the timestamp if the environment
varible `CICD_DEBUG_LOG` is defined and not empty

```
[2021-06-30T10:50:38+0200]: Error output!
```

#### cicd::log::err

echoes a message via standard error stream (STDERR) with the timestamp. Example format:

```
[2021-06-30T10:50:38+0200]: Error output!
```