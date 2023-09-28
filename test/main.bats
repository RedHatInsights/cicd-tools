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
    assert_output --partial "loading container lib"
}

@test "loading all work successfully" {

    CICD_TOOLS_DEBUG=1
    IMAGE_REPOSITORY='foobar'
    run source main.sh all
    assert_success
    assert_output --partial "loading common lib"
    assert_output --partial "loading container lib"
    assert_output --partial "loading image builder lib"
}

@test "loading container helper functions work successfully" {

    podman() {
        echo "podman here"
    }
    run ! cicd::container::cmd
    assert_failure
    CICD_TOOLS_DEBUG=1
    run source main.sh container
    assert_success
    assert_output --partial "loading container lib"
    source main.sh container
    run cicd::container::cmd
    assert_success
    assert_output --partial "podman here"
}

@test "Loading multiple times don't reload libraries multiple times" {

    IMAGE_REPOSITORY='FOO'
    assert [ -z "$CICD_TOOLS_COMMON_LOADED" ]
    source main.sh all
    assert [ "$CICD_TOOLS_COMMON_LOADED" -eq 0 ]
    CICD_TOOLS_DEBUG=1
    run source main.sh ""
    assert_success
    refute_output --partial "loading common lib"
    run source main.sh all
    assert_success
    refute_output --partial "loading common lib"
    run source main.sh container 
    assert_success
    refute_output --partial "loading container lib"
    run source main.sh image_builder
    assert_success
    refute_output --partial "loading image_builder lib"
}
