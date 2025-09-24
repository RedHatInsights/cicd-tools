#!/usr/bin/env python3

import json
import sys
import urllib.request
import urllib.error
from datetime import datetime
from typing import List, Dict, Any, Optional


def fetch_all_tags(repo_path: str) -> List[Dict[str, Any]]:
    """
    Fetch all tags from Quay.io repository using paginated API.

    Args:
        repo_path: Repository path like 'redhat-user-workloads/hcm-eng-prod-tenant/cicd-tools/cicd-tools'

    Returns:
        List of tag objects with name and metadata
    """
    base_url = f"https://quay.io/api/v1/repository/{repo_path}/tag/"
    all_tags = []
    page = 1

    while True:
        try:
            url = f"{base_url}?page={page}"
            with urllib.request.urlopen(url) as response:
                data = json.loads(response.read().decode())

            # Store full tag objects to access timestamps
            all_tags.extend(data.get('tags', []))

            # Check if there are more pages
            if not data.get('has_additional', False):
                break

            page += 1

        except urllib.error.URLError as e:
            print(f"Error fetching tags: {e}", file=sys.stderr)
            return []
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON: {e}", file=sys.stderr)
            return []

    return all_tags


def find_latest_on_push_tag(tags: List[Dict[str, Any]]) -> str:
    """
    Find the most recent tag containing 'on-push' based on last_modified date.

    Args:
        tags: List of tag objects

    Returns:
        Most recent 'on-push' tag or 'latest' if none found
    """
    on_push_tags = [tag for tag in tags if 'on-push' in tag.get('name', '').lower()]

    if not on_push_tags:
        return 'latest'

    # Sort by last_modified date (most recent first)
    latest_tag = max(on_push_tags, key=lambda tag: tag.get('last_modified', ''))
    return latest_tag.get('name', 'latest')


def main():
    repo_path = "redhat-user-workloads/hcm-eng-prod-tenant/cicd-tools/cicd-tools"

    try:
        all_tags = fetch_all_tags(repo_path)
        if not all_tags:
            print("latest")
            sys.exit(1)

        latest_tag = find_latest_on_push_tag(all_tags)
        print(latest_tag)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        print("latest")
        sys.exit(1)


if __name__ == "__main__":
    main()