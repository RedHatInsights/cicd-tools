#!/usr/bin/env python3

import json
import os
from typing import Mapping
from textwrap import dedent


def main() -> None:
    snapshot_str = os.environ.get("SNAPSHOT")
    if snapshot_str is None:
        raise RuntimeError("SNAPSHOT environment variable wasn't declared or empty")
    snapshot: Mapping = json.loads(snapshot_str)
    components = snapshot.get("components")
    if not components:
        raise RuntimeError(f"No components found in SNAPSHOT: ${snapshot}")
    if len(components) > 1:
        raise RuntimeError(
            f"Can't handle snapshot that has more than 1 component. Got SNAPSHOT: ${snapshot}"
        )

    image, sha = components[0]["containerImage"].split("@sha256")
    git_revision = components[0]["source"]["git"]["revision"]

    print(dedent(
        f"""
        export IMAGE={image} IMAGE_TAG={sha} GIT_COMMIT={git_revision}
        """
    ))


if __name__ == "__main__":
    main()
