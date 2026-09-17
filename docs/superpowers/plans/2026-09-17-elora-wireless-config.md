# Halcyon Elora Wireless Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Local ZMK firmware builds for a Halcyon Elora rev2 with two wireless halves, the wired board's keymap, scroll-only Cirque touchpad, underglow-only RGB, and a custom epaper status screen with both battery levels.

**Architecture:** This repo is a ZMK user config and a Zephyr module at the same time. `config/` holds the keymap and per-side conf files. `boards/shields/` holds one local shield that removes tap-to-click. `src/display/` holds a custom LVGL status screen that replaces the Halcyon widget. `scripts/build.sh` bootstraps a west workspace next to the repo and builds both halves against the working tree.

**Tech Stack:** ZMK (splitkb fork `main+halcyon-fixes`), Zephyr 4.1, LVGL 9, west, Zephyr SDK 0.17.0, uv-managed Python 3.12, bash.

Spec: `docs/superpowers/specs/2026-09-17-elora-wireless-config-design.md`.

---

## Facts the engineer needs

- **Halves.** Left is central and has the epaper display. Right is peripheral and has the Cirque touchpad. There is no dongle.
- **Config file rules.** ZMK reads `config/<shield>.conf` and `config/<shield>.keymap`. A shared `halcyon_elora.conf` would apply to both halves, but several options we need exist only on the left half build. Assigning a Kconfig symbol that does not exist or has unmet dependencies aborts a Zephyr build. So this plan uses `halcyon_elora_left.conf` and `halcyon_elora_right.conf`, and one shared `halcyon_elora.keymap`. This is a deliberate deviation from the spec's single conf file.
- **Keymap order.** The Elora `halcyon_transform` lists 72 positions: three rows of 6 left plus 6 right, one row of 8 left plus 8 right, 5 thumbs left plus 5 right, then 5 Halcyon module keys left plus 5 right.
- **Widget geometry.** The status widget is 184 by 88. Three 88 by 88 canvases are drawn then rotated 90 degrees, so a canvas strip of `y` 0 to 23 becomes a 24 pixel wide column. The `top` canvas owns strip 0 to 23, `middle` 24 to 43, `bottom` 44 to 73, and the art starts at 74. Anything drawn past `y` 23 in the top canvas is covered by the middle canvas.
- **Peripheral battery.** ZMK raises `zmk_peripheral_battery_state_changed` on the central with fields `source` and `state_of_charge` when `CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING=y`. The header is `zmk/events/battery_state_changed.h`.
- **Halcyon module pin.** Widget sources are copied from `splitkb/zmk-halcyon-module` at commit `2054c0469e554f136387d2a580c494e8296d3681`.
- **Workspace.** Lives at `../zmk-halcyon-ws` relative to the repo. Never inside the repo: west would clone Zephyr into `zephyr/`, which this repo already uses for `zephyr/module.yml`.

## File structure

| Path | Responsibility |
| :--- | :--- |
| `build.yaml` | The two build targets. Read by the build script. |
| `config/halcyon_elora.keymap` | Keymap, encoder bindings, LED chain length, Cirque scroll processors. |
| `config/halcyon_elora_left.conf` | Left half options: underglow, display, peripheral battery fetching. |
| `config/halcyon_elora_right.conf` | Right half options: underglow. |
| `boards/shields/mod_cirque_no_tap/Kconfig.shield` | Declares the local shield. |
| `boards/shields/mod_cirque_no_tap/mod_cirque_no_tap.overlay` | Removes tap-to-click from the trackpad node. |
| `zephyr/module.yml` | Registers this repo as a module with CMake, Kconfig, and boards. |
| `CMakeLists.txt` | Adds `src/display` when the custom screen is enabled. |
| `Kconfig` | Defines `ELORA_STATUS_SCREEN`. |
| `src/display/CMakeLists.txt` | Compiles the screen sources. |
| `src/display/status_screen.c` | `zmk_display_status_screen()` entry point. |
| `src/display/widgets/status.c` | The status widget with the two-battery top strip. |
| `src/display/widgets/status.h` | Widget struct. |
| `src/display/widgets/util.c`, `util.h` | Drawing helpers and `status_state`, copied from the module. |
| `src/display/widgets/bolt.c`, `art.c` | Image data, copied verbatim from the module. |
| `scripts/build.sh` | Bootstraps the workspace and builds targets. |
| `scripts/targets.py` | Prints build targets from `build.yaml` as tab-separated lines. |
| `.gitignore` | Ignores `.superpowers/`, `firmware/`, `build/`. |

---

### Task 1: Repo hygiene and build targets

**Files:**
- Delete: `.github/workflows/build.yml`
- Modify: `build.yaml`
- Modify: `docs/superpowers/specs/2026-09-17-elora-wireless-config-design.md` (conf file deviation)

- [ ] **Step 1: Remove the cloud workflow**

```bash
cd /home/val/Work/zmk-halcyon-config
git rm -q .github/workflows/build.yml
rmdir .github/workflows .github 2>/dev/null || true
```

- [ ] **Step 2: Write the build targets**

Replace the whole of `build.yaml` with:

```yaml
# Build targets. scripts/build.sh reads this file.
# artifact-name is the build directory name and the .uf2 name in firmware/.
---
include:
  - board: halcyon_wireless//zmk
    shield: halcyon_elora_left mod_battery_lipo mod_display_epaper_mountain mod_cirque_central
    cmake-args: -DCONFIG_ZMK_STUDIO=y
    snippet: studio-rpc-usb-uart
    artifact-name: elora_left
  - board: halcyon_wireless//zmk
    shield: halcyon_elora_right mod_battery_lipo mod_cirque_hw_right mod_cirque_no_tap
    artifact-name: elora_right
```

- [ ] **Step 3: Record the conf file deviation in the spec**

In the spec, replace the line `File: \`config/halcyon_elora.conf\`, applied to both halves.` with:

```markdown
Files: `config/halcyon_elora_left.conf` and `config/halcyon_elora_right.conf`. A shared file cannot be used: the display and peripheral battery options exist only in the left half build, and Zephyr aborts when a conf assigns a symbol that does not exist or has unmet dependencies. Both files carry the underglow settings. Only the left file carries the display and battery lines.
```

Run:

```bash
grep -n "halcyon_elora_left.conf" docs/superpowers/specs/2026-09-17-elora-wireless-config-design.md
```

Expected: one line printed.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Remove cloud workflow, set build targets

Builds run locally. The build.yaml keeps the two targets as the single
source for scripts/build.sh.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Local build script and workspace bootstrap

**Files:**
- Create: `scripts/targets.py`
- Create: `scripts/build.sh`
- Test: `scripts/test_targets.py`

- [ ] **Step 1: Write the failing test for the target parser**

Create `scripts/test_targets.py`:

```python
"""Run: uv run --with pyyaml,pytest pytest scripts/test_targets.py -q"""
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def run(yaml_text: str) -> str:
    return subprocess.run(
        [sys.executable, str(REPO / "scripts" / "targets.py"), "/dev/stdin"],
        input=yaml_text, capture_output=True, text=True, check=True,
    ).stdout


def test_prints_one_tab_separated_line_per_target():
    out = run(
        "include:\n"
        "  - board: b//z\n"
        "    shield: s1 s2\n"
        "    cmake-args: -DX=y\n"
        "    snippet: snip\n"
        "    artifact-name: left\n"
        "  - board: b//z\n"
        "    shield: s3\n"
        "    artifact-name: right\n"
    )
    assert out.splitlines() == [
        "left\tb//z\ts1 s2\tsnip\t-DX=y",
        "right\tb//z\ts3\t\t",
    ]


def test_repo_build_yaml_has_left_and_right():
    out = subprocess.run(
        [sys.executable, str(REPO / "scripts" / "targets.py"), str(REPO / "build.yaml")],
        capture_output=True, text=True, check=True,
    ).stdout
    names = [line.split("\t")[0] for line in out.splitlines()]
    assert names == ["elora_left", "elora_right"]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /home/val/Work/zmk-halcyon-config && uv run --with pyyaml,pytest pytest scripts/test_targets.py -q`
