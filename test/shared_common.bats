
setup() {
    load "test_helper/common-setup"
    _common_setup
}

@test "Load directly results in error" {

    run ! source "src/shared/common.sh"
    assert_failure
    assert_output --partial "please use 'load_module.sh' to load modules."
}

@test "Load the module multiple times only loads it once" {
    CICD_LOG_DEBUG=1
    source load_module.sh common
    run cicd::loader::load_module common
    assert_success
    assert_output --partial "common module already loaded, skipping"
}


@test "Sets expected loaded flags" {

    assert [ -z "$CICD_COMMON_MODULE_LOADED" ]

    source load_module.sh common

    assert [ -n "$CICD_COMMON_MODULE_LOADED" ]
}


@test "Loading common message is displayed" {

    CICD_LOG_DEBUG=1
    run source load_module.sh common
    assert_success
    assert_output --partial "loading common"
}

@test "command is present works" {

    cat() {
        echo "cat exists"
    }

    source load_module.sh common
    run ! cicd::common::command_is_present foo
    assert_failure

    run cicd::common::command_is_present cat
    assert_success
    assert_output ""
}

@test "get_7_chars_commit_hash works" {

    source load_module.sh common
    run cicd::common::get_7_chars_commit_hash
    assert_success
    assert_output --regexp '^[0-9a-f]{7}$'
}

@test "is_ci_context" {

    source src/load_module.sh common

    unset CI
    assert [ -z "$CI" ]

    run cicd::common::is_ci_context
    assert_failure
    assert_output ""

    export CI='true'
    run cicd::common::is_ci_context
    assert_success
    assert_output ""
}
