#!/usr/bin/env bash
# Build ZMK firmware for the targets in build.yaml.
#
# Usage: scripts/build.sh [artifact-name ...]
#   No arguments builds every target. Names come from build.yaml artifact-name.
#
# First run creates the west workspace at ../zmk-halcyon-ws (override with ZMK_WS):
#   .venv with Python 3.12 and west, a manifest repo, zmk + modules, the Zephyr SDK.
# Every run builds against this working tree: ZMK_CONFIG=<repo>/config and the repo
# itself as an extra Zephyr module. Outputs land in <repo>/firmware/<name>.uf2.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="${ZMK_WS:-$(dirname "$REPO")/zmk-halcyon-ws}"
SDK_VER="0.17.0"
SDK_DIR="$WS/zephyr-sdk-$SDK_VER"
VENV="$WS/.venv"
PY_VER="3.12"

log() { printf '\n==> %s\n' "$*"; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing tool: $1" >&2; exit 1; }; }
need uv; need git; need cmake; need ninja; need dtc; need curl; need tar; need xz

bootstrap() {
    mkdir -p "$WS"
    cd "$WS"

    if [ ! -x "$VENV/bin/python" ]; then
        log "Creating Python $PY_VER venv in $VENV"
        uv venv --python "$PY_VER" "$VENV"
        uv pip install --python "$VENV/bin/python" west pyyaml
    fi
    export PATH="$VENV/bin:$PATH"

    if [ ! -d "$WS/.west" ]; then
        log "Writing manifest repo from $REPO/config/west.yml"
        mkdir -p manifest
        sed 's/^\(\s*\)path: config$/\1path: manifest/' "$REPO/config/west.yml" > manifest/west.yml
        grep -q "path: manifest" manifest/west.yml || { echo "manifest self.path rewrite failed" >&2; exit 1; }
        if [ ! -d manifest/.git ]; then
            git -C manifest init -q
            git -C manifest add west.yml
            git -C manifest -c user.name=build -c user.email=build@local commit -q -m "manifest"
        fi
        log "west init"
        west init -l manifest
    fi

    if [ ! -d "$WS/zmk/app" ]; then
        log "west update (clones zmk, zephyr, modules; takes a while)"
        west update
        west zephyr-export
        uv pip install --python "$VENV/bin/python" -r "$WS/zephyr/scripts/requirements.txt"
        # nanopb generates the ZMK Studio protobuf sources; it needs grpcio-tools.
        uv pip install --python "$VENV/bin/python" -r "$WS/modules/lib/nanopb/extra/requirements.txt"
    fi

    if [ ! -x "$SDK_DIR/arm-zephyr-eabi/bin/arm-zephyr-eabi-gcc" ]; then
        log "Installing Zephyr SDK $SDK_VER (minimal bundle + arm toolchain)"
        local tarball="zephyr-sdk-${SDK_VER}_linux-x86_64_minimal.tar.xz"
        curl -L -o "$WS/$tarball" \
            "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${SDK_VER}/${tarball}"
        tar -xf "$WS/$tarball" -C "$WS"
        rm -f "$WS/$tarball"
        (cd "$SDK_DIR" && ./setup.sh -t arm-zephyr-eabi -h -c)
    fi
}

build_one() {
    local name="$1" board="$2" shield="$3" snippet="$4" cmake_args="$5"
    local extra=()
    [ -n "$snippet" ] && extra+=(-S "$snippet")
    log "Building $name: board=$board shield='$shield' snippet='$snippet' cmake-args='$cmake_args'"
    cd "$WS"
    # shellcheck disable=SC2086
    west build -s zmk/app -d "build/$name" -b "$board" -p auto "${extra[@]}" -- \
        -DSHIELD="$shield" \
        -DZMK_CONFIG="$REPO/config" \
        -DZMK_EXTRA_MODULES="$REPO" \
        $cmake_args
    mkdir -p "$REPO/firmware"
    cp "build/$name/zephyr/zmk.uf2" "$REPO/firmware/$name.uf2"
    log "Wrote firmware/$name.uf2"
}

bootstrap
export PATH="$VENV/bin:$PATH"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR="$SDK_DIR"

wanted=("$@")
built=0
while IFS=$'\t' read -r name board shield snippet cmake_args; do
    if [ "${#wanted[@]}" -gt 0 ]; then
        keep=0
        for w in "${wanted[@]}"; do [ "$w" = "$name" ] && keep=1; done
        [ "$keep" -eq 1 ] || continue
    fi
    build_one "$name" "$board" "$shield" "$snippet" "$cmake_args"
    built=$((built + 1))
done < <("$VENV/bin/python" "$REPO/scripts/targets.py" "$REPO/build.yaml")

[ "$built" -gt 0 ] || { echo "no target matched: ${wanted[*]}" >&2; exit 1; }
log "Done. Firmware in $REPO/firmware/"