Expected: 2 failed, both with `No such file or directory: '.../scripts/targets.py'`.

- [ ] **Step 3: Write the target parser**

Create `scripts/targets.py`:

```python
#!/usr/bin/env python3
"""Print build targets from a build.yaml, one per line:
artifact-name TAB board TAB shield TAB snippet TAB cmake-args
Usage: targets.py build.yaml"""
import sys

import yaml


def main(path: str) -> None:
    with open(path) as f:
        doc = yaml.safe_load(f) or {}
    for t in doc.get("include", []):
        name = t.get("artifact-name") or t["shield"].split()[0]
        print("\t".join([
            name,
            t["board"],
            t["shield"],
            t.get("snippet", "") or "",
            t.get("cmake-args", "") or "",
        ]))


if __name__ == "__main__":
    main(sys.argv[1])
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `uv run --with pyyaml,pytest pytest scripts/test_targets.py -q`
Expected: `2 passed`.

- [ ] **Step 5: Write the build script**

Create `scripts/build.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x scripts/build.sh scripts/targets.py
```

- [ ] **Step 6: Bootstrap the workspace and build the stock right half**

The right half target lists `mod_cirque_no_tap`, which does not exist yet. Build the left half first: it uses only upstream shields. With no keymap or conf in `config/` yet, this is a pure baseline of the upstream default.

Run:

```bash
cd /home/val/Work/zmk-halcyon-config && scripts/build.sh elora_left 2>&1 | tail -40
```

Expected: the bootstrap logs, then a west build ending with lines like:

```
Memory region         Used Size  Region Size  %age Used
           FLASH:      ...
==> Wrote firmware/elora_left.uf2
==> Done. Firmware in /home/val/Work/zmk-halcyon-config/firmware/
```

If `west init -l manifest` fails saying the directory is not a git repository, the `git init` block above already handles it. If `west update` fails on a network error, rerun the script; every stage is idempotent.

If the build fails with `Shield ... not found`, check that `../zmk-halcyon-ws/zmk-halcyon-module/boards/shields/halcyon_elora` exists. It should, from `west update`.

- [ ] **Step 7: Confirm the artifact**

Run: `ls -la firmware/ && git status --short`
Expected: `firmware/elora_left.uf2` exists. `git status` does not list `firmware/` because `.gitignore` excludes it.

- [ ] **Step 8: Commit**

```bash
git add scripts/build.sh scripts/targets.py scripts/test_targets.py
git commit -m "Add local build script with workspace bootstrap

scripts/build.sh creates ../zmk-halcyon-ws with a uv venv, west, the
splitkb ZMK fork, and Zephyr SDK 0.17.0, then builds the targets from
build.yaml against this working tree.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Local shield that removes tap-to-click

**Files:**
- Create: `boards/shields/mod_cirque_no_tap/Kconfig.shield`
- Create: `boards/shields/mod_cirque_no_tap/mod_cirque_no_tap.overlay`

- [ ] **Step 1: Verify the right half fails without the shield**

Run: `scripts/build.sh elora_right 2>&1 | grep -i "shield" | head -5`
Expected: an error naming `mod_cirque_no_tap` as not found. This is the failing state the shield fixes.

- [ ] **Step 2: Write the shield Kconfig**

Create `boards/shields/mod_cirque_no_tap/Kconfig.shield`:

```kconfig
# Copyright (c) 2026 Val
# SPDX-License-Identifier: MIT

config SHIELD_MOD_CIRQUE_NO_TAP
    def_bool $(shields_list_contains,mod_cirque_no_tap)
```

- [ ] **Step 3: Write the shield overlay**

Create `boards/shields/mod_cirque_no_tap/mod_cirque_no_tap.overlay`:

```dts
/*
 * Copyright (c) 2026 Val
 * SPDX-License-Identifier: MIT
 *
 * Disables tap-to-click on the Cirque Pinnacle. List this shield after
 * mod_cirque_hw_right so the trackpad node exists when this overlay applies.
 */

&trackpad {
    /delete-property/ primary-tap-enable;
};
```

- [ ] **Step 4: Build the right half**

Run: `scripts/build.sh elora_right 2>&1 | tail -15`
Expected: build succeeds and prints `==> Wrote firmware/elora_right.uf2`.

- [ ] **Step 5: Confirm the property is gone from the compiled devicetree**

Run:

```bash
grep -n -A12 'compatible = "cirque,pinnacle"' ../zmk-halcyon-ws/build/elora_right/zephyr/zephyr.dts | grep -c "primary-tap-enable"
```

Expected: `0`. For comparison, the same grep on the left build directory is also `0` because the left half has no trackpad node at all, so also run:

```bash
grep -c 'compatible = "cirque,pinnacle"' ../zmk-halcyon-ws/build/elora_right/zephyr/zephyr.dts
```

Expected: `1`.

- [ ] **Step 6: Commit**

```bash
git add boards/shields/mod_cirque_no_tap
git commit -m "Add mod_cirque_no_tap shield

Removes primary-tap-enable from the Cirque trackpad node on the right
half. The keymap cannot do this because the node only exists in the
right half build.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Keymap

**Files:**
- Create: `config/halcyon_elora.keymap`

- [ ] **Step 1: Write the keymap**

Create `config/halcyon_elora.keymap`:

```dts
/*
 * Halcyon Elora rev2, wireless, no dongle.
 * Keymap copied from the wired Elora Vial keymap (docs/wired-elora-vial-decoded.json)
 * with the changes listed in docs/superpowers/specs/2026-09-17-elora-wireless-config-design.md.
 *
 * SPDX-License-Identifier: MIT
 */

#include <behaviors.dtsi>
#include <dt-bindings/zmk/bt.h>
#include <dt-bindings/zmk/keys.h>
#include <dt-bindings/zmk/rgb.h>
#include <dt-bindings/zmk/input_transform.h>
#include <input/processors.dtsi>

#define BASE      0
#define RAISE     1
#define STARCRAFT 2
#define BLUETOOTH 3

/* Underglow only: the chain starts with the 6 underglow LEDs, then 31 per-key LEDs. */
&led_strip {
    chain-length = <6>;
};

/*
 * Cirque touchpad: always scroll, both axes, no pointer movement.
 * Traditional direction: finger down scrolls down, finger right scrolls right.
 * The right shield inverts Y for pointer use, so one Y invert is expected here.
 * If an axis is flipped on hardware, change the transform flags:
 *   INPUT_TRANSFORM_Y_INVERT                             vertical only (current)
 *   (INPUT_TRANSFORM_Y_INVERT | INPUT_TRANSFORM_X_INVERT) both axes
 *   remove the zip_scroll_transform entry                 no invert
 * Scroll speed: zip_scroll_scaler multiplies by 1/8. Raise the second number to slow down.
 */
&trackpad_listener {
    input-processors = <&zip_xy_to_scroll_mapper>,
                       <&zip_scroll_transform INPUT_TRANSFORM_Y_INVERT>,
                       <&zip_scroll_scaler 1 8>;
};

