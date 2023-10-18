setup() {
    load 'test_helper/common-setup'
    _common_setup
}

@test "Unsupported modules fail to load" {

    run ! source load_module.sh unsupported-foo-module
    assert_failure 1
    assert_output --partial "Unsupported module: 'unsupported-foo-module'"
}

@test "Default main loading sequence runs successfully" {

    CICD_LOG_DEBUG=1
    run source src/load_module.sh ''
    assert_success
    assert_output --partial "loading common module"
    assert_output --partial "loading container module"
}

@test "loading all work successfully" {

    CICD_LOG_DEBUG=1
    run source load_module.sh all
    assert_success
    assert_output --partial "loading common module"
    assert_output --partial "loading container module"
    assert_output --partial "loading image builder module"
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
