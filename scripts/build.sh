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
#
# Note: `-p auto` does not notice a changed shield list or cmake args in build.yaml.
# After you change a target line, delete ../zmk-halcyon-ws/build/<name> before you build.
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
need sha256sum

bootstrap() {
    mkdir -p "$WS"
    cd "$WS"

    # Each stage writes its stamp only after every command in the stage is done.
    # A stage that stops in the middle thus runs again on the next start.
    if [ ! -f "$WS/.stamp-venv" ]; then
        log "Creating Python $PY_VER venv in $VENV"
        # --clear replaces a venv that a stopped run left in a half-made state.
        uv venv --clear --python "$PY_VER" "$VENV"
        uv pip install --python "$VENV/bin/python" west pyyaml
        # A new venv has no Zephyr or nanopb requirements. Make them again.
        rm -f "$WS/.stamp-deps"
        touch "$WS/.stamp-venv"
    fi
    export PATH="$VENV/bin:$PATH"

    # Make the manifest again on every start, because config/west.yml can change.
    log "Writing manifest repo from $REPO/config/west.yml"
    mkdir -p manifest
    sed 's/^\(\s*\)path: config$/\1path: manifest/' "$REPO/config/west.yml" > manifest/west.yml
    grep -q "path: manifest" manifest/west.yml || { echo "manifest self.path rewrite failed" >&2; exit 1; }
    [ -d manifest/.git ] || git -C manifest init -q
    if [ -n "$(git -C manifest status --porcelain)" ]; then
        log "Manifest changed; committing it and making the dependencies again"
        git -C manifest add west.yml
        git -C manifest -c user.name=build -c user.email=build@local commit -q -m "manifest"
        rm -f "$WS/.stamp-deps"
    fi

    if [ ! -d "$WS/.west" ]; then
        log "west init"
        west init -l manifest
    fi

    if [ ! -f "$WS/.stamp-deps" ]; then
        log "west update (clones zmk, zephyr, modules; takes a while)"
        west update
        west zephyr-export
        uv pip install --python "$VENV/bin/python" -r "$WS/zephyr/scripts/requirements.txt"
        # nanopb makes the ZMK Studio protobuf sources; it needs grpcio-tools.
        uv pip install --python "$VENV/bin/python" -r "$WS/modules/lib/nanopb/extra/requirements.txt"
        # No build directory must stay longer than the dependency set that made it.
        rm -rf "$WS/build"
        touch "$WS/.stamp-deps"
    fi

    # The gcc binary is the last file the SDK setup writes, thus it is a good guard.
    if [ ! -x "$SDK_DIR/arm-zephyr-eabi/bin/arm-zephyr-eabi-gcc" ]; then
        log "Installing Zephyr SDK $SDK_VER (minimal bundle + arm toolchain)"
        local base="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${SDK_VER}"
        local tarball="zephyr-sdk-${SDK_VER}_linux-x86_64_minimal.tar.xz"
        curl -fL --retry 3 -o "$WS/$tarball" "$base/$tarball"
        curl -fL --retry 3 -o "$WS/sha256.sum" "$base/sha256.sum"
        (cd "$WS" && grep " ${tarball}\$" sha256.sum | sha256sum -c -) \
            || { echo "SDK checksum is not correct" >&2; exit 1; }
        tar -xf "$WS/$tarball" -C "$WS"
        rm -f "$WS/$tarball" "$WS/sha256.sum"
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

# Read the targets before the bootstrap, thus a bad name stops the run in a second.
# uv gives the parser its own pyyaml, thus this does not need the workspace venv.
targets="$(uv run --with pyyaml python3 "$REPO/scripts/targets.py" "$REPO/build.yaml")" \
    || { echo "could not parse build.yaml" >&2; exit 1; }

wanted=("$@")
if [ "${#wanted[@]}" -gt 0 ]; then
    names="$(printf '%s\n' "$targets" | cut -f1)"
    for w in "${wanted[@]}"; do
        printf '%s\n' "$names" | grep -qxF -- "$w" \
            || { echo "unknown target: $w" >&2; exit 1; }
    done
fi

# bootstrap leaves the shell in $WS with the venv on PATH.
bootstrap
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR="$SDK_DIR"

built=0
while IFS=$'\t' read -r name board shield snippet cmake_args; do
    if [ "${#wanted[@]}" -gt 0 ]; then
        keep=0
        for w in "${wanted[@]}"; do [ "$w" = "$name" ] && keep=1; done
        [ "$keep" -eq 1 ] || continue
    fi
    build_one "$name" "$board" "$shield" "$snippet" "$cmake_args"
    built=$((built + 1))
done <<< "$targets"

[ "$built" -gt 0 ] || { echo "no target matched: ${wanted[*]}" >&2; exit 1; }
log "Done. Firmware in $REPO/firmware/"
