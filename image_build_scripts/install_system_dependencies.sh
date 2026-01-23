#!/bin/bash
set -e

dependencies=(
    "python3.12"
    "python3.12-pip"
    "shadow-utils"
    "tar"
    "gzip"
    "jq"
)

microdnf install -y "${dependencies[@]}"
microdnf clean all

alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.12 1
