
setup() {
    load "test_helper/common-setup"
    _common_setup
}

@test "Load directly results in error" {

    run ! source "src/shared/container-engine-lib.sh"
    assert_failure
    assert_output --partial "load through main.sh"
}

@test "Sets expected loaded flags" {

    assert [ -z "$CICD_TOOLS_COMMON_LOADED" ]
    assert [ -z "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" ]

    source main.sh container_engine

    assert [ -n "$CICD_TOOLS_COMMON_LOADED" ]
    assert [ -n "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" ]
}

@test "Loading common message is displayed" {

    CICD_TOOLS_DEBUG=1
    run source main.sh container_engine
    assert_success
    assert_output --partial "loading container engine"
}

@test "container engine cmd is set once" {

    docker() {
        echo "docker version 1"
    }
    podman() {
        echo "podman version 1"
    }

    PREFER_CONTAINER_ENGINE="docker"

    run ! container_engine_cmd
    assert_failure
    assert_output --partial "container_engine_cmd: command not found"

    source src/main.sh container_engine

    container_engine_cmd --version
    run container_engine_cmd --version

    assert_success 
    assert_output "docker version 1"

    unset PREFER_CONTAINER_ENGINE
    source main.sh container_engine
    run container_engine_cmd --version
    assert_success 
    assert_output "docker version 1"
}

@test "container engine cmd is set once - setting preference after initial call" {

    docker() {
        echo "docker version 1"
    }
    podman() {
        echo "podman version 1"
    }

    run ! container_engine_cmd
    assert_failure
    assert_output --partial "container_engine_cmd: command not found"

    source src/main.sh container_engine

    container_engine_cmd --version

    PREFER_CONTAINER_ENGINE="docker"

    run container_engine_cmd --version
    assert_success 
    assert_output "podman version 1"

    source main.sh container_engine
    run container_engine_cmd --version
    assert_success 
    assert_output "podman version 1"
}

@test "get container engine cmd" {

    podman() {
        echo "podman version 1"
    }

    source main.sh container_engine
    run container_engine_cmd --version
    assert_output --partial "podman version 1"
}

@test "if forcing docker as container engine but is emulated, keeps looking and uses podman if found" {

    PREFER_CONTAINER_ENGINE="docker"

    docker() {
        podman
    }

    podman() {
        echo 'podman version 1'
    }

    source main.sh container_engine
    run container_engine_cmd --version
    assert_output --regexp "WARNING.*docker.*seems emulated"
    assert_output --partial "podman version 1"
}

@test "if no container engine found, fails" {

    source main.sh container_engine
    OLDPATH="$PATH"
    PATH=':'
    run ! container_engine_cmd --version
    PATH="$OLDPATH"
    assert_failure
    assert_output --partial "ERROR, no container engine found"
}

@test "if forcing podman but not found, uses docker if found and not emulated" {

    PREFER_CONTAINER_ENGINE="podman"

    docker() {
        echo 'docker version 1'
    }
    source main.sh container_engine

    OLDPATH="$PATH"
    PATH=':'
    run container_engine_cmd --version
    PATH="$OLDPATH"
    assert_output --regexp "WARNING.*podman.*not present"
    assert_output --partial "docker version 1"
}

@test "if forcing podman but not found and docker is emulated it fails" {

    PREFER_CONTAINER_ENGINE="podman"

    docker() {
        echo 'podman version 1'
    }
    source main.sh container_engine

    OLDPATH="$PATH"
    PATH=':'
    run container_engine_cmd --version
    PATH="$OLDPATH"
    assert [ $status -eq 1 ]
    assert_output --regexp "WARNING.*docker seems emulated"
    assert_output --regexp "WARNING.*podman.*not present"
    assert_output --partial "no container engine found"
}

@test "Podman is used by default if no container engine preference defined" {

    podman() {
        echo 'podman version 1'
    }
    docker() {
        echo 'docker version 1'
    }
    source main.sh container_engine

    run container_engine_cmd --version
    assert_success
    assert_output --partial "podman version 1"
}

@test "Docker can be set as preferred over podman if both are available" {

    PREFER_CONTAINER_ENGINE='docker'

    podman() {
        echo 'podman version 1'
    }
    docker() {
        echo 'docker version 1'
    }
    source main.sh container_engine
    run container_engine_cmd --version
    assert_success
    assert_output --partial "docker version 1"
}

@test "cat is not a supported container engine" {

    PREFER_CONTAINER_ENGINE='cat'


    cat() {
        echo "not an awesome container engine"
    }
    podman() {
        echo 'podman version 1'
    }
    source main.sh container_engine
    run container_engine_cmd --version
    assert_success
    assert_output --regexp "WARNING.*'cat'.*isn't supported"
    assert_output --partial "podman version 1"
}
