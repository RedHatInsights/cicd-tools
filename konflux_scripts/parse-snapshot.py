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


class BonfireComponent(BaseModel):
    model_config = ConfigDict(frozen=True)

    name: str
    bonfire_component: str


def parse_bonfire_components(bonfire_components_str):
    """Parses json translation of Konflux component name into bonfire component"""
    bonfire_components = {}
    if bonfire_components_str:
        components_list = json.loads(bonfire_components_str)
        bonfire_comps = [BonfireComponent.model_validate(comp) for comp in components_list]
        for bf_comp in bonfire_comps:
            bonfire_components[bf_comp.name] = bf_comp.bonfire_component
    return bonfire_components


def main() -> None:
    snapshot_str = os.environ.get("SNAPSHOT")
    if snapshot_str is None:
        raise RuntimeError("SNAPSHOT environment variable wasn't declared or empty")
    snapshot: Snapshot = Snapshot.model_validate_json(snapshot_str)
    bonfire_components = parse_bonfire_components(os.environ.get('BONFIRE_COMPONENTS'))
    # BONFIRE_COMPONENT_NAME is deprecated, left here for backward compatibility
    bonfire_component_name = os.environ.get('BONFIRE_COMPONENT_NAME')
    ret = []

    for snapshot_component in snapshot.components:
        # check if the snapshot component name has a mapping defined in BONFIRE_COMPONENTS
        # ... if not, check if BONFIRE_COMPONENT_NAME is set
        # ... if not, just use the snapshot component name
        component_name = bonfire_components.get(
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
