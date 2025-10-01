#!/bin/bash

LOCAL_DIR=$(dirname "$(readlink -f "$0")")

# apt source
bash ${LOCAL_DIR}/apts/basic.sh

# config files
# bash ${LOCAL_DIR}/config_files/apt_source.sh

# debs
bash ${LOCAL_DIR}/debs/desktop.sh

# vscode extensions
bash ${LOCAL_DIR}/others/vscode.sh

# advance
bash ${LOCAL_DIR}/advance/conda.sh
bash ${LOCAL_DIR}/advance/docker.sh
bash ${LOCAL_DIR}/advance/node.sh
