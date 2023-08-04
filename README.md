# CI/CD Tools

## Description
Utilities used to run smoke tests in an ephemeral environment within a CI/CD pipeline

## Getting Started
Grab the [Jenkinsfile template](templates/Jenkinsfile) and cater it to your specific needs. This file should reside in your git repositories root directory. That Jenkinsfile will 
download the necessary files from this repository. It does not have a unit test file so that will need to be made in your repository. You can find a 
unit test template file [here](templates/unit_test_example.sh).

## Scripts

| Script                  | Description |  
| ----------------------- | ----------- | 
| bootstrap.sh            | Clone bonfire into workspace, setup python venv, modify PATH, login to container registries, login to Kube/OCP,  and set envvars used by following scripts. |
| build.sh                | Using docker (rhel7) or podman (else) build, tag, and push an image to Quay and Red Hat registries. If its a GitHub or GitLab PR/MR triggered script execution, tag image with `pr-123-SHA` and `pr-123-testing`, else use a short SHA for the target repo HEAD. |
| deploy_ephemeral_db.sh  | Deploy using `bonfire process` and `<oc_wrapper> apply`, removing dependencies and setting up database envvars. |
| deploy_ephemeral_env.sh | Deploy using `bonfire deploy` into ephemeral, specifying app, component, and relevant image tag args.  Passes `EXTRA_DEPLOY_ARGS` which can be set by the caller via pr_checks.sh.
| cji_smoke_test.sh       | Run iqe-tests container for the relevant app plugin using `bonfire deploy-iqe-cji`. Waits for tests to complete, and fetches artifacts using minio.
| post_test_results.sh    | Using artifacts fetched from `cji_smoke_test.sh`, add a GitHub status or GitLab comment linking to the relevant test results in Ibutsu.
| smoke_test.sh           | **DEPRECATED**, use [cji_smoke_test.sh](cji_smoke_test.sh) |
| iqe_pod                 | **DEPRECATED**, use [cji_smoke_test.sh](cji_smoke_test.sh) |

## Bash script helper scripts usage

The collection of helper scripts are expected to be loaded using the provided [src/bootstrap.sh](bootstrap) script.

Currently there is 1 collection available:

- Container helper scripts: provides wrapper functions for invoking container engine agnostic commands

To use any of the provided libraries, you must source the [src/bootstrap.sh](bootstrap.sh) script.
One can simply either source the [src/bootstrap.sh](bootstrap) script directly:

```
$ source <(curl -sSL https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh)
$ container_engine_cmd --version
  podman version 4.6.1

```

In case you want to refactor some of your scripts using this library, here's a snippet you can use:

```
load_cicd_helper_functions() {

    local LIBRARY_TO_LOAD=${1:-all}
    local CICD_TOOLS_REPO_BRANCH='main'
    local CICD_TOOLS_REPO_ORG='RedHatInsights'
    local CICD_TOOLS_URL="https://raw.githubusercontent.com/${CICD_TOOLS_REPO_ORG}/cicd-tools/${CICD_TOOLS_REPO_BRANCH}/src/bootstrap.sh"
    set -e
    source <(curl -sSL "$CICD_TOOLS_URL") "$LIBRARY_TO_LOAD"
    set +e
}

load_cicd_helper_functions
```

you can select which collection needs to load independently as a parameter:

```
source bootstrap.sh container_engine
```

The bootstrap script will download the selected version of the CICD scripts (or `latest` if none specified) into the directory defined by
the `CICD_TOOLS_WORKDIR` variable (defaults to `.cicd_tools` in the current directory). 

**Please note** that the directory defined by the `CICD_TOOLS_WORKDIR` will be deleted !
You can disable recreation feature by setting the `CICD_TOOLS_SKIP_RECREATE` variable

The bootstrap.sh can be invoked multiple times but it has a status control to ensure each
of the libraries is loaded only once. This is to prevent potential issues with collections 
that are not supposed to be loaded many times.

An example of this is the _container_engine_ library, where the selected container engine
is **set only once the first command using the library helper function `container_engine_cmd` is used**.


## Template Scripts
| Script                  | Description |  
| ----------------------- | ----------- | 
| example/Jenkinsfile                       |  |
| example/pr_check_template.sh              |  |
| example/unit_test_example.sh              |  |
| example/unit_test_example_ephemeral_db.sh |  |

## Contributing

Suggested method for testing changes to these scripts:
- Modify `bootstrap.sh` to `git clone` your fork and branch of bonfire.
- Open a PR in a repo using bonfire pr_checks and the relevant scripts, modifying `pr_check` script to clone your fork and branch of bonfire.
- Observe modified scripts running in the relevant CI/CD pipeline.
# 