/* Order: left halcyon encoder, right halcyon encoder, left soldered, right soldered. */
#define ENCODERS \
    <&inc_dec_kp C_VOL_UP C_VOL_DN &inc_dec_kp PG_DN PG_UP &inc_dec_kp C_VOL_UP C_VOL_DN &inc_dec_kp PG_DN PG_UP>

/ {
    keymap {
        compatible = "zmk,keymap";

        base_layer {
            display-name = "Base";
// ------------------------------------------------------------------------------------------------------------------
// |      |     |     |     |     |     |                                     |     |     |     |     |     |      |
// | ESC  |  Q  |  W  |  E  |  R  |  T  |                                     |  Y  |  U  |  I  |  O  |  P  |  \   |
// | TAB  |  A  |  S  |  D  |  F  |  G  |                                     |  H  |  J  |  K  |  L  |  ;  |  '   |
// | LGUI |  Z  |  X  |  C  |  V  |  B  | mo BT | CAPS |   |     | tog SC |  N  |  M  |  ,  |  .  |  /  | RET  |
//                    |  -  | LALT| LSHFT| LCTRL| SPC |   | BSPC | mo RAISE | RSHFT |  [  |  ]  |
// | MUTE |     |     |     |     |                                                 |     |     |     |     | MUTE |
            bindings = <
&none    &none &none &none &none &none                                                    &none &none &none  &none   &none    &none
&kp ESC  &kp Q &kp W &kp E &kp R &kp T                                                    &kp Y &kp U &kp I  &kp O   &kp P    &kp BSLH
&kp TAB  &kp A &kp S &kp D &kp F &kp G                                                    &kp H &kp J &kp K  &kp L   &kp SEMI &kp SQT
&kp LGUI &kp Z &kp X &kp C &kp V &kp B  &mo BLUETOOTH &kp CAPS      &none    &tog STARCRAFT &kp N &kp M &kp COMMA &kp DOT &kp FSLH &kp RET
                     &kp MINUS &kp LALT &kp LSHFT &kp LCTRL &kp SPACE  &kp BSPC &mo RAISE &kp RSHFT &kp LBKT &kp RBKT

&kp C_MUTE &none &none &none &none                                                                       &none &none &none &none &kp C_MUTE
            >;
            sensor-bindings = ENCODERS;
        };

        raise_layer {
            display-name = "Raise";
// ------------------------------------------------------------------------------------------------------------------
// |      |  F1 |  F2 |  F3 |  F4 |  F5 |                                     |  F6 |  F7 |  F8 |  F9 | F10 | F11  |
// |  ~   |     |  7  |  8  |  9  |     |                                     | HOME| PGDN| PGUP| END |     | F12  |
// |  =   |     |  4  |  5  |  6  |     |                                     | LEFT| DOWN| UP  | RGHT|     |  `   |
// |      |     |  1  |  2  |  3  |     | none |      |   |      | RGB TOG |     |     |     |     |     |      |
//                    | DEL |     |     |     |  0  |   |      |      |      |  (  |  )  |
// |      |     |     |     |     |                                                 |     |     |     |     |      |
            bindings = <
&none     &kp F1 &kp F2 &kp F3 &kp F4 &kp F5                                              &kp F6   &kp F7    &kp F8    &kp F9    &kp F10 &kp F11
&kp TILDE &trans &kp N7 &kp N8 &kp N9 &trans                                              &kp HOME &kp PG_DN &kp PG_UP &kp END   &trans  &kp F12
&kp EQUAL &trans &kp N4 &kp N5 &kp N6 &trans                                              &kp LEFT &kp DOWN  &kp UP    &kp RIGHT &trans  &kp GRAVE
&trans    &trans &kp N1 &kp N2 &kp N3 &trans  &none  &trans      &trans &rgb_ug RGB_TOG   &trans   &trans    &trans    &trans    &trans  &trans
                        &kp DEL &trans &trans &trans &kp N0      &trans &trans &trans &kp LPAR &kp RPAR

&trans &trans &trans &trans &trans                                                                            &trans &trans &trans &trans &trans
            >;
            sensor-bindings = ENCODERS;
        };

        starcraft_layer {
            display-name = "StarCraft";
// ------------------------------------------------------------------------------------------------------------------
// | ESC  |  1  |  2  |  3  |  4  |  5  |                                     |  6  |  7  |  8  |  9  |  0  |      |
// | TAB  |     |     |     |     |     |                                     |     |     |     |     |     |      |
// |  =   |     |     |     |     |     |                                     |     |     |     |     |     |      |
// | LGUI |     |     |     |     |     | none |      |   |      |      |     |     |     |     |     |      |
//                    |     |     | LALT|     |LSHFT|   |      |      |      |     |     |
// |      |     |     |     |     |                                                 |     |     |     |     |      |
            bindings = <
&kp ESC   &kp N1 &kp N2 &kp N3 &kp N4 &kp N5                                              &kp N6 &kp N7 &kp N8 &kp N9 &kp N0 &trans
&kp TAB   &trans &trans &trans &trans &trans                                              &trans &trans &trans &trans &trans &trans
&kp EQUAL &trans &trans &trans &trans &trans                                              &trans &trans &trans &trans &trans &trans
&kp LGUI  &trans &trans &trans &trans &trans  &none  &trans      &trans &trans            &trans &trans &trans &trans &trans &trans
                        &trans &trans &kp LALT &trans &kp LSHFT  &trans &trans &trans &trans &trans

&trans &trans &trans &trans &trans                                                                            &trans &trans &trans &trans &trans
            >;
            sensor-bindings = ENCODERS;
        };

        bluetooth_layer {
            display-name = "Bluetooth";
// ------------------------------------------------------------------------------------------------------------------
// |STUDIO| BT1 | BT2 | BT3 | BT4 | BT5 |                                     |     |     |     |     |     |BT CLR|
// |      |     |     |     |     |     |                                     |     |     |     |     |     |      |
// |      |     |     |     |     |     |                                     |     |     |     |     |     |      |
// |      |     |     |     |     |     |      |      |   |      |      |     |     |     |     |     |      |
//                    |     |     |     |     |     |   |      |      |      |     |     |
// |      |     |     |     |     |                                                 |     |     |     |     |      |
            bindings = <
&studio_unlock &bt BT_SEL 0 &bt BT_SEL 1 &bt BT_SEL 2 &bt BT_SEL 3 &bt BT_SEL 4          &trans &trans &trans &trans &trans &bt BT_CLR
&trans &trans &trans &trans &trans &trans                                                 &trans &trans &trans &trans &trans &trans
&trans &trans &trans &trans &trans &trans                                                 &trans &trans &trans &trans &trans &trans
&trans &trans &trans &trans &trans &trans  &trans &trans          &trans &trans           &trans &trans &trans &trans &trans &trans
                        &trans &trans &trans &trans &trans        &trans &trans &trans &trans &trans

&trans &trans &trans &trans &trans                                                                            &trans &trans &trans &trans &trans
            >;
            sensor-bindings = ENCODERS;
        };
    };
};
```

- [ ] **Step 2: Count bindings per layer**

Every layer must have exactly 72 bindings. Run:

```bash
python3 - <<'EOF'
import re
src = open('config/halcyon_elora.keymap').read()
for name, body in re.findall(r'(\w+_layer) \{.*?bindings = <(.*?)>;', src, re.S):
    body = re.sub(r'//.*', '', body)
    n = len(re.findall(r'&\w+', body))
    print(name, n)
