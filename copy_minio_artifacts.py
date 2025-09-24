#!/usr/bin/env python3

import os
import sys
import argparse
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import ClientError, NoCredentialsError
except ImportError:
    print("ERROR: boto3 is required. Install with: pip install boto3", file=sys.stderr)
    sys.exit(1)


def setup_s3_client(endpoint_url, access_key, secret_key):
    """Setup S3 client with minio credentials"""
    try:
        client = boto3.client(
            "s3",
            endpoint_url=endpoint_url,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name="us-east-1",  # Default region for minio
        )
        return client
    except NoCredentialsError:
        print("ERROR: Invalid credentials provided", file=sys.stderr)
        return None


def list_objects(s3_client, bucket_name, prefix=""):
    """List all objects in the bucket with given prefix"""
    try:
        paginator = s3_client.get_paginator("list_objects_v2")
        pages = paginator.paginate(Bucket=bucket_name, Prefix=prefix)

        objects = []
        for page in pages:
            if "Contents" in page:
                objects.extend(page["Contents"])
        return objects
    except ClientError as e:
        print(
            f"ERROR: Failed to list objects in bucket {bucket_name}: {e}",
            file=sys.stderr,
        )
        return None


def download_object(s3_client, bucket_name, object_key, local_path):
    """Download a single object from S3 to local path"""
    try:
        # Ensure local directory exists
        local_dir = os.path.dirname(local_path)
        if local_dir:
            Path(local_dir).mkdir(parents=True, exist_ok=True)

        s3_client.download_file(bucket_name, object_key, local_path)
        return True
    except ClientError as e:
        print(f"ERROR: Failed to download {object_key}: {e}", file=sys.stderr)
        return False


def mirror_bucket(s3_client, bucket_name, local_dir, prefix=""):
    """Mirror S3 bucket contents to local directory (equivalent to mc mirror)"""
    objects = list_objects(s3_client, bucket_name, prefix)
    if objects is None:
        return False

    success_count = 0
    total_count = len(objects)

    for obj in objects:
        object_key = obj["Key"]

        # Remove prefix from object key to get relative path
        if prefix and object_key.startswith(prefix):
            relative_path = object_key[len(prefix) :].lstrip("/")
        else:
            relative_path = object_key

        # Skip if it's just a directory marker
        if relative_path.endswith("/") or not relative_path:
            continue

        local_path = os.path.join(local_dir, relative_path)

        if download_object(s3_client, bucket_name, object_key, local_path):
            success_count += 1
            print(f"Downloaded: {object_key} -> {local_path}")
        else:
            print(f"FAILED: {object_key}")

    print(f"Downloaded {success_count}/{total_count} objects")
    return success_count == total_count


def main():
    parser = argparse.ArgumentParser(
        description="Copy artifacts from minio bucket to local directory"
    )
    parser.add_argument("--endpoint", required=True, help="Minio endpoint URL")
    parser.add_argument("--access-key", required=True, help="Minio access key")
    parser.add_argument("--secret-key", required=True, help="Minio secret key")
    parser.add_argument("--bucket", required=True, help="Bucket name")
    parser.add_argument(
        "--local-dir", required=True, help="Local directory to copy files to"
    )
    parser.add_argument(
        "--prefix", default="", help="Object key prefix to filter objects"
    )

    args = parser.parse_args()

    # Setup S3 client
    s3_client = setup_s3_client(args.endpoint, args.access_key, args.secret_key)
    if not s3_client:
        sys.exit(1)

    # Ensure local directory exists
    Path(args.local_dir).mkdir(parents=True, exist_ok=True)

    # Mirror the bucket
    if mirror_bucket(s3_client, args.bucket, args.local_dir, args.prefix):
        print("Successfully copied all artifacts")
        sys.exit(0)
    else:
        print("ERROR: Failed to copy some artifacts")
        sys.exit(1)


if __name__ == "__main__":
    main()
