setup() {
    load 'test_helper/common-setup'
    _common_setup
}

@test "Unsupported libraries fail to load" {

    run ! source main.sh unsupported-foo-library
    assert_failure 1
    assert_output --partial "Unsupported library: 'unsupported-foo-library'"
}

@test "Default main loading sequence runs successfully" {

    CICD_TOOLS_DEBUG=1
    run source src/main.sh ''
    assert_success
    assert_output --partial "loading common"
    assert_output --partial "loading container engine"
}

@test "loading all work successfully" {

    CICD_TOOLS_DEBUG=1
    run source main.sh all
    assert_success
    assert_output --partial "loading common"
    assert_output --partial "loading container engine"
}

@test "loading container helper functions work successfully" {

    podman() {
        echo "podman here"
    }
    run ! container_engine_cmd
    assert_failure
    CICD_TOOLS_DEBUG=1
    run source main.sh container_engine
    assert_success
    assert_output --partial "loading container engine"
    source main.sh container_engine
    run container_engine_cmd
    assert_success
    assert_output --partial "podman here"
}

@test "Loading multiple times don't reload libraries multiple times" {

    assert [ -z "$CICD_TOOLS_COMMON_LOADED" ]
    source main.sh
    assert [ "$CICD_TOOLS_COMMON_LOADED" -eq 0 ]
    CICD_TOOLS_DEBUG=1
    run source main.sh ""
    refute_output --partial "loading common"
    run source main.sh all
    refute_output --partial "loading common"
    run source main.sh container_engine
    refute_output --partial "loading container engine"
}
