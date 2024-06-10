#!/usr/bin/env python3

import json
import sys
from textwrap import dedent


def main() -> None:
    cji = json.load(sys.stdin)
    job_map: dict = cji["status"]["jobMap"]
    if not all(v == "Complete" for v in job_map.values()):
        print(dedent(
            f"""
            Some jobs failed: {job_map}
            """
        ))
        sys.exit(1)

    print(dedent(
        f"""
            All jobs succeeded: {job_map}   
        """
    ))


if __name__ == "__main__":
    main()
