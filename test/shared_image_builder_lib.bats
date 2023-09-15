
setup() {
    load "test_helper/common-setup"
    _common_setup
}

@test "Load directly results in error" {

    run ! source "src/shared/image_builder_lib.sh"
    assert_failure
    assert_output --partial "load through main.sh"
}

@test "Sets expected loaded flags" {

    assert [ -z "$CICD_TOOLS_COMMON_LOADED" ]
    assert [ -z "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" ]
    assert [ -z "$CICD_TOOLS_IMAGE_BUILDER_LOADED" ]

    IMAGE_REPOSITORY='foo'
    source main.sh image_builder

    assert [ -n "$CICD_TOOLS_COMMON_LOADED" ]
    assert [ -n "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" ]
    assert [ -n "$CICD_TOOLS_IMAGE_BUILDER_LOADED" ]
}

@test "Default image tag is set appropriately outside of a change request context" {

    IMAGE_REPOSITORY='foo/bar'
    source main.sh image_builder
    run cicd_tools::image_builder::get_default_image_tag
    assert_success
    assert_output --regexp '^foo/bar:[0-9a-f]{7}$'
}

@test "Default image tag is set appropriately in a Pull Request context" {

    # git mock
    git() {
        echo "1abcdef"
    }

    ghprbPullId=123
    IMAGE_REPOSITORY='pull/request'
    source main.sh image_builder
    run cicd_tools::image_builder::get_default_image_tag
    assert_success
    assert_output --regexp '^pull/request:pr-[0-9]+-[0-9a-f]{7}$'
}

@test "Default image tag is set appropriately in a Merge Request context" {

    # git mock
    git() {
        echo "1abcdef"
    }

    gitlabMergeRequestId=4321
    IMAGE_REPOSITORY='merge/request'
    source main.sh image_builder
    run cicd_tools::image_builder::get_default_image_tag
    assert_success
    assert_output --regexp '^merge/request:pr-[0-9]+-[0-9a-f]{7}$'
}

@test "fails if no image repository is defined" {

    run ! source main.sh image_builder
    assert_failure
    assert_output --partial "Image repository not defined, please set IMAGE_REPOSITORY"
}

@test "Image build works as expected with default values" {

    # podman mock
    podman() {
        echo "$@"
    }

    # git mock
    git() {
        echo "1abcdef"
    }

    IMAGE_REPOSITORY='foo'
    source main.sh image_builder
    run cicd_tools::image_builder::build
    assert_success
    assert_output --regexp "^build"
    assert_output --partial "-f Dockerfile"
    assert_output --partial "-t foo:1abcdef"
    assert_output --regexp "\.$"
}

@test "Image build works as expected with all custom values set" {

    # podman mock
    podman() {
        echo "$@"
    }

    # git mock
    git() {
        echo "1abcdef"
    }

    IMAGE_REPOSITORY='quay.io/my-awesome-org/my-awesome-app'
    CICD_TOOLS_IMAGE_BUILDER_LABELS=("LABEL1=FOO" "LABEL2=bar")
    CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS=("test1" "additional-label-2" "security")
    CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS=("BUILD_ARG1=foobar" "BUILD_ARG2=bananas")
    CICD_TOOLS_IMAGE_BUILDER_BUILD_CONTEXT='another/context'
    CICD_TOOLS_IMAGE_BUILDER_CONTAINER_FILE='test/data/Containerfile.test'

    source main.sh image_builder
    run cicd_tools::image_builder::build
    assert_success
    assert_output --regexp "^build.*"
    assert_output --regexp "another/context$"
    assert_output --partial "-f test/data/Containerfile.test"
    assert_output --regexp "-t quay.io/my-awesome-org/my-awesome-app:[0-9a-f]{7}"
    assert_output --partial "--label LABEL1=FOO"
    assert_output --partial "--label LABEL2=bar"
    assert_output --partial "-t quay.io/my-awesome-org/my-awesome-app:additional-label-2"
    assert_output --partial "-t quay.io/my-awesome-org/my-awesome-app:security"
    assert_output --partial "-t quay.io/my-awesome-org/my-awesome-app:test1"
    assert_output --partial "--build-arg BUILD_ARG1=foobar"
    assert_output --partial "--build-arg BUILD_ARG2=bananas"
}

@test "Image builds gets expiry label in change request context" {

    # podman mock
    podman() {
        echo "$@"
    }

    # git mock
    git() {
        echo "1abcdef"
    }

    ghprbPullId="123"
    IMAGE_REPOSITORY="someimage"
    source main.sh image_builder
    run cicd_tools::image_builder::build
    assert_success
    assert_output --partial "-t someimage:pr-123-1abcdef"
    assert_output --partial "--label quay.expires-after=3d"
}

@test "Image build failures are caught" {

    # podman mock
    podman() {
        echo "something went really wrong" >&2
        return 1
    }

    # git mock
    git() {
        echo "1abcdef"
    }
    
    IMAGE_REPOSITORY="someimage"
    source main.sh image_builder
    run cicd_tools::image_builder::build
    assert_failure
    assert_output --partial "went really wrong"
    assert_output --partial "Error building image"

}

@test "Image builder tries to login to registries" {

    # podman mock
    podman() {
        echo "$@"
    }

    CICD_TOOLS_IMAGE_BUILDER_QUAY_USER="username1"
    CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD="secr3t"
    IMAGE_REPOSITORY="someimage"

    run source main.sh image_builder
    assert_success
    assert_output --regexp "^login.*quay.io" 
    assert_output --partial "-u=username1"

    CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER="username2"
    CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD="secr3t"

    run source main.sh image_builder
    assert_success
    assert_output --regexp "^login.*registry.redhat.io" 
    assert_output --partial "-u=username2"
}

@test "Image builder logs failure on logging in to Quay.io" {

    # podman mock
    podman() {
        return 1
    }

    CICD_TOOLS_IMAGE_BUILDER_QUAY_USER="wrong-user"
    CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD="secr3t"
    IMAGE_REPOSITORY="someimage"
    
    run ! source main.sh image_builder
    assert_failure
    assert_output --partial "Image builder setup failed!"
    assert_output --partial "Error logging in to Quay.io"


}

@test "Image builder logs failure on logging in to Red Hat Registry" {

    # podman mock
    podman() {
        return 1
    }

    CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER="wrong-user"
    CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD="wrong-password"
    IMAGE_REPOSITORY="someimage"

    run ! source main.sh image_builder
    assert_failure
    assert_output --partial "Image builder setup failed!"
    assert_output --partial "Error logging in to Red Hat Registry"
}
