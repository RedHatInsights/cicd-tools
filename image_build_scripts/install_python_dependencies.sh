#!/bin/bash

dependencies=(
    "awscli==1.29.28"
    "crc-bonfire"
    "pydantic"
)

pip3 install --user "${dependencies[@]}"
