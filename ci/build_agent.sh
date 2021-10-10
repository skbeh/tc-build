#!/usr/bin/env bash

shopt -s nullglob
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
sudo apt update
sudo apt install -y bison ca-certificates ccache cmake curl file flex gcc git make ninja-build python3 texinfo zlib1g-dev libssl-dev libelf-dev patchelf zstd eatmydata

git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"

# Clone LLVM and apply fixup patches *before* building
git clone --depth 1 "https://github.com/llvm/llvm-project"
if [ -n "$(echo patches/*.patch)" ]; then
    pushd llvm-project
    git apply -3 ../patches/*.patch
    popd
fi

eatmydata ./build-toolchain.sh