EOF
```

Expected:

```
base_layer 72
raise_layer 72
starcraft_layer 72
bluetooth_layer 72
```

- [ ] **Step 3: Build both halves**

Run: `scripts/build.sh 2>&1 | grep -E "^==>|error|warning: " | head -30`
Expected: two `==> Wrote firmware/...` lines and no lines containing `error`. Devicetree errors name `halcyon_elora.keymap` with a line number; fix the keymap and rebuild.

- [ ] **Step 4: Confirm the LED chain length and the scroll processors landed in both builds**

Run:

```bash
for h in elora_left elora_right; do
  echo "== $h"
  grep -c "chain-length = < 0x6 >" ../zmk-halcyon-ws/build/$h/zephyr/zephyr.dts
  grep -A3 "trackpad_listener {" ../zmk-halcyon-ws/build/$h/zephyr/zephyr.dts | grep -c "input-processors"
done
```

Expected: `1` and `1` for each half.

- [ ] **Step 5: Commit**

```bash
git add config/halcyon_elora.keymap
git commit -m "Add Elora keymap from the wired board

Base, Raise, StarCraft, Bluetooth layers. Underglow chain limited to
the 6 underglow LEDs. Cirque mapped to scroll on both axes.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: Pause for the user's manual keymap edits**

The user said they will make a couple of modifications by hand before the first flash. Tell the user the keymap is in place and built, and ask whether they want to edit it now. Continue with Task 5 after they answer. Their edits, if any, get their own commit.

---

### Task 5: Per-side conf files

**Files:**
- Create: `config/halcyon_elora_left.conf`
- Create: `config/halcyon_elora_right.conf`

- [ ] **Step 1: Write the right half conf**

Create `config/halcyon_elora_right.conf`:

```conf
# Halcyon Elora right half (peripheral).

# Underglow: solid royal blue, on at power-up. The 50 percent brightness cap
# and USB auto-off come from the shield.
CONFIG_ZMK_RGB_UNDERGLOW_ON_START=y
CONFIG_ZMK_RGB_UNDERGLOW_EFF_START=0
CONFIG_ZMK_RGB_UNDERGLOW_HUE_START=218
CONFIG_ZMK_RGB_UNDERGLOW_SAT_START=100
CONFIG_ZMK_RGB_UNDERGLOW_BRT_START=45
```

- [ ] **Step 2: Write the left half conf, without the display lines yet**

Create `config/halcyon_elora_left.conf`:

```conf
# Halcyon Elora left half (central, epaper display, Studio).

# Underglow: solid royal blue, on at power-up. The 50 percent brightness cap
# and USB auto-off come from the shield.
CONFIG_ZMK_RGB_UNDERGLOW_ON_START=y
CONFIG_ZMK_RGB_UNDERGLOW_EFF_START=0
CONFIG_ZMK_RGB_UNDERGLOW_HUE_START=218
CONFIG_ZMK_RGB_UNDERGLOW_SAT_START=100
CONFIG_ZMK_RGB_UNDERGLOW_BRT_START=45

# Let the central learn the right half's battery level.
CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING=y
```

The two display lines are added in Task 6, once the custom screen exists. Adding `CONFIG_ELORA_STATUS_SCREEN=y` before the Kconfig symbol exists would abort the build.

- [ ] **Step 3: Build both halves and check the values took effect**

Run:

```bash
scripts/build.sh 2>&1 | grep -E "^==>|error" ; \
for h in elora_left elora_right; do echo "== $h"; grep -E "RGB_UNDERGLOW_(ON_START|EFF_START|HUE_START|SAT_START|BRT_START)=" ../zmk-halcyon-ws/build/$h/zephyr/.config; done; \
grep -c "CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING=y" ../zmk-halcyon-ws/build/elora_left/zephyr/.config
```

Expected per half:

```
CONFIG_ZMK_RGB_UNDERGLOW_ON_START=y
CONFIG_ZMK_RGB_UNDERGLOW_HUE_START=218
CONFIG_ZMK_RGB_UNDERGLOW_SAT_START=100
CONFIG_ZMK_RGB_UNDERGLOW_BRT_START=45
CONFIG_ZMK_RGB_UNDERGLOW_EFF_START=0
```

and `1` for the battery fetching line. Order within `.config` may differ.

- [ ] **Step 4: Commit**

```bash
git add config/halcyon_elora_left.conf config/halcyon_elora_right.conf
git commit -m "Add per-side conf files

Underglow solid royal blue on at start for both halves. Left half
fetches the peripheral battery level.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Custom epaper status screen

**Files:**
- Modify: `zephyr/module.yml`
- Create: `CMakeLists.txt`
- Create: `Kconfig`
- Create: `src/display/CMakeLists.txt`
- Create: `src/display/status_screen.c`
- Create: `src/display/widgets/util.h`, `util.c`, `bolt.c`, `art.c` (copied from the module)
- Create: `src/display/widgets/status.h`, `status.c`
- Modify: `config/halcyon_elora_left.conf`

- [ ] **Step 1: Register CMake and Kconfig in the module file**

Replace `zephyr/module.yml` with:

```yaml
build:
  cmake: .
  kconfig: Kconfig
  settings:
    board_root: .
```

- [ ] **Step 2: Write the root CMake and Kconfig**

Create `CMakeLists.txt`:

```cmake
# This repo is a Zephyr module. Only the custom display screen has sources.
if(CONFIG_ELORA_STATUS_SCREEN)
  add_subdirectory(src/display)
endif()
```

Create `Kconfig`:

```kconfig
# Copyright (c) 2026 Val
# SPDX-License-Identifier: MIT

config ELORA_STATUS_SCREEN
    bool "Custom Elora epaper status screen with both battery levels"
    depends on ZMK_DISPLAY && ZMK_DISPLAY_STATUS_SCREEN_CUSTOM
    depends on !ZMK_SPLIT || ZMK_SPLIT_ROLE_CENTRAL
    select LV_FONT_MONTSERRAT_16
    select LV_FONT_MONTSERRAT_14
    select LV_FONT_UNSCII_8
    select LV_USE_IMAGE
    select LV_USE_CANVAS
    help
      Replaces the Halcyon epaper status widget. Shows the left and right
      battery levels with percentages, the output status, the Bluetooth
      profiles, the active layer name, and the Mountain art.
```

- [ ] **Step 3: Copy the unchanged widget files from the Halcyon module**

Run:

```bash
mkdir -p src/display/widgets
B="https://raw.githubusercontent.com/splitkb/zmk-halcyon-module/2054c0469e554f136387d2a580c494e8296d3681/boards/shields/mod_display_epaper/widgets"
for f in util.c bolt.c art.c; do curl -sfL -o "src/display/widgets/$f" "$B/$f"; done
grep -c "draw_battery" src/display/widgets/util.c; grep -c "Mountain_map" src/display/widgets/art.c; grep -c "bolt_map" src/display/widgets/bolt.c
```

Expected: `1` or more for each grep. These three files are copied verbatim. Do not edit them.

- [ ] **Step 4: Write util.h with two extra state fields**

Create `src/display/widgets/util.h`. This is the module's `util.h` with `peripheral_battery` and `peripheral_known` added to `status_state`:

```c
/*
 *
 * Copyright (c) 2025 The ZMK Contributors
 * SPDX-License-Identifier: MIT
 *
 * Copied from splitkb/zmk-halcyon-module boards/shields/mod_display_epaper/widgets/util.h
 * at 2054c0469e554f136387d2a580c494e8296d3681. Change: peripheral battery fields in status_state.
 */

#pragma once

#include <lvgl.h>
#include <zmk/endpoints.h>

#define NICEVIEW_PROFILE_COUNT 5

