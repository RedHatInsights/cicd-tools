# CI/CD Tools

## Description

Utilities used to run smoke tests in an ephemeral environment within a CI/CD pipeline

## Getting Started

Grab the Jenkinsfile template for your [backend](examples/backend-pipeline-pr-checks/Jenkinsfile)
or [frontend](examples/frontends-pipeline-pr-checks/Jenkinsfile) and cater it to your specific
needs. This file should reside in your git repositories root directory. That Jenkinsfile will
download the necessary files from this repository. It does not have a unit test file so that will
need to be made in your repository. You can find a unit test template
file [here](examples/unit_test_example.sh).

## Scripts

| Script                  | Description                                                                                                                                                                                                                                                      |  
|-------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| 
| bootstrap.sh            | Clone bonfire into workspace, setup python venv, modify PATH, login to container registries, login to Kube/OCP,  and set envvars used by following scripts.                                                                                                      |
| build.sh                | Using docker (rhel7) or podman (else) build, tag, and push an image to Quay and Red Hat registries. If its a GitHub or GitLab PR/MR triggered script execution, tag image with `pr-123-SHA` and `pr-123-testing`, else use a short SHA for the target repo HEAD. |
| deploy_ephemeral_db.sh  | Deploy using `bonfire process` and `<oc_wrapper> apply`, removing dependencies and setting up database envvars.                                                                                                                                                  |
| deploy_ephemeral_env.sh | Deploy using `bonfire deploy` into ephemeral, specifying app, component, and relevant image tag args.  Passes `EXTRA_DEPLOY_ARGS` which can be set by the caller via pr_checks.sh.                                                                               |
| cji_smoke_test.sh       | Run iqe-tests container for the relevant app plugin using `bonfire deploy-iqe-cji`. Waits for tests to complete, and fetches artifacts using minio.                                                                                                              |
| post_test_results.sh    | Using artifacts fetched from `cji_smoke_test.sh`, add a GitHub status or GitLab comment linking to the relevant test results in Ibutsu.                                                                                                                          |
| smoke_test.sh           | **DEPRECATED**, use [cji_smoke_test.sh](cji_smoke_test.sh)                                                                                                                                                                                                       |
| iqe_pod                 | **DEPRECATED**, use [cji_smoke_test.sh](cji_smoke_test.sh)                                                                                                                                                                                                       |

## Bash script library usage

The collection of helper libraries are expected to be loaded using the
provided [src/bootstrap.sh](bootstrap) script.

The  [src/bootstrap.sh](/src/bootstrap.sh) script pulls a local copy of this repo and initializes
the loader module, which serves as an entrypoint into the library. The loader module provides
the ` cicd::loader::load_module` functions that enable loading different modules.

See the table below for information on the modules:

| Library ID                                        | Description                                        |
|---------------------------------------------------|----------------------------------------------------|
| [container](docs/cicd_tools/container.md)         | container engine agnostic commands                 |
| [image_builder](docs/cicd_tools/image_builder.md) | Simplify image building process                    |
| [common](docs/cicd_tools/common.md)               | Generic helper functions shared across all modules |
| [log](docs/cicd_tools/log.md)                     | logging tools                                      |
| [loader](docs/cicd_tools/loader.md)               | Module loading functions                           |

### How to use the helper libraries

This library is intended to be used to gather the most common shell scripts used in pipelines in a
centralized way. This should be helpful to reduce the amount of code needed to write the most common
operations in a pipeline for routine tasks, such as operating with containers or building container
images.

The [src/load_module.sh](load_module.sh) script is the main entrypoint and should be used to load
the modules
included in this library. This script requires all the other scripts available in a local directory
following the same structure in this repository.

To use any of the provided libraries, you must source the [src/load_module.sh](load_module.sh)
script and pass the unique library ID to be loaded as a parameter. For example:

```
module_id='container'
source src/load_module.sh "$module_id"


$ cicd::container::cmd --version

podman version 4.7.0
```

