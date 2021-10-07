#!/usr/bin/env bash

shopt -s nullglob
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
sudo apt update
sudo apt install -y bison ca-certificates ccache clang cmake curl file flex gcc g++ git make ninja-build python3 texinfo zlib1g-dev libssl-dev libelf-dev patchelf zstd

git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"

# Build a newer version of CMake to satisfy LLVM's requirements
curl -L https://gitlab.kitware.com/cmake/cmake/-/archive/v3.21.3/cmake-v3.21.3.tar.gz | tar xzf -
pushd cmake-v3.21.3
./bootstrap --parallel="$(nproc)"
make -j"$(nproc)"
sudo make install
popd

# Clone LLVM and apply fixup patches *before* building
git clone --depth 1 "https://github.com/llvm/llvm-project"
if [ -n "$(echo patches/*.patch)" ]; then
    pushd llvm-project
    git apply -3 ../patches/*.patch
    popd
fi

./build-toolchain.sh