#define CANVAS_SIZE 88
#define CANVAS_COLOR_FORMAT LV_COLOR_FORMAT_L8 // smallest type supported by sw_rotate
#define CANVAS_BUF_SIZE                                                                            \
    LV_CANVAS_BUF_SIZE(CANVAS_SIZE, CANVAS_SIZE, LV_COLOR_FORMAT_GET_BPP(CANVAS_COLOR_FORMAT),     \
                       LV_DRAW_BUF_STRIDE_ALIGN)

#define LVGL_BACKGROUND                                                                            \
    IS_ENABLED(CONFIG_HALCYON_EPAPER_WIDGET_INVERTED) ? lv_color_black() : lv_color_white()
#define LVGL_FOREGROUND                                                                            \
    IS_ENABLED(CONFIG_HALCYON_EPAPER_WIDGET_INVERTED) ? lv_color_white() : lv_color_black()

struct status_state {
    uint8_t battery;
    bool charging;
    uint8_t peripheral_battery;
    bool peripheral_known;
#if !IS_ENABLED(CONFIG_ZMK_SPLIT) || IS_ENABLED(CONFIG_ZMK_SPLIT_ROLE_CENTRAL)
    struct zmk_endpoint_instance selected_endpoint;
    int active_profile_index;
    bool active_profile_connected;
    bool active_profile_bonded;
    bool profiles_connected[NICEVIEW_PROFILE_COUNT];
    bool profiles_bonded[NICEVIEW_PROFILE_COUNT];
    uint8_t layer_index;
    const char *layer_label;
    uint8_t wpm[10];
#else
    bool connected;
#endif
};

struct battery_status_state {
    uint8_t level;
#if IS_ENABLED(CONFIG_USB_DEVICE_STACK)
    bool usb_present;
#endif
};

void rotate_canvas(lv_obj_t *canvas);
void draw_battery(lv_obj_t *canvas, const struct status_state *state);
void init_label_dsc(lv_draw_label_dsc_t *label_dsc, lv_color_t color, const lv_font_t *font,
                    lv_text_align_t align);
void init_rect_dsc(lv_draw_rect_dsc_t *rect_dsc, lv_color_t bg_color);
void init_line_dsc(lv_draw_line_dsc_t *line_dsc, lv_color_t color, uint8_t width);
void init_arc_dsc(lv_draw_arc_dsc_t *arc_dsc, lv_color_t color, uint8_t width);

void canvas_draw_line(lv_obj_t *canvas, const lv_point_t points[], uint32_t point_cnt,
                      lv_draw_line_dsc_t *draw_dsc);
void canvas_draw_rect(lv_obj_t *canvas, lv_coord_t x, lv_coord_t y, lv_coord_t w, lv_coord_t h,
                      lv_draw_rect_dsc_t *draw_dsc);
void canvas_draw_arc(lv_obj_t *canvas, lv_coord_t x, lv_coord_t y, lv_coord_t r,
                     int32_t start_angle, int32_t end_angle, lv_draw_arc_dsc_t *draw_dsc);
void canvas_draw_text(lv_obj_t *canvas, lv_coord_t x, lv_coord_t y, lv_coord_t max_w,
                      lv_draw_label_dsc_t *draw_dsc, const char *txt);
void canvas_draw_img(lv_obj_t *canvas, lv_coord_t x, lv_coord_t y, const lv_image_dsc_t *src,
                     lv_draw_image_dsc_t *draw_dsc);
```

- [ ] **Step 5: Write status.h**

Create `src/display/widgets/status.h` (identical to the module's file):

```c
/*
 *
 * Copyright (c) 2023 The ZMK Contributors
 * SPDX-License-Identifier: MIT
 *
 * Copied from splitkb/zmk-halcyon-module boards/shields/mod_display_epaper/widgets/status.h
 * at 2054c0469e554f136387d2a580c494e8296d3681. Unchanged.
 */

#pragma once

#include <lvgl.h>
#include <zephyr/kernel.h>
#include "util.h"

struct zmk_widget_status {
    sys_snode_t node;
    lv_obj_t *obj;
    uint8_t cbuf[CANVAS_BUF_SIZE];
    uint8_t cbuf2[CANVAS_BUF_SIZE];
    uint8_t cbuf3[CANVAS_BUF_SIZE];
    struct status_state state;
};

int zmk_widget_status_init(struct zmk_widget_status *widget, lv_obj_t *parent);
lv_obj_t *zmk_widget_status_obj(struct zmk_widget_status *widget);
```

- [ ] **Step 6: Write status.c**

Create `src/display/widgets/status.c`. This is the module's `status.c` with a new `draw_top`, a `draw_small_battery` helper, and a peripheral battery listener. `draw_middle`, `draw_bottom`, the output listener, the layer listener, and `zmk_widget_status_init` are unchanged apart from the art selection, which is fixed to Mountain.

```c
/*
 *
 * Copyright (c) 2025 The ZMK Contributors
 * SPDX-License-Identifier: MIT
 *
 * Based on splitkb/zmk-halcyon-module boards/shields/mod_display_epaper/widgets/status.c
 * at 2054c0469e554f136387d2a580c494e8296d3681.
 * Changes: the top strip shows both halves' battery levels with percentages,
 * a peripheral battery listener feeds the right half's level, art is always Mountain.
 */

#include <zephyr/kernel.h>

#include <zephyr/logging/log.h>
LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#include <zmk/battery.h>
#include <zmk/display.h>
#include "status.h"
#include <zmk/events/usb_conn_state_changed.h>
#include <zmk/event_manager.h>
#include <zmk/events/battery_state_changed.h>
#include <zmk/events/ble_active_profile_changed.h>
#include <zmk/events/endpoint_changed.h>
#include <zmk/events/layer_state_changed.h>
#include <zmk/usb.h>
#include <zmk/ble.h>
#include <zmk/endpoints.h>
#include <zmk/keymap.h>

LV_IMG_DECLARE(Mountain);

static sys_slist_t widgets = SYS_SLIST_STATIC_INIT(&widgets);

struct output_status_state {
    struct zmk_endpoint_instance selected_endpoint;
    int active_profile_index;
    bool active_profile_connected;
    bool active_profile_bonded;
    bool profiles_connected[NICEVIEW_PROFILE_COUNT];
    bool profiles_bonded[NICEVIEW_PROFILE_COUNT];
};

struct layer_status_state {
    zmk_keymap_layer_index_t index;
    const char *label;
};

struct peripheral_battery_status_state {
    uint8_t level;
    bool known;
};

/*
 * Small battery icon, 27 by 10 pixels including the nub, at (x, y).
 * Fill bar is 21 pixels wide at 100 percent. A bolt is drawn over it while charging.
 */
static void draw_small_battery(lv_obj_t *canvas, lv_coord_t x, lv_coord_t y, uint8_t level,
                               bool charging) {
    lv_draw_rect_dsc_t rect_bg;
    init_rect_dsc(&rect_bg, LVGL_BACKGROUND);
    lv_draw_rect_dsc_t rect_fg;
    init_rect_dsc(&rect_fg, LVGL_FOREGROUND);

    canvas_draw_rect(canvas, x, y, 25, 10, &rect_fg);
    canvas_draw_rect(canvas, x + 1, y + 1, 23, 8, &rect_bg);
    canvas_draw_rect(canvas, x + 2, y + 2, (level * 21 + 50) / 100, 6, &rect_fg);
    canvas_draw_rect(canvas, x + 25, y + 3, 2, 4, &rect_fg);

    if (charging) {
        // Zigzag bolt: a wide background stroke first so it reads on the filled part too,
        // then a thin foreground stroke so it reads on the empty part.
        const lv_point_t bolt[] = {{x + 14, y + 1}, {x + 10, y + 5}, {x + 15, y + 5}, {x + 11, y + 9}};
        lv_draw_line_dsc_t line_bg;
        init_line_dsc(&line_bg, LVGL_BACKGROUND, 3);
        canvas_draw_line(canvas, bolt, 4, &line_bg);
        lv_draw_line_dsc_t line_fg;
        init_line_dsc(&line_fg, LVGL_FOREGROUND, 1);
        canvas_draw_line(canvas, bolt, 4, &line_fg);
    }
}

