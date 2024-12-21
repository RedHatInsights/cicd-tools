#!/usr/bin/env python3

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

class BonfireComponents(BaseModel):
    model_config = ConfigDict(frozen=True)

    name: str
    bonfire_component: str


def parse_bonfire_components(bonfire_components_str):
    """Parses json translation of Konflux component name into bonfire component"""
    bonfire_components = {}
    if bonfire_comp_str is not None:
        bonfire_comps: BonfireComponents = BonfireComponents.model_validate_json(bonfire_components_str)
        for bf_comp in bonfire_comps:
            bonfire_components[bf_comp.name] = bf_comp.bonfire_component
    return bonfire_components

def main() -> None:
    snapshot_str = os.environ.get("SNAPSHOT")
    if snapshot_str is None:
        raise RuntimeError("SNAPSHOT environment variable wasn't declared or empty")
    snapshot: Snapshot = Snapshot.model_validate_json(snapshot_str)
    bonfire_components = parse_bonfire_components(os.environ.get('BONFIRE_COMPONENTS'))
    ret = []

    for component in snapshot.components:
        component_name = bonfire_components[component.name] or component.name
        ret.extend((
            "--set-template-ref",
            f"{component_name}={component.source.git.revision}",
            "--set-parameter",
            f"{component_name}/IMAGE={component.container_image.image}@sha256",
            "--set-parameter",
            f"{component_name}/IMAGE_TAG={component.container_image.sha}"
        ))
    print(" ".join(ret))


if __name__ == "__main__":
    main()
