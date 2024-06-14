#!/bin/bash

CONDA_ENVS_FILES="${CONDA_ENVS_FILES:-./envs}"

# Find all .yml files in the specified directory and create conda environments from them
for env_file in $(ls -1 "$CONDA_ENVS_FILES" | grep -v "base"); do
    echo "Creating conda environment from $env_file"
    conda env create -f "$CONDA_ENVS_FILES/$env_file"

    # Save the env path to a environment variable
    env_name=$(basename "$env_file" .yml)
done