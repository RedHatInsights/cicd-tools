# Image builder module

This module provides functions to help write scripts simplify the image build process. It does so by
invoking one of the supported container engines found in the user's PATH.

## Definition

The module ID is `image_builder`

All functions exposed by this module will use the namespaced prefix:

```
cicd::image_builder::
```

### Public functions

#### cicd::container::build_and_push

This will build a container image and conditionally push it if not in a change request context using
the provided configuration

#### cicd::container::build

This will build a container image using the provided configuration

#### cicd::container::tag

This function will create local tags using the provided configuration

#### cicd::container::push

This function will push all configured tags

## How to use

This module uses the following variables to configure the image building requirements:

| Variable name                               | Description                                                                                                                       | Default value        | Type   | Mandatory |
|---------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|----------------------|--------|-----------|
| CICD_TOOLS_IMAGE_BUILDER_IMAGE_NAME         | The Image name to be used, in format: 'imageregistry/org/image_name'                                                              | `""`                 | string | Yes       |
| CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG          | The main image tag to be used. If not provided the 7 first chars of the current repository's git commit hash will be used instead | `""`                 | string | No        |
| CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS    | The additional tags (if any) to be created in array format: ("tag1" "tag2" "latest")                                              | `()`                 | Array  | No        |
| CICD_TOOLS_IMAGE_BUILDER_LABELS             | The labels (if any) to add to the image being built in array format: ("label1=Value1" "label2=value2")                            | `()`                 | Array  | No        |
| CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS         | The build arguments to be provided when building the image (if any) in array format: ("buildarg1=Value1" "buildarg2=value2")      | `()`                 | Array  | No        |
| CICD_TOOLS_IMAGE_BUILDER_BUILD_CONTEXT      | The build context path to use when building the image.                                                                            | `.`                  | None   | string    | No|
| CICD_TOOLS_IMAGE_BUILDER_CONTAINERFILE_PATH | The Containerfile path to use when building the image.                                                                            | `Dockerfile`         | None   | string    | No|
| CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME   | The expire time value to be set for Quay expires labels, used only in change request contexts.                                    | `3d`                 | string | No        |
| CICD_TOOLS_IMAGE_BUILDER_QUAY_USER          | The username to use when logging in to Quay.io                                                                                    | `$QUAY_USER`         | string | No        |
| CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD      | The password to use when logging in to Quay.io                                                                                    | `$QUAY_TOKEN`        | string | No        |
| CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER        | The username to use when logging in to the Red Hat Registry                                                                       | `$RH_REGISTRY_USER`  | string | No        |
| CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD    | The password to use when logging in to the Red Hat Registry                                                                       | `$RH_REGISTRY_TOKEN` | string | No        |

The only required variable is `CICD_TOOLS_IMAGE_BUILDER_IMAGE_NAME`, the rest of them are optional
and should not be needed for the majority of use cases as the provided default values should be
enough.

It is important to consider that the behavior of the different image builder functions may be
affected by the context where it runs.
The context include a CI context (for example, while running in a pipeline), and running in a Change
Request (a Pull Request pipeline for a project hosted in Github or a Merge Request pipeline for a
project hosted in Gitlab).

## Expected Image tags based on the environment

The following table has examples of the different combinations of the variables and tags that are
expected to be created, considering if:

- In a Change Request context (A pull request or Merge request pipeline)
- A default Image Tag is specified
- Additional tags are specified

| CR context | Image tag   | Additional tags     | Tags created                                                           |
|------------|-------------|---------------------|------------------------------------------------------------------------|
| NO         | N/A         | N/A                 | `${GIT_SHA}`                                                           |
| NO         | N/A         | `("tag1" "latest")` | `${GIT_SHA} tag1 latest`                                               |
| NO         | awesome-tag | N/A                 | `awesome-tag`                                                          |
| NO         | awesome-tag | `("tag1" "latest")` | `awesome-tag tag1 latest`                                              |
| YES        | N/A         | N/A                 | `pr-${BUILD_ID}-${GIT_SHA}`                                            |
| YES        | N/A         | `("tag1" "latest")` | `pr-${BUILD_ID}-GIT_SHA pr-${BUILD_ID}-tag1 pr-${BUILD_ID}-latest`     |
| YES        | awesome-tag | N/A                 | `pr-${BUILD_ID}-awesome-tag`                                           |
| YES        | awesome-tag | `("tag1" "latest")` | `pr-${BUILD_ID}-awesome-tag pr-${BUILD_ID}-tag1 pr-${BUILD_ID}-latest` |

**Important:** This module will **only** try to authenticate against either registry if it finds the
variables present in the environment. In addition, in a CI context the `DOCKER_CONFIG` file will be
recreated using a temporary file, so it is expected that the required registry credentials are
provided as environment variables.


