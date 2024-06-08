#!/bin/bash

dependencies=(
    "python3.11"
    "python3-pip"
    "shadow-utils"
    "tar"
    "gzip"
)

microdnf install -y "${dependencies[@]}"
microdnf clean all
