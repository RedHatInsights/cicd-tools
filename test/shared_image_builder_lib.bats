
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

    source main.sh image_builder

    assert [ -n "$CICD_TOOLS_COMMON_LOADED" ]
    assert [ -n "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" ]
    assert [ -n "$CICD_TOOLS_IMAGE_BUILDER_LOADED" ]
}

@test "Image tag is set appropriately outside of a change request context" {

    source main.sh image_builder
    run cicd_tools::image_builder::get_image_tag
    assert_success
    assert_output --regexp '^[0-9a-f]{7}$'

    assert [ -n "$CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG" ]
}

@test "Image tag is set appropriately in a Pull Request context" {

    # git mock
    git() {
        echo "1abcdef"
    }

    ghprbPullId=123
    source main.sh image_builder
    run cicd_tools::image_builder::get_image_tag
    assert_success
    assert_output --regexp '^pr-[0-9]+-[0-9a-f]{7}$'

    assert [ -n "$CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG" ]
}

@test "Image tag is set appropriately in a Merge Request context" {

    # git mock
    git() {
        echo "1abcdef"
    }

    gitlabMergeRequestId=4321
    source main.sh image_builder
    run cicd_tools::image_builder::get_image_tag
    assert_success
    assert_output --regexp '^pr-[0-9]+-[0-9a-f]{7}$'

    assert [ -n "$CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG" ]
}

@test "Image build works as expected" {

    # podman mock
    podman() {
        echo "$@"
    }

    # git mock
    git() {
        echo "1abcdef"
    }

    source main.sh image_builder
    run ! cicd_tools::image_builder::build
    assert_failure
    assert_output --partial "you must specify an image name to build"

    run ! cicd_tools::image_builder::build -i "foobar" -f "non-existent-Containerfile"
    assert_failure
    assert_output --partial "non-existent-Containerfile not found "

    run ! cicd_tools::image_builder::build -i "defaults" 
    assert_output --partial "Dockerfile not found"

    run ! cicd_tools::image_builder::build -i foo -f "test/data/Containerfile.test" -X
    assert_output --partial "X"
    assert_output --partial "cannot handle parameter"

    run cicd_tools::image_builder::build -i "someimage"  -f "test/data/Containerfile.test"
    assert_success
    assert_output --partial ""
    assert_output --regexp "\.$"

    run cicd_tools::image_builder::build \
      -l "LABEL1=FOO LABEL2=bar" \
      -i "quay.io/my-awesome-org/my-awesome-app" \
      -t "test1 additional-label-2 security" \
      -b "BUILD_ARG1=foobar BUILD_ARG2=bananas" \
      -c "another/context" \
      -f "test/data/Containerfile.test"
    assert_success
    assert_output --regexp "^build.*"
    assert_output --regexp "another/context$"
    assert_output --partial "-f test/data/Containerfile.test"
    assert_output --regexp "-t quay.io/my-awesome-org/my-awesome-app:[0-9a-f]{7}"
    assert_output --regexp "--label LABEL1=FOO --label LABEL2=bar"
    assert_output --regexp "-t quay.io/my-awesome-org/my-awesome-app:additional-label-2"
    assert_output --regexp "-t quay.io/my-awesome-org/my-awesome-app:security"
    assert_output --regexp "-t quay.io/my-awesome-org/my-awesome-app:test1"
    assert_output --regexp "--build_arg BUILD_ARG1=foobar"
    assert_output --regexp "--build_arg BUILD_ARG2=bananas"


    run cicd_tools::image_builder::build -i "someimage"  -f "test/data/Containerfile.test"
    assert_success
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

    source main.sh image_builder
    run cicd_tools::image_builder::build -i "someimage"  -f "test/data/Containerfile.test"
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
    
    source main.sh image_builder
    run cicd_tools::image_builder::build -i "someimage"  -f "test/data/Containerfile.test"
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

    run ! source main.sh image_builder
    assert_failure
    assert_output --partial "Image builder setup failed!"
    assert_output --partial "Error logging in to Red Hat Registry"
}
