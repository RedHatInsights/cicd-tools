#!/bin/bash

dependencies=(
    "pydantic"
    "crc-bonfire"
)

pip3 install --user "${dependencies[@]}"