There's two different approaches for loading these scripts, depending on if you're a contributor or
an end user.

#### Contributing to the repository

This is the intended way when developing new modules for this library. The recommended approach for
contributing is to create a new fork and then open a pull request against the `main` branch.

When working with a local copy of the repository, you should source
the [src/load_module.sh](load_module.sh)
script directly.

#### Using the library from other scripts

There is an existing helper script named [src/bootstrap.sh](bootstrap) to help with sourcing the
[src/load_module.sh](load_module.sh) script if you're not contributing to this repo.

**This is the intended way of using this library from external projects**.

One can simply either source the [src/bootstrap.sh](bootstrap) script directly:

```
$ source <(curl -sSL https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh) container

$ cicd::container::cmd --version
  podman version 4.6.1

```

Or choose to be more specific and select a specific repository and branch name (useful for working
with forks and testing new WIP features)

The following is a snippet you can use to place on top of a script to load the helper module you
need:

```
load_cicd_helper_functions() {

    local LIBRARY_TO_LOAD="$1"
    local CICD_TOOLS_REPO_BRANCH='main'
    local CICD_TOOLS_REPO_ORG='RedHatInsights'
    local CICD_TOOLS_URL="https://raw.githubusercontent.com/${CICD_TOOLS_REPO_ORG}/cicd-tools/${CICD_TOOLS_REPO_BRANCH}/src/bootstrap.sh"
    source <(curl -sSL "$CICD_TOOLS_URL") "$LIBRARY_TO_LOAD"
}

load_cicd_helper_functions container
```

you can select which collection needs to load independently as a parameter:

```
source bootstrap.sh container
```

The bootstrap script will download the selected version of the CICD scripts (or `latest` if none
specified) into the directory defined by the `CICD_TOOLS_WORKDIR` variable (defaults
to `.cicd_tools` in the current directory).

**Please note** that when cloning the repo, the directory defined by the `CICD_TOOLS_WORKDIR` will
be deleted!
You can disable running the `git clone` by setting the `CICD_TOOLS_SKIP_GIT_CLONE` variable

After loading the requested module the `CICD_TOOLS_WORKDIR` directory will be automatically removed
by the [src/bootstrap.sh](bootstrap) script.

the [src/bootstrap.sh](bootstrap) script can be invoked multiple times, but it has a status control
to ensure each of the libraries is loaded only once. This is to prevent potential issues with
collections that are not supposed to be loaded many times.

An example of this is the _container_ library, where the selected container engine
is **set only once the first command using the library helper function `cicd::container::cmd`
is used**.

Each of the libraries will export their functions and variables to the shell when sourcing the
bootstrap script the helper functions.

This library
follows [Google's Shell style guide](https://google.github.io/styleguide/shellguide.html), and the
functions are all namespaced to its corresponding module, meaning the names follow the naming
format:

```
cicd::library::function
```

where:

- *cicd* represents the namespace root, which is shared by all functions
- *library* would match with each of the imported library IDs.

## Template Scripts

| Script                                            | Description                                                  |  
|---------------------------------------------------|--------------------------------------------------------------| 
| examples/backend-pipeline-pr-checks/Jenkinsfile   | Templated example of the pr-check pipeline for backend apps  |
| examples/frontends-pipeline-pr-checks/Jenkinsfile | Templated example of the pr-check pipeline for frontend apps |
| examples/pr_check_template.sh                     |                                                              |
| examples/unit_test_example.sh                     |                                                              |
| examples/unit_test_example_ephemeral_db.sh        |                                                              |

## Contributing

Suggested method for testing changes to these scripts:

- Modify `bootstrap.sh` to `git clone` your fork and branch of bonfire.
- Open a PR in a repo using bonfire pr_checks and the relevant scripts, modifying `pr_check` script
  to clone your fork and branch of bonfire.
- Observe modified scripts running in the relevant CI/CD pipeline.
