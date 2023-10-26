setup() {
    load "test_helper/common-setup"
    _common_setup
}

@test "Load directly results in error" {

    run ! source "src/shared/loader.sh"
    assert_failure
    assert_output --partial "use 'load_module.sh' to load this module"
    assert_output --partial "use 'cicd::loader::load_module' to load modules"
}

@test "Load the module multiple times only loads it once" {
    CICD_LOG_DEBUG=1
    run source load_module.sh loader 
    assert_success
    assert_output --partial "loading loader module"
    assert_output --partial "loader module loaded"
    assert_output --partial "loader module already loaded, skipping"

    source load_module.sh loader 
    run cicd::loader::load_module "loader" 
    assert_output --regexp ".*loader module already loaded, skipping"
}

@test "Sets expected loaded flags" {

    assert [ -z "$CICD_LOADER_MODULE_LOADED" ]
    assert [ -z "$CICD_LOADER_SCRIPTS_DIR" ]

    source load_module.sh loader 

    assert [ -n "$CICD_LOADER_MODULE_LOADED" ]
    assert [ -n "$CICD_LOADER_SCRIPTS_DIR" ]
}

@test "Loading message is displayed" {

    CICD_LOG_DEBUG=1
    run source load_module.sh loader 
    assert_success
    assert_output --partial "loading loader module"
}

@test "Unsupported modules fail to load" {

    run ! source load_module.sh unsupported-foo-module
    assert_failure 1
    assert_output --partial "Unsupported module: 'unsupported-foo-module'"
}

@test "Default main loading sequence runs successfully" {

    CICD_LOG_DEBUG=1
    run source load_module.sh ''
    assert_success
    assert_output --partial "loading common module"
    assert_output --partial "loading container module"
}

@test "loading log module works successfully" {

    CICD_LOG_DEBUG=1
    run source load_module.sh log
    assert_success
    assert_output --partial "log module loaded"
}

@test "loading common module works successfully" {

    CICD_LOG_DEBUG=1
    run source load_module.sh common
    assert_success
    assert_output --partial "common module loaded"
}

@test "loading all work successfully" {

    CICD_LOG_DEBUG=1
    run source load_module.sh all
    assert_success
    assert_output --partial "log module loaded"
    assert_output --partial "loader module loaded"
    assert_output --partial "common module loaded"
    assert_output --partial "container module loaded"
    assert_output --partial "image_builder module loaded"
}

@test "loading container helper functions work successfully" {

    podman() {
        echo "podman here"
    }
    run ! cicd::container::cmd
    assert_failure
    CICD_LOG_DEBUG=1
    run source load_module.sh container
    assert_success
    assert_output --partial "loading container module"
    source load_module.sh container
    run cicd::container::cmd
    assert_success
    assert_output --partial "podman here"
}

@test "Loading multiple times don't reload modules multiple times" {

    IMAGE_REPOSITORY='FOO'
    assert [ -z "$CICD_COMMON_MODULE_LOADED" ]
    source load_module.sh all
    assert [ -n "$CICD_COMMON_MODULE_LOADED" ]
    CICD_LOG_DEBUG=1
    run source load_module.sh ""
    assert_success
    refute_output --partial "loading common module"
    run source load_module.sh all
    assert_success
    refute_output --partial "loading common module"
    run source load_module.sh container 
    assert_success
    refute_output --partial "loading container module"
    run source load_module.sh image_builder
    assert_success
    refute_output --partial "loading image_builder module"
}
