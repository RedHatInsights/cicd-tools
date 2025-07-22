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
    """Parses json translation of Konflux component name into bonfire component"""
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
        component_name = component_mapping.get(
            snapshot_component.name,
            bonfire_component_name or snapshot_component.name
        )

        ret.extend((
            "--set-template-ref",
            f"{component_name}={snapshot_component.source.git.revision}",
            "--set-parameter",
            f"{component_name}/IMAGE={snapshot_component.container_image.image}@sha256",
            "--set-parameter",
            f"{component_name}/IMAGE_TAG={snapshot_component.container_image.sha}"
        ))
    print(" ".join(ret))


if __name__ == "__main__":
    main()