static void draw_top(lv_obj_t *widget, const struct status_state *state) {
    lv_obj_t *canvas = lv_obj_get_child(widget, 0);

    lv_draw_label_dsc_t symbol_dsc;
    init_label_dsc(&symbol_dsc, LVGL_FOREGROUND, &lv_font_montserrat_16, LV_TEXT_ALIGN_RIGHT);
    lv_draw_label_dsc_t small_dsc;
    init_label_dsc(&small_dsc, LVGL_FOREGROUND, &lv_font_unscii_8, LV_TEXT_ALIGN_LEFT);

    // Fill background
    lv_canvas_fill_bg(canvas, LVGL_BACKGROUND, LV_OPA_COVER);

    // Row one, y 0..11: left half battery, percentage, output symbol at the right edge.
    draw_small_battery(canvas, 0, 1, state->battery, state->charging);
    char text[8];
    snprintf(text, sizeof(text), "L%3u%%", state->battery);
    canvas_draw_text(canvas, 29, 2, 44, &small_dsc, text);

    // Row two, y 12..23: right half battery and percentage, or dashes while unknown.
    if (state->peripheral_known) {
        draw_small_battery(canvas, 0, 13, state->peripheral_battery, false);
        snprintf(text, sizeof(text), "R%3u%%", state->peripheral_battery);
    } else {
        draw_small_battery(canvas, 0, 13, 0, false);
        snprintf(text, sizeof(text), "R --%%");
    }
    canvas_draw_text(canvas, 29, 14, 44, &small_dsc, text);

    // Output status, right aligned across the full width on row one.
    char output_text[10] = {};

    switch (state->selected_endpoint.transport) {
    case ZMK_TRANSPORT_NONE:
        strcat(output_text, LV_SYMBOL_CLOSE);
        break;
    case ZMK_TRANSPORT_USB:
        strcat(output_text, LV_SYMBOL_USB);
        break;
    case ZMK_TRANSPORT_BLE:
        if (state->active_profile_bonded) {
            if (state->active_profile_connected) {
                strcat(output_text, LV_SYMBOL_WIFI);
            } else {
                strcat(output_text, LV_SYMBOL_CLOSE);
            }
        } else {
            strcat(output_text, LV_SYMBOL_SETTINGS);
        }
        break;
    }

    canvas_draw_text(canvas, 0, 0, CANVAS_SIZE, &symbol_dsc, output_text);

    // Rotate canvas
    rotate_canvas(canvas);
}

static void draw_middle(lv_obj_t *widget, const struct status_state *state) {
    lv_obj_t *canvas = lv_obj_get_child(widget, 2);

    lv_draw_rect_dsc_t rect_black_dsc;
    init_rect_dsc(&rect_black_dsc, LVGL_BACKGROUND);
    lv_draw_rect_dsc_t rect_white_dsc;
    init_rect_dsc(&rect_white_dsc, LVGL_FOREGROUND);
    lv_draw_arc_dsc_t arc_dsc;
    init_arc_dsc(&arc_dsc, LVGL_FOREGROUND, 2);
    lv_draw_arc_dsc_t arc_dsc_filled;
    init_arc_dsc(&arc_dsc_filled, LVGL_FOREGROUND, 9);
    lv_draw_label_dsc_t label_dsc;
    init_label_dsc(&label_dsc, LVGL_FOREGROUND, &lv_font_montserrat_14, LV_TEXT_ALIGN_CENTER);
    lv_draw_label_dsc_t label_dsc_black;
    init_label_dsc(&label_dsc_black, LVGL_BACKGROUND, &lv_font_montserrat_14, LV_TEXT_ALIGN_CENTER);

    // Fill background
    lv_canvas_fill_bg(canvas, LVGL_BACKGROUND, LV_OPA_COVER);

    // Draw circles
    int circle_offsets[NICEVIEW_PROFILE_COUNT][2] = {
        {10, 16}, {27, 16}, {44, 16}, {61, 16}, {78, 16},
    };

    for (int i = 0; i < NICEVIEW_PROFILE_COUNT; i++) {
        bool selected = i == state->active_profile_index;

        if (state->profiles_connected[i]) {
            canvas_draw_arc(canvas, circle_offsets[i][0], circle_offsets[i][1], 10, 0, 360,
                            &arc_dsc);
        } else if (state->profiles_bonded[i]) {
            const int segments = 8;
            const int gap = 20;
            for (int j = 0; j < segments; ++j)
                canvas_draw_arc(canvas, circle_offsets[i][0], circle_offsets[i][1], 10,
                                360. / segments * j + gap / 2.0,
                                360. / segments * (j + 1) - gap / 2.0, &arc_dsc);
        }

        if (selected) {
            canvas_draw_arc(canvas, circle_offsets[i][0], circle_offsets[i][1], 7, 0, 359,
                            &arc_dsc_filled);
        }

        char label[2];
        snprintf(label, sizeof(label), "%d", i + 1);
        canvas_draw_text(canvas, circle_offsets[i][0] - 8, circle_offsets[i][1] - 9, 16,
                         (selected ? &label_dsc_black : &label_dsc), label);
    }

    // Rotate canvas
    rotate_canvas(canvas);
}

static void draw_bottom(lv_obj_t *widget, const struct status_state *state) {
    lv_obj_t *canvas = lv_obj_get_child(widget, 1);

    lv_draw_rect_dsc_t rect_black_dsc;
    init_rect_dsc(&rect_black_dsc, LVGL_BACKGROUND);
    lv_draw_label_dsc_t label_dsc;
    init_label_dsc(&label_dsc, LVGL_FOREGROUND, &lv_font_montserrat_14, LV_TEXT_ALIGN_CENTER);

    // Fill background
    lv_canvas_fill_bg(canvas, LVGL_BACKGROUND, LV_OPA_COVER);

    // Draw layer
    if (state->layer_label == NULL || strlen(state->layer_label) == 0) {
        char text[10] = {};

        sprintf(text, "LAYER %i", state->layer_index);

        canvas_draw_text(canvas, 0, 0, 88, &label_dsc, text);
    } else {
        canvas_draw_text(canvas, 0, 0, 88, &label_dsc, state->layer_label);
    }

    // Rotate canvas
    rotate_canvas(canvas);
}

static void set_battery_status(struct zmk_widget_status *widget,
                               struct battery_status_state state) {
#if IS_ENABLED(CONFIG_USB_DEVICE_STACK)
    widget->state.charging = state.usb_present;
#endif /* IS_ENABLED(CONFIG_USB_DEVICE_STACK) */

    widget->state.battery = state.level;

    draw_top(widget->obj, &widget->state);
}

static void battery_status_update_cb(struct battery_status_state state) {
    struct zmk_widget_status *widget;
    SYS_SLIST_FOR_EACH_CONTAINER(&widgets, widget, node) { set_battery_status(widget, state); }
}

static struct battery_status_state battery_status_get_state(const zmk_event_t *eh) {
    const struct zmk_battery_state_changed *ev = as_zmk_battery_state_changed(eh);

