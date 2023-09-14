
setup() {
    load "test_helper/common-setup"
    _common_setup
}

@test "Load directly results in error" {

    run ! source "src/shared/container_image_builder_lib.sh"
    assert_failure
    assert_output --partial "load through main.sh"
}

@test "Sets expected loaded flags" {

    assert [ -z "$CICD_TOOLS_COMMON_LOADED" ]
    assert [ -z "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" ]
    assert [ -z "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED" ]

    source main.sh image_builder

    assert [ -n "$CICD_TOOLS_COMMON_LOADED" ]
    assert [ -n "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" ]
    assert [ -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED" ]
}

@test "Image tag is set appropriately outside of a change request context" {

    source main.sh image_builder
    run cicd_tools::image_builder::get_image_tag
    assert_success
    assert_output --regexp '^[0-9a-f]{7}$'

    assert [ -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG" ]
}

@test "Image tag is set appropriately in a Pull Request context" {

    ghprbPullId=123
    source main.sh image_builder
    run cicd_tools::image_builder::get_image_tag
    assert_success
    assert_output --regexp '^pr-[0-9]+-[0-9a-f]{7}$'

    assert [ -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG" ]
}

@test "Image tag is set appropriately in a Merge Request context" {

    gitlabMergeRequestId=4321
    source main.sh image_builder
    run cicd_tools::image_builder::get_image_tag
    assert_success
    assert_output --regexp '^pr-[0-9]+-[0-9a-f]{7}$'

    assert [ -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG" ]
}
