#!/usr/bin/env bash

REPO_DIR=https://raw.githubusercontent.com/RexWzh/QuickSetup-Ubuntu/main/scripts

# apt source
curl -sL ${REPO_DIR}/apts/basic.sh | bash

# config files
# curl -sL ${REPO_DIR}/config/apt_source.sh | bash
# curl -sL ${REPO_DIR}/config/docker-config.sh | bash

# debs
curl -sL ${REPO_DIR}/debs/desktop.sh | bash

# vscode extensions
curl -sL ${REPO_DIR}/others/vscode.sh | bash

# advance
curl -sL ${REPO_DIR}/advance/conda.sh | bash
curl -sL ${REPO_DIR}/advance/docker.sh | bash
curl -sL ${REPO_DIR}/advance/node.sh | bash
# curl -sL ${REPO_DIR}/advance/oh-my-zsh.sh | bash
