"""You can test this script with:

A. Single component mapping:

export SNAPSHOT='{
    "application": "my-app",
    "components": [
    {
        "name": "konflux-component1",
        "containerImage": "quay.io/org/img1@sha256:abc123",
        "source": {
            "git": {
                "url": "https://git.example.com/repo1",
                "revision": "v1.0"
            }
        }
    },
    {
        "name": "konflux-component2",
        "containerImage": "quay.io/org/img2@sha256:abc456",
        "source": {
            "git": {
                "url": "https://git.example.com/repo2",
                "revision": "v2.0"
            }
        }
    }
    ]
}'
export BONFIRE_COMPONENTS_MAPPING='{"konflux-component1": "app-interface-component1"}'
python parse-snapshot.py

B. Multiple component mapping:

export SNAPSHOT='{
    "application": "my-app",
    "components": [
    {
        "name": "konflux-component1",
        "containerImage": "quay.io/org/img1@sha256:abc123",
        "source": {
            "git": {
                "url": "https://git.example.com/repo1",
                "revision": "v1.0"
            }
        }
    },
    {
        "name": "konflux-component2",
        "containerImage": "quay.io/org/img2@sha256:abc456",
        "source": {
            "git": {
                "url": "https://git.example.com/repo2",
                "revision": "v2.0"
            }
        }
    }
    ]
}'
export BONFIRE_COMPONENTS_MAPPING='{"konflux-component1": "app-interface-component1", "konflux-component2": "app-interface-component2"}'
python parse-snapshot.py

C. Konflux component mapping with multiple app-interface components:

export SNAPSHOT='{
    "application": "my-app",
    "components": [
    {
        "name": "konflux-component1",
        "containerImage": "quay.io/org/img1@sha256:abc123",
        "source": {
            "git": {
                "url": "https://git.example.com/repo1",
                "revision": "v1.0"
            }
        }
    },
    {
        "name": "konflux-component2",
        "containerImage": "quay.io/org/img2@sha256:abc456",
        "source": {
            "git": {
                "url": "https://git.example.com/repo2",
                "revision": "v2.0"
            }
        }
    }
    ]
}'
export BONFIRE_COMPONENTS_MAPPING='{"konflux-component1": ["app-interface-component1", "app-interface-component2"]}'
python parse-snapshot.py
"""

#!/usr/bin/env python3

import json
import os
from typing import Any, MutableMapping

from pydantic import BaseModel, ConfigDict, AnyUrl, Field, model_validator


class Git(BaseModel):
    model_config = ConfigDict(frozen=True)

    url: AnyUrl
    revision: str


class Source(BaseModel):
    model_config = ConfigDict(frozen=True)

    git: Git


class ContainerImage(BaseModel):
    model_config = ConfigDict(frozen=True)

    image: str
    sha: str


class Component(BaseModel):
    model_config = ConfigDict(frozen=True)

    name: str
    container_image: ContainerImage = Field(alias="containerImage")
    source: Source

    @model_validator(mode='before')
    @classmethod
    def container_image_validator(cls, data: Any) -> Any:
        if not isinstance(data, MutableMapping):
            raise ValueError(f"{data} is not of mapping type")

        image, sha = data["containerImage"].split("@sha256:")
        data["containerImage"] = ContainerImage(image=image, sha=sha)
        return data


class Snapshot(BaseModel):
    model_config = ConfigDict(frozen=True)

    application: str
    components: list[Component]


def parse_component_mapping(mapping_str):
    """Parses json translation of Konflux component name into bonfire component(s).

    Values may be a single string or a list of strings (one Konflux component → many app-interface components).
    For example:
    - {'{"konflux_component1": "app_interface_component1", "konflux_component2": "app_interface_component2"}'}
    - {'{"konflux_component1": "app_interface_component1", "konflux_component2": ["app_interface_component2", "app_interface_component3"]}'}
    """
    mapping = {}
    if mapping_str:
         mapping = json.loads(mapping_str)
    return mapping


def main() -> None:
    snapshot_str = os.environ.get("SNAPSHOT")
    if snapshot_str is None:
        raise RuntimeError("SNAPSHOT environment variable wasn't declared or empty")
    snapshot: Snapshot = Snapshot.model_validate_json(snapshot_str)
    component_mapping = parse_component_mapping(os.environ.get('BONFIRE_COMPONENTS_MAPPING'))
    # BONFIRE_COMPONENT_NAME is deprecated, left here for backward compatibility
    bonfire_component_name = os.environ.get('BONFIRE_COMPONENT_NAME')
    ret = []

    for snapshot_component in snapshot.components:
        # check if the snapshot component name has a mapping defined in BONFIRE_COMPONENTS
        # ... if not, check if BONFIRE_COMPONENT_NAME is set
        # ... if not, just use the snapshot component name
        component_names: str | list[str] = component_mapping.get(
            snapshot_component.name,
            bonfire_component_name or snapshot_component.name
        )

        if isinstance(component_names, str):
            _add_component_to_params(ret, component_names, snapshot_component)
        elif isinstance(component_names, list):
            for component_name in component_names:
                _add_component_to_params(ret, component_name, snapshot_component)
        else:
            raise ValueError(f"Invalid component mapping: {component_mapping}. Expected a string or a list of strings.")
    print(" ".join(ret))

def _add_component_to_params(params: list[str], component_name: str, snapshot_component: Component) -> None:
    params.extend((
        "--set-template-ref",
        f"{component_name}={snapshot_component.source.git.revision}",
        "--set-parameter",
        f"{component_name}/IMAGE={snapshot_component.container_image.image}@sha256",
        "--set-parameter",
        f"{component_name}/IMAGE_TAG={snapshot_component.container_image.sha}"
    ))

if __name__ == "__main__":
    main()
