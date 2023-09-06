#!/usr/bin/env python3

import json
import select
import sys
from textwrap import dedent


def main() -> None:
    rlist, _, _ = select.select([sys.stdin], [], [], 0)
    if not rlist:
        raise RuntimeError("No was provided to STDIN")
    cji = json.load(rlist[0])
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
            All jobs completed: {job_map}   
        """
    ))


if __name__ == "__main__":
    main()