    return (struct battery_status_state){
        .level = (ev != NULL) ? ev->state_of_charge : zmk_battery_state_of_charge(),
#if IS_ENABLED(CONFIG_USB_DEVICE_STACK)
        .usb_present = zmk_usb_is_powered(),
#endif /* IS_ENABLED(CONFIG_USB_DEVICE_STACK) */
    };
}

ZMK_DISPLAY_WIDGET_LISTENER(widget_battery_status, struct battery_status_state,
                            battery_status_update_cb, battery_status_get_state)

ZMK_SUBSCRIPTION(widget_battery_status, zmk_battery_state_changed);
#if IS_ENABLED(CONFIG_USB_DEVICE_STACK)
ZMK_SUBSCRIPTION(widget_battery_status, zmk_usb_conn_state_changed);
#endif /* IS_ENABLED(CONFIG_USB_DEVICE_STACK) */

#if IS_ENABLED(CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING)
static void set_peripheral_battery_status(struct zmk_widget_status *widget,
                                          struct peripheral_battery_status_state state) {
    widget->state.peripheral_battery = state.level;
    widget->state.peripheral_known = state.known;

    draw_top(widget->obj, &widget->state);
}

static void peripheral_battery_status_update_cb(struct peripheral_battery_status_state state) {
    struct zmk_widget_status *widget;
    SYS_SLIST_FOR_EACH_CONTAINER(&widgets, widget, node) {
        set_peripheral_battery_status(widget, state);
    }
}

static struct peripheral_battery_status_state
peripheral_battery_status_get_state(const zmk_event_t *eh) {
    const struct zmk_peripheral_battery_state_changed *ev =
        as_zmk_peripheral_battery_state_changed(eh);

    if (ev == NULL) {
        // Called once at init before any report arrived.
        return (struct peripheral_battery_status_state){.level = 0, .known = false};
    }
    return (struct peripheral_battery_status_state){.level = ev->state_of_charge, .known = true};
}

ZMK_DISPLAY_WIDGET_LISTENER(widget_peripheral_battery_status,
                            struct peripheral_battery_status_state,
                            peripheral_battery_status_update_cb,
                            peripheral_battery_status_get_state)

ZMK_SUBSCRIPTION(widget_peripheral_battery_status, zmk_peripheral_battery_state_changed);
#endif /* IS_ENABLED(CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING) */

static void set_output_status(struct zmk_widget_status *widget,
                              const struct output_status_state *state) {
    widget->state.selected_endpoint = state->selected_endpoint;
    widget->state.active_profile_index = state->active_profile_index;
    widget->state.active_profile_connected = state->active_profile_connected;
    widget->state.active_profile_bonded = state->active_profile_bonded;
    for (int i = 0; i < NICEVIEW_PROFILE_COUNT; ++i) {
        widget->state.profiles_connected[i] = state->profiles_connected[i];
        widget->state.profiles_bonded[i] = state->profiles_bonded[i];
    }

    draw_top(widget->obj, &widget->state);
    draw_middle(widget->obj, &widget->state);
}

static void output_status_update_cb(struct output_status_state state) {
    struct zmk_widget_status *widget;
    SYS_SLIST_FOR_EACH_CONTAINER(&widgets, widget, node) { set_output_status(widget, &state); }
}

static struct output_status_state output_status_get_state(const zmk_event_t *_eh) {
    struct output_status_state state = {
        .selected_endpoint = zmk_endpoint_get_selected(),
        .active_profile_index = zmk_ble_active_profile_index(),
        .active_profile_connected = zmk_ble_active_profile_is_connected(),
        .active_profile_bonded = !zmk_ble_active_profile_is_open(),
    };
    for (int i = 0; i < MIN(NICEVIEW_PROFILE_COUNT, ZMK_BLE_PROFILE_COUNT); ++i) {
        state.profiles_connected[i] = zmk_ble_profile_is_connected(i);
        state.profiles_bonded[i] = !zmk_ble_profile_is_open(i);
    }
    return state;
}

ZMK_DISPLAY_WIDGET_LISTENER(widget_output_status, struct output_status_state,
                            output_status_update_cb, output_status_get_state)
ZMK_SUBSCRIPTION(widget_output_status, zmk_endpoint_changed);

#if IS_ENABLED(CONFIG_USB_DEVICE_STACK)
ZMK_SUBSCRIPTION(widget_output_status, zmk_usb_conn_state_changed);
#endif
#if defined(CONFIG_ZMK_BLE)
ZMK_SUBSCRIPTION(widget_output_status, zmk_ble_active_profile_changed);
#endif

static void set_layer_status(struct zmk_widget_status *widget, struct layer_status_state state) {
    widget->state.layer_index = state.index;
    widget->state.layer_label = state.label;

    draw_middle(widget->obj, &widget->state);
    draw_bottom(widget->obj, &widget->state);
}

static void layer_status_update_cb(struct layer_status_state state) {
    struct zmk_widget_status *widget;
    SYS_SLIST_FOR_EACH_CONTAINER(&widgets, widget, node) { set_layer_status(widget, state); }
}

static struct layer_status_state layer_status_get_state(const zmk_event_t *eh) {
    zmk_keymap_layer_index_t index = zmk_keymap_highest_layer_active();
    return (struct layer_status_state){
        .index = index, .label = zmk_keymap_layer_name(zmk_keymap_layer_index_to_id(index))};
}

ZMK_DISPLAY_WIDGET_LISTENER(widget_layer_status, struct layer_status_state, layer_status_update_cb,
                            layer_status_get_state)

ZMK_SUBSCRIPTION(widget_layer_status, zmk_layer_state_changed);

int zmk_widget_status_init(struct zmk_widget_status *widget, lv_obj_t *parent) {
    widget->obj = lv_obj_create(parent);
    lv_obj_set_size(widget->obj, 184, 88);
    lv_obj_t *top = lv_canvas_create(widget->obj);
    lv_obj_align(top, LV_ALIGN_TOP_LEFT, 0, 0);
    lv_canvas_set_buffer(top, widget->cbuf, CANVAS_SIZE, CANVAS_SIZE, CANVAS_COLOR_FORMAT);
    lv_obj_t *middle = lv_canvas_create(widget->obj);
    lv_obj_align(middle, LV_ALIGN_TOP_LEFT, 24, 0);
    lv_canvas_set_buffer(middle, widget->cbuf2, CANVAS_SIZE, CANVAS_SIZE, CANVAS_COLOR_FORMAT);
    lv_obj_t *bottom = lv_canvas_create(widget->obj);
    lv_obj_align(bottom, LV_ALIGN_TOP_LEFT, 44, 0);
    lv_canvas_set_buffer(bottom, widget->cbuf3, CANVAS_SIZE, CANVAS_SIZE, CANVAS_COLOR_FORMAT);

    lv_obj_t *art = lv_img_create(widget->obj);
    lv_image_set_src(art, &Mountain);
    lv_obj_align(art, LV_ALIGN_TOP_LEFT, 74, 0);

    widget->state.peripheral_known = false;

    sys_slist_append(&widgets, &widget->node);
    widget_battery_status_init();
#if IS_ENABLED(CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING)
    widget_peripheral_battery_status_init();
#endif
    widget_output_status_init();
    widget_layer_status_init();

    return 0;
}

lv_obj_t *zmk_widget_status_obj(struct zmk_widget_status *widget) { return widget->obj; }
```

- [ ] **Step 7: Write the screen entry point and the display CMake**

Create `src/display/status_screen.c`:

```c
/*
 * Copyright (c) 2023 The ZMK Contributors
 * SPDX-License-Identifier: MIT
 *
 * Based on splitkb/zmk-halcyon-module boards/shields/mod_display_epaper/custom_status_screen.c.
 * ZMK calls zmk_display_status_screen() when CONFIG_ZMK_DISPLAY_STATUS_SCREEN_CUSTOM is set.
 */

