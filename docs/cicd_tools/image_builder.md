# Image builder module

This module provides functions to help write scripts simplify the image build process. It does so by
invoking one of the supported container engines found in the user's PATH.

## Definition

The module ID is `image_builder`

All functions exposed by this module will use the namespaced prefix:

```
cicd::image_builder::
```

## Usage

Use the `image_builder` id to load the module

```
CICD_TOOLS_URL="https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh"
# shellcheck source=/dev/null
source <(curl -sSL "$CICD_TOOLS_URL") image_builder
```

This module uses the following variables to configure the image building requirements:

### Configuration variables

The only required variable is `CICD_IMAGE_BUILDER_IMAGE_NAME`, the rest of them are optional
and should not be needed for the majority of use cases as the provided default values should be
enough.

Here are a few examples (considering `abcdef1` is the first 7 chars of the current directory git
HEAD):

```
export CICD_IMAGE_BUILDER_IMAGE_NAME='quay.io/awesome_org/awesome_project'
source <(curl -sSL "$CICD_TOOLS_URL") image_builder

cicd::image_builder::get_full_image_name

# returns quay.io/awesome_org/awesome_project:abcdef1
```

The following is a list of all the configuration variables available with a description and examples

#### CICD_IMAGE_BUILDER_IMAGE_NAME

Type: "string", Default value: ""

Image name to be used, in format: 'imageregistry/org/image_name'. This variable is **mandatory**.
Several functions rely on this variable to work properly.

```shell
export CICD_IMAGE_BUILDER_IMAGE_NAME='quay.io/cloudservices/awesomerepo'

cicd::image_builder::get_full_image_name

# quay.io/cloudservices/awesomerepo:abcdef1
```

### CICD_IMAGE_BUILDER_LOCAL_BUILD

Type: "string", Default value: ""

Force "local build context" mode. The library autodetects the mode based on the environment
variables to decide if on a local build context or not. Some functions change their behavior
depending on whether it's a local build or not.

For example, `cicd::image_builder::build_and_push` will not actually `push` if on local mode. This
is to prevent accidental push events and to facilitate local debugging.

Setting this variable to a non-empty value will force the local mode regardless of the environment
variables present

```shell

export CICD_IMAGE_BUILDER_LOCAL_MODE=1

if cicd::image_builder::local_build then;
    echo "forcing local mode!"
fi
```

### CICD_IMAGE_BUILDER_IMAGE_TAG

Type: "string", Default value: ""

Define a static default tag. If not defined, the 7 first chars of the current repository's git
commit hash will be used instead

```shell

cicd::image_builder::get_image_tag
# prints abcdef1

export CICD_IMAGE_BUILDER_IMAGE_TAG='awesome_tag'
cicd::image_builder::get_image_tag
# prints awesome_tag
```

### CICD_IMAGE_BUILDER_ADDITIONAL_TAGS

Type: "array", Default value: "()"

The additional tags (if any) to be created in array format: ("tag1" "tag2" "latest")

```shell

cicd::image_builder::get_additional_tags
# prints ""

export CICD_IMAGE_BUILDER_ADDITIONAL_TAGS=("apple" "banana" "orange")
cicd::image_builder::get_additional_tags
# prints "apple" "banana" "orange"

export CICD_IMAGE_BUILDER_IMAGE_NAME='quay.io/cloudservices/awesome'
cicd::image_builder::build
# will attempt to build the following tags:
#quay.io/cloudservices/awesome:abcdef1
#quay.io/cloudservices/awesome:apple
#quay.io/cloudservices/awesome:banana
#quay.io/cloudservices/awesome:orange

```

### CICD_IMAGE_BUILDER_LABELS

Type: "array", Default value: "()"

The additional labels (if any) to be created in array format: ("label1=Value1" "label2=value2")

```shell
export CICD_IMAGE_BUILDER_LABELS=("label1=value1" "label2=value2")

cicd::image_builder::build

# will add --label label1=value1 --label2=value2 to the image build command
```

### CICD_IMAGE_BUILDER_BUILD_ARGS

Type: "array", Default value: "()"

