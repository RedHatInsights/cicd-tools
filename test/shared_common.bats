
setup() {
    load "test_helper/common-setup"
    _common_setup
}

@test "Common can be sourced directly" {

    run source "src/shared/common.sh"
    assert_success
}


@test "Sets expected loaded flags" {

    assert [ -z "$CICD_TOOLS_COMMON_LOADED" ]

    source "src/shared/common.sh"

    assert [ "$CICD_TOOLS_COMMON_LOADED" -eq 0 ]
}


@test "Loading common message is displayed" {

    CICD_TOOLS_DEBUG=1
    run source 'src/shared/common.sh'
    assert_success
    assert_output "loading common"
}

@test "command is present works" {

    cat() {
        echo "cat exists"
    }

    source "src/shared/common.sh"
    run ! command_is_present foo
    assert_failure

    run command_is_present cat
    assert_success
    assert_output ""
}

@test "get_7_chars_commit_hash works" {

    source "src/shared/common.sh"
    run cicd_tools::common::get_7_chars_commit_hash
    assert_success
    assert_output --regexp '^[0-9a-f]{7}$'
}

@test "local build check" {

    assert [ -z "$LOCAL_BUILD" ]
    assert [ -z "$CI" ]
    source "src/shared/common.sh"
    assert local_build
    CI='true'
    refute local_build
    LOCAL_BUILD='true'
    assert local_build
    unset LOCAL_BUILD
    refute local_build
}
