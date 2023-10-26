# loader module

This module provides functions to help loading the different modules included in this library.

## Definition

The module ID is `loader`

All functions exposed by this module will use the namespaced prefix:

```
cicd::loader::
```

## Usage

**Note:** This is an **internal module** and is not meant to be loaded directly, you should try to
use
*the [src/bootstrap.sh](load_module.sh) script as it already provides means to load this module.

To load this module, the `CICD_LOADER_SCRIPTS_DIR` must be set with the path to the root directory
where the different modules to be loaded are located.

## Configuration and public functions

### Dependencies

- `CICD_LOADER_SCRIPTS_DIR` variable is **required** to be set to the path containing the modules to
  be loaded

### Configuration Variables

- `CICD_LOADER_SCRIPTS_DIR` The path to the root directory containing all the library's modules.

### Public functions

#### cicd::loader::load_module

receives a module id and sources it. All the module source scripts are relative to the directory
defined in the `CICD_LOADER_SCRIPTS_DIR` variable