The additional labels (if any) to be created in array format: ("buildarg1=Value1" "
buildarg2=value2")

```shell
export CICD_IMAGE_BUILDER_BUILD_ARGS=("buildarg1=value1" "buildarg2=value2")

cicd::image_builder::build

# will add --build-arg buildarg1=value1 --build-arg buildarg2=value2 to the image build command
```

### CICD_IMAGE_BUILDER_BUILD_CONTEXT

Type: "string", Default value: "."

Defines the current build context for when building the container images

```shell
export CICD_IMAGE_BUILDER_BUILD_CONTEXT='./container' 

cicd::image_builder::build

# will try to run the build command using the provided context
# docker build -f Dockerfile ./contaienr
```

### CICD_IMAGE_BUILDER_CONTAINERFILE_PATH

Type: "string", Default value: "Dockerfile"

Defines the containerfiule path to build images.

```shell
export CICD_IMAGE_BUILDER_CONTAINERFILE_PATH='deployment/test.Dockerfile' 

cicd::image_builder::build

# will try to run the build command using the provided containerfile
# docker build -f deployment/test.Dockerfile .
```

### CICD_IMAGE_BUILDER_QUAY_EXPIRE_TIME

Type: "string", Default value: "3d"

Defines the default expiry time for change request images pushed to Quay.

```shell
export CICD_IMAGE_BUILDER_QUAY_EXPIRE_TIME='1h'

# in a change request context, will build using the label: quay.expires-after=1h 
```

### CICD_IMAGE_BUILDER_QUAY_USER

Type: "string", Default value: `$QUAY_USER`

The username used to log in to Quay.io

### CICD_IMAGE_BUILDER_QUAY_PASSWORD

Type: "string", Default value: `$QUAY_TOKEN`

The password used to log in to Quay.io

### CICD_IMAGE_BUILDER_REDHAT_USER

Type: "string", Default value: `$RH_REGISTRY_USER`

The username used to log in to the Red Hat Registry

### CICD_IMAGE_BUILDER_QUAY_PASSWORD

Type: "string", Default value: `$RH_REGISTRY_TOKEN`

The password used to log in to Red Hat Registry

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

## Override the default image tag

If for some reason the "GIT_SHA" default value, the `CICD_IMAGE_BUILDER_IMAGE_TAG` can be used to
override it.
The value of the default tag will still be modified in change requests context though, to include
the `buildID` and the `pr` prefix

Example:

```
export CICD_IMAGE_BUILDER_IMAGE_TAG=awesome-tag
echo $(cicd::image_builder::get_image_tag)
```

Will output the value `awesome-tag` or the `pr-123-awaesome-tag` value for Change Request contexts

## Dependencies

This module depends on the [container](/docs/cicd_tools/container.md) module to build images.

**NOTE**: About logging in against image registries:

This module has a setup phase that creates a unique container config file to handle container
registry credentials

This module will **only** try to authenticate against an image registry if it finds the variables
present in the environment. In addition, in a CI context the `DOCKER_CONFIG` file will be
recreated using a temporary file, so it is expected that the required registry credentials are
provided as environment variables.

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

#### cicd::image_builder::local_build

Whether if the context is considered a local build or not. This is done by evaluating the
environment variables to decide if it's being run in a CI Job. It can be overriden with
the `CICD_IMAGE_BUILDER_LOCAL_BUILD` variable

#### cicd::image_builder::get_containerfile

Returns the Containerfile path that will be used

#### cicd::image_builder::get_build_context

Returns the build context that will be used

#### cicd::image_builder::get_image_tag

Returns the default image tag that will be used based on the current configuration. There are 2
factors that can affect the value returned, whether if it's a CI context, and whether if it's a
change request context. Please refer to the previous
section `Expected Image tags based on the environment` for a reference of the expected tags

#### cicd::image_builder::get_build_id

If on a change request context, returns the build ID (the unique identifier of the change request
ID)

#### cicd::image_builder::get_additional_tags

Returns the list of additional tags to be added when building and pushing an image.

#### cicd::image_builder::get_labels

Returns the list of labels to be applied when building a new image

#### cicd::image_builder::get_build_args

Returns the list of build arguments when building a new image

#### cicd::image_builder::get_full_image_name

Returns the Image name including the default tag in the format

`registry/repository_org/repository_name:default_tag`