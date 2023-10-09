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

This will build a container image and conditionally push it if not in a change request context using the provided configuration

#### cicd::container::build

This will build a container image using the provided configuration

#### cicd::container::tag

This function will create local tags using the provided configuration

#### cicd::container::push

This function will push all configured tags

## How to use

This module uses the following variables to configure the image building requirements:

| Variable name | Description | Default value | Type | Mandatory |
|CICD_TOOLS_IMAGE_BUILDER_IMAGE_NAME | The Image name to be used, in format: 'imageregistry/org/image_name' | `""` | string | Yes |
|CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG | The main image tag to be used. If not provided the 7 first chars of the current repository's git commit hash will be used instead |`""` | string | No |
|CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS | The additional tags (if any) to be created in array format: ("tag1" "tag2" "latest") | `()` | Array | No|
|CICD_TOOLS_IMAGE_BUILDER_LABELS| The labels (if any) to add to the image being built in array format: ("label1=Value1" "label2=value2") | `()` | Array | No|
|CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS| The build arguments to be provided when building the image (if any) in array format: ("buildarg1=Value1" "buildarg2=value2") | `()` | Array | No|
|CICD_TOOLS_IMAGE_BUILDER_BUILD_CONTEXT| The build context path to use when building the image. | `.` | None | string | No|
|CICD_TOOLS_IMAGE_BUILDER_CONTAINERFILE_PATH| The Containerfile path to use when building the image. | `Dockerfile` | None | string | No|
|CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME| The expire time value to be set for Quay expires labels, used only in change request contexts. | `3d` | string | No|
|CICD_TOOLS_IMAGE_BUILDER_QUAY_USER| The username to use when logging in to Quay. | `$QUAY_USER` | string | No|
|CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD| The password to use when logging in to Quay. | `$QUAY_TOKEN` | string | No|
