#!/usr/bin/env bash

set -euo pipefail

cmake_c_flags=(-pipe -O3 -mllvm -polly -mllvm -polly-vectorizer=stripmine -fno-semantic-interposition -fno-signed-zeros -fno-trapping-math -fassociative-math -freciprocal-math -fno-plt -fno-stack-protector)
args=()
mcpu=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s)
            build_stage="$2"
            args+=(--build-stage "$build_stage")
            if [ "$build_stage" -ge 2 ]; then
                args+=(--incremental)
            fi
            shift
            shift
            ;;
        -c)
            mcpu=(-march="$2" -mtune="$2")
            shift
            shift
            ;;
        -i)
            args+=(--incremental)
            shift
            ;;
        -p)
            args+=(--pgo kernel-defconfig llvm)
            shift
            ;;
        '')
            args+=(--pgo kernel-defconfig llvm)
            shift
            shift
            ;;
        *)
            echo "$(basename "$0"):usage: [-s build_stage] [-c mcpu] [-i incremental]"
            exit 1
            ;;
    esac
done

[ -z "${build_stage:-}" ] && build_stage=''
[ ${#mcpu[@]} -eq 0 ] && cmake_c_flags+=(-march=x86-64-v3) || cmake_c_flags+=("${mcpu[@]}")

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$*\e[0m"
}

cmake_flags=(CMAKE_C_FLAGS="${cmake_c_flags[*]}" CMAKE_CXX_FLAGS="${cmake_c_flags[*]}")

# Don't touch repo if running on CI
if [ -z "${GITHUB_RUN_ID:-}" ]; then
    args+=(--shallow-clone)
else
    args+=(--no-update)
fi

# Build LLVM
msg "Building LLVM..."
./build-llvm.py --targets 'AArch64;ARM;BPF;X86' \
    --lto thin \
    --no-ccache \
    -D "${cmake_flags[@]}" \
    -b 'llvmorg-13.0.0' \
    "${args[@]}"

# Build binutils
msg "Building binutils..."
./build-binutils.py --targets aarch64 x86_64 -m native

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
if [ -n "${GITHUB_RUN_ID:-}" ] && [ "$build_stage" -eq 3 ]; then
    tar --zstd -cf clang.tar.zst install
fi
