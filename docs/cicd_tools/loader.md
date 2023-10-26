# loader module

Loads other modules provided by the library.

**Internal use only**

This is an internal API for the CICD tools library and not intended for public use. Library users
should use the [/src/bootstrap.sh](/src/bootstrap.sh) script in lieu of calling the loader module
itself

## Definition

The module ID is `loader`

All functions exposed by this module will use the namespaced prefix:

```
cicd::loader::
```

## Usage

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