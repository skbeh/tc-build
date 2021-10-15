#!/usr/bin/env bash

set -eo pipefail

# Function to show an informational message
function msg() {
    # shellcheck disable=SC2145
    echo -e "\e[1;32m$@\e[0m"
}

# Don't touch repo if running on CI
[ -z "$GITHUB_RUN_ID" ] && repo_flag="--shallow-clone" || repo_flag="--no-update"

# Build LLVM
msg "Building LLVM..."
CMAKE_C_FLAGS='-pipe -O3 -mllvm -polly -mllvm -polly-vectorizer=stripmine'
./build-llvm.py \
    --targets "AArch64;X86" \
    "$repo_flag" \
    --pgo kernel-defconfig \
    --lto full \
    --no-ccache \
    -D CMAKE_C_FLAGS="$CMAKE_C_FLAGS" CMAKE_CXX_FLAGS="$CMAKE_C_FLAGS"

# Build binutils
msg "Building binutils..."
./build-binutils.py --targets aarch64 x86_64

# Remove unused products
msg "Removing unused products..."
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
    llvm-strip "${f::-1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
msg "Setting library load paths for portability..."
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
    # Remove last character from file output (':')
    bin="${bin::-1}"

    echo "$bin"
    # shellcheck disable=SC2016
    patchelf --set-rpath '$ORIGIN/../lib' "$bin"
done

tar --zstd -cf clang.tar.zst install
