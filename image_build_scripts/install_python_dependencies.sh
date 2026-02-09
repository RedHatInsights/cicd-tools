#!/bin/bash
set -e

dependencies=(
    "awscli==1.29.28"
    "crc-bonfire>=6.8.1"
    "pydantic"
)

python3 -m venv ${PYTHON_VENV}

$PYTHON_VENV/bin/pip install --upgrade pip setuptools wheel "${dependencies[@]}"
