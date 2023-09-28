
setup() {
    load "test_helper/common-setup"
    _common_setup
}

@test "Load directly results in error" {

    run ! source "src/shared/common_lib.sh"
    assert_failure
    assert_output --partial "load through main.sh"
}

@test "Sets expected loaded flags" {

    assert [ -z "$CICD_TOOLS_COMMON_LOADED" ]

    source main.sh common

    assert [ "$CICD_TOOLS_COMMON_LOADED" -eq 0 ]
}


@test "Loading common message is displayed" {

    CICD_TOOLS_DEBUG=1
    run source main.sh common
    assert_success
    assert_output --partial "loading common"
}

@test "command is present works" {

    cat() {
        echo "cat exists"
    }

    source main.sh common
    run ! cicd::common::command_is_present foo
    assert_failure

    run cicd::common::command_is_present cat
    assert_success
    assert_output ""
}

@test "get_7_chars_commit_hash works" {

    source main.sh common
    run cicd::common::get_7_chars_commit_hash
    assert_success
    assert_output --regexp '^[0-9a-f]{7}$'
}

@test "local build check" {

    unset CI

    assert [ -z "$LOCAL_BUILD" ]
    assert [ -z "$CI" ]
    source src/main.sh common
    run cicd::common::local_build
    assert_success
    CI='true'
    run cicd::common::local_build
    assert_failure
    assert_output ""
    LOCAL_BUILD='true'
    run cicd::common::local_build
    assert_output ""
    assert_success
    unset LOCAL_BUILD
    run ! cicd::common::local_build
    assert_output ""
    assert_failure
}

@test "is_ci_context" {

    source src/main.sh common

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
