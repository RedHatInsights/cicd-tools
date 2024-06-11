#!/bin/bash

dependencies=(
    "python3.11"
    "python3.11-pip"
    "shadow-utils"
    "tar"
    "gzip"
)

microdnf install -y "${dependencies[@]}"
microdnf clean all

alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1
