#!/usr/bin/env bash

set -eo pipefail

args=()

case "$1" in
    -s)
        args+=(--build-stage "$2")
        if [ "$2" -ge 2 ]; then
            args+=(--incremental)
        fi
        if [ "$2" -eq 3 ]; then
            args+=(--pgo kernel-defconfig)
        fi
        ;;
    '')
        args+=(--pgo kernel-defconfig)
        ;;
    *)
        echo "$(basename "$0"):usage: [-s build_stage]"
        exit 1
        ;;
esac

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$*\e[0m"
}

CMAKE_C_FLAGS='-pipe -O3 -mllvm -polly -mllvm -polly-vectorizer=stripmine -fno-semantic-interposition -fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math -fno-plt -fno-stack-protector -march=x86-64-v3'
cmake_flags=(CMAKE_C_FLAGS="$CMAKE_C_FLAGS" CMAKE_CXX_FLAGS="$CMAKE_C_FLAGS")

# Don't touch repo if running on CI
[ -z "$GITHUB_RUN_ID" ] && args+=(--shallow-clone) || args+=(--no-update) && cmake_flags+=("LLVM_PARALLEL_LINK_JOBS=1")

# Build LLVM
msg "Building LLVM..."
./build-llvm.py --targets 'AArch64;X86' \
    --lto full \
    --no-ccache \
    -D "${cmake_flags[@]}" \
    -b release/13.x \
    "${args[@]}"

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
if [ -z "$1" ] || [ "$1" == 3 ]; then
    tar --zstd -cf clang.tar.zst install
fi
