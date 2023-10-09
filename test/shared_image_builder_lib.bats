
setup() {
    load "test_helper/common-setup"
    _common_setup
}

@test "Load directly results in error" {

    run ! source "src/shared/image_builder_lib.sh"
    assert_failure
    assert_output --partial "load through main.sh"
}

@test "Does not fail sourcing the library" {

    run source main.sh image_builder
    assert_success
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

@test "Image tag outside of a change request context" {

    # git mock
    git() {
        echo "1abcdef"
    }

    source main.sh image_builder
    run cicd::image_builder::get_image_tag
    assert_success
    assert_output '1abcdef'
}

@test "Image tags in a Pull Request context" {

    # git mock
    git() {
        echo "1abcdef"
    }

    ghprbPullId=123
    source main.sh image_builder

    run cicd::image_builder::get_image_tag

    assert_success
    assert_output 'pr-123-1abcdef'
}

@test "Image tags in a Merge Request context" {

    # git mock
    git() {
        echo "1abcdef"
    }

    gitlabMergeRequestId=4321

    source main.sh image_builder

    run cicd::image_builder::get_image_tag

    assert_success
    assert_output 'pr-4321-1abcdef'
}


@test "Image build fails if Dockerfile doesn't exist" {

    # podman mock
    podman() {
        echo "$@"
    }

    # git mock
    git() {
        echo "1abcdef"
    }

    source main.sh image_builder

    EXPECTED_CONTAINERFILE_PATH='Dockerfile'
    IMAGE_NAME='quay.io/foo/bar'

    refute [ -r "$EXPECTED_CONTAINERFILE_PATH" ]
    run ! cicd::image_builder::build
    assert_failure
    assert_output --regexp "$EXPECTED_CONTAINERFILE_PATH.*does not exist"
    refute_output --regexp "build"
}

@test "Image build fails if no image name is defined" {

    # podman mock
    podman() {
        echo "$@"
    }

    # git mock
    git() {
        echo "1abcdef"
    }

    source main.sh image_builder

    run ! cicd::image_builder::build
    assert_failure
    assert_output --partial "Image name not defined"
    refute_output --partial "build"
}

@test "Image build fails if git hash cannot be retrieved" {

    # podman mock
    podman() {
        echo "$@"
    }

    # git mock
    git() {
        return 1
    }

    IMAGE_NAME='quay.io/foo/bar'
    source main.sh image_builder

    run ! cicd::image_builder::build
    assert_failure
    assert_output --partial "Cannot retrieve commit hash"
    refute_output --partial "build"
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

    source main.sh image_builder

    EXPECTED_CONTAINERFILE_PATH='Dockerfile'
    IMAGE_NAME='quay.io/foo/bar'

    touch "${EXPECTED_CONTAINERFILE_PATH}"
    run cicd::image_builder::build
    rm "${EXPECTED_CONTAINERFILE_PATH}"

    assert_success
    assert_output --regexp "^build"
    assert_output --partial "-f Dockerfile"
    assert_output --partial "-t quay.io/foo/bar:1abcdef"
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

    source main.sh image_builder

    IMAGE_NAME='quay.io/my-awesome-org/my-awesome-app'
    CICD_TOOLS_IMAGE_BUILDER_LABELS=("LABEL1=FOO" "LABEL2=bar")
    CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS=("test1" "additional-label-2" "security")
    CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS=("BUILD_ARG1=foobar" "BUILD_ARG2=bananas")
    CICD_TOOLS_IMAGE_BUILDER_BUILD_CONTEXT='another/context'
    CICD_TOOLS_IMAGE_BUILDER_CONTAINERFILE_PATH='test/data/Containerfile.test'

    run cicd::image_builder::build

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

    source main.sh image_builder

    ghprbPullId="123"
    IMAGE_NAME="someimage"
    CONTAINERFILE_PATH='test/data/Containerfile.test'

    run cicd::image_builder::build

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

    IMAGE_NAME="someimage"
    CONTAINERFILE_PATH='test/data/Containerfile.test'

    run cicd::image_builder::build

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


@test "Get all image tags" {

    # git mock
    git() {
        echo "1abcdef"
    }

    source main.sh image_builder

    IMAGE_NAME="someimage"
    ADDITIONAL_TAGS=("foo" "bar" "baz")

    run cicd::image_builder::get_image_tag

    assert_success
    assert_output "1abcdef"


    run cicd::image_builder::get_additional_tags

    assert_success
    assert_output "foo bar baz"
}

@test "tag all images" {

    # git mock
    git() {
        echo "source"
    }
    # podman mock
    podman() {
        echo "$@"
    }

    source main.sh image_builder

    IMAGE_NAME="someimage"
    ADDITIONAL_TAGS=("target1" "target2" "target3")

    run cicd::image_builder::tag
    assert_success

    refute_output --partial "tag someimage:source someimage:source"
    assert_output --partial "tag someimage:source someimage:target1"
    assert_output --partial "tag someimage:source someimage:target2"
    assert_output --partial "tag someimage:source someimage:target3"
}

@test "tag error is caught" {

    # git mock
    git() {
        echo "source"
    }
    # podman mock
    podman() {
      echo "$@"
      return 1
    }

    source main.sh image_builder

    IMAGE_NAME="someimage"
    ADDITIONAL_TAGS=("target1")

    run ! cicd::image_builder::tag

    assert_failure
    assert_output --partial "tag someimage:source someimage:target1"
    assert_output --regexp "Error tagging.*someimage:source.*someimage:target1"
}

@test "push all images" {

    # git mock
    git() {
        echo "abcdef1"
    }
    # podman mock
    podman() {
        echo "$@"
    }

    source main.sh image_builder

    IMAGE_NAME="someimage"
    ADDITIONAL_TAGS=("tag1" "tag2")

    run cicd::image_builder::push

    assert_success
    assert_output --partial "push someimage:abcdef1"
    assert_output --partial "push someimage:tag1"
    assert_output --partial "push someimage:tag2"
}

@test "push all image tags with context prefix on change-request-context" {

    # git mock
    git() {
        echo "abcdef1"
    }
    # podman mock
    podman() {
        echo "$@"
    }

    source main.sh image_builder

    IMAGE_NAME="someimage"
    ghprbPullId="123"
    ADDITIONAL_TAGS=("tag1" "tag2")

    run cicd::image_builder::push

    assert_success
    assert_output --partial "push someimage:pr-123-abcdef1"
    assert_output --regexp "push someimage:pr-123-tag1"
    assert_output --regexp "push someimage:pr-123-tag2"
}

@test "push error is caught" {

    # git mock
    git() {
      echo "source"
    }
    # podman mock
    podman() {
      echo "$@"
      return 1
    }

    source main.sh image_builder

    IMAGE_NAME="someimage"
    ADDITIONAL_TAGS=("target1")

    run ! cicd::image_builder::push

    assert_failure
    assert_output --partial "push someimage:source"
    assert_output --partial "Error pushing image"
}

@test "build and push does not push if not on local build context" {

    # git mock
    git() {
      echo "source"
    }
    # podman mock
    podman() {
      echo "$@"
    }

    if [ -n "$CI" ]; then
        unset CI
    fi

    source main.sh image_builder

    IMAGE_NAME="someimage"
    ADDITIONAL_TAGS=("target1")
    CONTAINERFILE_PATH='test/data/Containerfile.test'

    run cicd::image_builder::build_and_push

    assert_success
    assert_output --regexp "^build.*?-t someimage:source -t someimage:target1"
    refute_output --partial "push"
}

@test "build and push pushes if not on local build context" {

    # git mock
    git() {
      echo "source"
    }
    # podman mock
    podman() {
      echo "$@"
    }

    if [ -n "CI" ]; then
        CI="true"
    fi

    source main.sh image_builder

    IMAGE_NAME="someimage"
    ADDITIONAL_TAGS=("target1" "target2")
    CONTAINERFILE_PATH='test/data/Containerfile.test'

    run cicd::image_builder::build_and_push

    assert_success
    assert_output --regexp "^build.*?-t someimage:source"
    assert_output --regexp "^build.*?-t someimage:target1"
    assert_output --regexp "^build.*?-t someimage:target2"
    assert_output --partial "push someimage:source"
    assert_output --partial "push someimage:target1"
    assert_output --partial "push someimage:target2"
}


@test "build_and_push pushes all tags with context prefix if on change request context" {

    # git mock
    git() {
      echo "source"
    }
    # podman mock
    podman() {
      echo "$@"
    }

    source main.sh image_builder

    ghprbPullId='123'
    IMAGE_NAME="someimage"
    ADDITIONAL_TAGS=("target1" "target2")
    CONTAINERFILE_PATH='test/data/Containerfile.test'

    run cicd::image_builder::build_and_push

    assert_success
    assert_output --regexp "^build.*?-t someimage:pr-123-source"
    assert_output --regexp "^build.*?--label quay.expires-after"
    assert_output --regexp "^build.*?-t someimage:pr-123-target1"
    assert_output --regexp "^build.*?-t someimage:pr-123-target2"
}

@test "Image build setup doesn't force fresh DOCKER_CONF if not in CI context" {

    unset DOCKER_CONFIG
    unset CI

    source main.sh image_builder
    assert [ -z "$DOCKER_CONFIG" ]
}

@test "build on CI forces fresh DOCKER_CONF creds in CI context" {

    CI="true"
    unset DOCKER_CONFIG

    source main.sh image_builder
    assert [ -n "$DOCKER_CONFIG" ]
    assert [ -w "${DOCKER_CONFIG}/config.json" ]
}

@test "Default image tag is configured if none set" {

    git() {
        echo -n "abcdef1"
    }

    source main.sh image_builder

    expected_tag="abcdef1"
    run cicd::image_builder::get_image_tag
    assert_output "$expected_tag"

    export CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG='some-cool-tag'
    expected_tag="$CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG"
    run cicd::image_builder::get_image_tag
    assert_output "$expected_tag"
}

@test "Build custom tag support" {

    # podman mock
    podman() {
        echo "$@"
    }

    source main.sh image_builder

    export CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG='custom-tag1'
    export CICD_TOOLS_IMAGE_BUILDER_IMAGE_NAME='foobar'
    export CONTAINERFILE_PATH='test/data/Containerfile.test'

    expected_tag="$CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG"
    run cicd::image_builder::get_image_tag

    assert_output "$expected_tag"

    run cicd::image_builder::build

    assert_output --regexp "^build.*-t foobar:custom-tag1"

    export CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG='custom-tag2'
    run cicd::image_builder::build

    assert_output --regexp "^build.*-t foobar:custom-tag2"
    refute_output --regexp "^build.*-t foobar:custom-tag1"
}

@test "Custom tag support for change request context" {

    # podman mock
    podman() {
        echo "$@"
    }

    source main.sh image_builder

    export CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG='custom-tag1'
    export ghprbPullId=123

    expected_tag="pr-123-$CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG"
    run cicd::image_builder::get_image_tag

    assert_output "$expected_tag"
}

@test "Build additional tags in change request context" {

    # podman mock
    podman() {
        echo "$@"
    }

    source main.sh image_builder

    export CICD_TOOLS_IMAGE_BUILDER_IMAGE_NAME='foobar'
    export CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG='custom-tag1'
    export CONTAINERFILE_PATH='test/data/Containerfile.test'
    export CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS=("extra1" "extra2")
    export ghprbPullId=123

    expected_tag="pr-123-$CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG"
    run cicd::image_builder::get_image_tag

    assert_output "$expected_tag"

    run cicd::image_builder::build

    assert_output --regexp "^build.*-t foobar:pr-123-custom-tag1"
    assert_output --regexp "^build.*-t foobar:pr-123-extra1"
    assert_output --regexp "^build.*-t foobar:pr-123-extra2"
}