#include "widgets/status.h"

#include <zephyr/logging/log.h>
LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

static struct zmk_widget_status status_widget;

lv_obj_t *zmk_display_status_screen() {
    lv_obj_t *screen = lv_obj_create(NULL);

    zmk_widget_status_init(&status_widget, screen);
    lv_obj_align(zmk_widget_status_obj(&status_widget), LV_ALIGN_TOP_LEFT, 0, 0);

    return screen;
}
```

Create `src/display/CMakeLists.txt`:

```cmake
zephyr_library()
# ZMK headers (zmk/display.h, zmk/battery.h, ...) live in zmk/app/include.
# CMAKE_SOURCE_DIR is zmk/app when built with `west build -s zmk/app`.
zephyr_library_include_directories(${CMAKE_SOURCE_DIR}/include)
zephyr_library_sources(
  status_screen.c
  widgets/status.c
  widgets/util.c
  widgets/bolt.c
  widgets/art.c
)
```

- [ ] **Step 8: Enable the screen in the left conf**

Append to `config/halcyon_elora_left.conf`:

```conf

# Display: custom Elora status screen instead of the Halcyon widget.
CONFIG_HALCYON_EPAPER_WIDGET_STATUS=n
CONFIG_ELORA_STATUS_SCREEN=y
```

- [ ] **Step 9: Build the left half with a pristine build directory**

The module set changed, so force a full reconfigure:

```bash
rm -rf ../zmk-halcyon-ws/build/elora_left
scripts/build.sh elora_left 2>&1 | grep -E "^==>|error|warning:|status\.c|util\.c" | head -40
```

Expected: `==> Wrote firmware/elora_left.uf2` and no `error` lines. Warnings from files under `src/display/` must be fixed. Warnings from ZMK or Zephyr itself can be ignored.

If the link fails with `multiple definition of zmk_display_status_screen`, the Halcyon widget is still compiled: check that `CONFIG_HALCYON_EPAPER_WIDGET_STATUS=n` appears in `../zmk-halcyon-ws/build/elora_left/zephyr/.config`.

If the build fails with `undefined reference to Mountain`, `art.c` did not compile: check `src/display/CMakeLists.txt` lists it.

- [ ] **Step 10: Confirm which screen is compiled in**

Run:

```bash
grep -E "CONFIG_(ELORA_STATUS_SCREEN|HALCYON_EPAPER_WIDGET_STATUS|ZMK_DISPLAY_STATUS_SCREEN_CUSTOM|ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING)" ../zmk-halcyon-ws/build/elora_left/zephyr/.config
grep -c "peripheral_battery_status" ../zmk-halcyon-ws/build/elora_left/zephyr/zephyr.map
```

Expected:

```
CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING=y
CONFIG_ZMK_DISPLAY_STATUS_SCREEN_CUSTOM=y
# CONFIG_HALCYON_EPAPER_WIDGET_STATUS is not set
CONFIG_ELORA_STATUS_SCREEN=y
```

and a count of 1 or more for the map grep, which proves the peripheral listener is linked.

- [ ] **Step 11: Build the right half to confirm the module does no harm there**

```bash
scripts/build.sh elora_right 2>&1 | grep -E "^==>|error" | head
grep -c "ELORA_STATUS_SCREEN" ../zmk-halcyon-ws/build/elora_right/zephyr/.config
```

Expected: `==> Wrote firmware/elora_right.uf2`, and `0` for the grep. The right half has no display, so the symbol's dependencies are unmet and it does not appear. The right conf never sets it, so there is no warning.

- [ ] **Step 12: Commit**

```bash
git add zephyr/module.yml CMakeLists.txt Kconfig src/display config/halcyon_elora_left.conf
git commit -m "Add custom epaper status screen with both battery levels

Copies the Halcyon epaper widget into this module and reworks the top
strip: left battery with bolt and percentage, right battery with
percentage from the peripheral battery event. Mountain art kept.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Full build, push, and hardware checklist

**Files:**
- Modify: `README.md` (add a short local build section at the top)

- [ ] **Step 1: Clean full build of both halves**

```bash
rm -rf ../zmk-halcyon-ws/build firmware
scripts/build.sh 2>&1 | grep -E "^==>|error|warning:.*zmk-halcyon-config" 
ls -la firmware/
```

Expected: two `==> Wrote` lines, no `error`, no warnings pointing into this repo, and two `.uf2` files listed.

- [ ] **Step 2: Add a local build section to the README**

Insert after the first heading line of `README.md` (`# Official Splitkb.com Halcyon ZMK config`):

```markdown

> **This fork:** Halcyon Elora rev2, two wireless halves, epaper left, Cirque right.
> Build locally with `scripts/build.sh`. First run creates `../zmk-halcyon-ws` and
> downloads the toolchain. Firmware lands in `firmware/elora_left.uf2` and
> `firmware/elora_right.uf2`. Design notes are in `docs/superpowers/`.
```

- [ ] **Step 3: Commit and push**

```bash
git add README.md
git commit -m "Document the local build in the README

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin main
```

Expected: push succeeds to `acidclouds/zmk-halcyon-config`.

- [ ] **Step 4: Flash and check on hardware**

Flashing: double tap reset on a half, copy the matching `.uf2` to the USB drive that appears. Flash the right half first, then the left. Then pair a computer with profile 1.

Checklist. Report each as pass or fail:

1. Display shows `Base`. Hold the second right thumb key: `Raise`. Press the inner right key next to the thumbs: `StarCraft`, press again to leave. Hold the inner left key next to Caps: `Bluetooth`.
2. Left battery icon and `L nn%`. Plug USB into the left half: bolt appears. `R --%` becomes `R nn%` within 10 minutes of the halves linking, sooner after a right half reset.
3. Hold the Bluetooth key and press number row key 2: profile circle 2 becomes active and the computer sees a new pairing. Hold it and press the far right number row key: the active profile's bond clears.
4. Touchpad: finger down scrolls a page down, finger right scrolls right. If an axis is reversed, edit the transform flags in `config/halcyon_elora.keymap` as its comment says, rebuild, reflash the left half only, since processors run on the central.
5. Tapping the touchpad does not click.
6. Only the 6 underglow LEDs light, solid blue, at power-up on both halves. No per-key LEDs light.
7. Studio: open https://zmk.studio in Chrome, connect over USB to the left half, hold the Bluetooth key and press the far left number row key to unlock, and confirm the four layers appear.

- [ ] **Step 5: Record results**

Append a `## Hardware check 2026-MM-DD` section at the end of the spec with the pass or fail per item and any keymap edits made as a result. Commit and push.

---

## Self-review notes

- Spec coverage: build targets (Task 1), local build (Task 2), tap-to-click shield (Task 3), keymap with underglow chain and Cirque scroll (Task 4), conf options (Task 5, with the per-side deviation recorded in the spec by Task 1), custom screen with both batteries (Task 6), verification and push (Task 7).
- The spec's single conf file is replaced by two files. Reason documented in Task 1 Step 3 and in the facts section.
- Names used across tasks: `mod_cirque_no_tap`, `ELORA_STATUS_SCREEN`, `draw_small_battery`, `peripheral_battery_status_state`, `widget_peripheral_battery_status`, `elora_left`, `elora_right`, `scripts/build.sh`, `scripts/targets.py`. Each is defined before use.
