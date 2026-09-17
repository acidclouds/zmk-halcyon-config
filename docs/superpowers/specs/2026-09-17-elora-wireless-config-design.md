# Halcyon Elora wireless config: design

Date: 2026-09-17

## Goal

Build ZMK firmware for a Halcyon Elora rev2 with two wireless controllers and no dongle. The keymap copies the keymap that runs on the user's wired Elora under Vial, with agreed changes. The build runs locally. The repo is a fork at `git@github.com:acidclouds/zmk-halcyon-config.git`.

## Hardware

| Item | Value |
| :--- | :--- |
| Keyboard | Halcyon Elora rev2, shield `halcyon_elora` |
| Controllers | Two `halcyon_wireless//zmk`, left half is central |
| Battery | LiPo board on both halves, shield `mod_battery_lipo` |
| Left module | Epaper display, mountain image, shield `mod_display_epaper_mountain` |
| Right module | Cirque touchpad, shield `mod_cirque_hw_right` |
| Soldered encoders | None |
| Halcyon encoder modules | None |
| Studio | Enabled on the left half |

## Source of the keymap

The keymap was read from the wired Elora over raw HID with the Vial protocol. The raw dump and the decoded keymap are saved in `docs/wired-elora-vial-dump.json` and `docs/wired-elora-vial-decoded.json`. Facts from the dump:

- VIA protocol 9, Vial protocol 6, 8 layers, 12 by 7 matrix. Rows 0 to 4 are the left main matrix, row 5 the left Halcyon module row, rows 6 to 10 the right main matrix, row 11 the right Halcyon module row.
- QMK 0.22 style keycodes. Decoded with the vial-gui `keycodes_v6` table.
- No macros, tap dances, combos, or key overrides in use.
- Only layers 0, 3, and 6 are in use. Layers 1 and 2 are the untouched Dvorak and Colemak defaults and nothing switches to them. Layer 7 is empty.
- Encoders on layer 0: left encoders volume up clockwise and volume down counter-clockwise, right encoders page down clockwise and page up counter-clockwise. Other layers transparent.
- One firmware custom keycode, value 0x7E40, on the inner left key next to Caps. It was a personal QMK experiment and is dropped.

### Matrix mapping, Vial to ZMK

ZMK's `halcyon_transform` lists positions as `RC(row, col)` with 14 columns. For a Vial position `(r, c)`:

- Left main matrix, `r` 0 to 4: ZMK `RC(r, c)`.
- Right main matrix, `r` 6 to 10: ZMK `RC(r - 6, 13 - c)`. The right half's columns are mirrored in QMK.
- Left Halcyon row, `r` 5: ZMK `RC(5, c)`.
- Right Halcyon row, `r` 11: ZMK `RC(5, 7 + c)`.

This mapping was checked against the untouched Dvorak layer, which matched the Splitkb default key for key.

## Keymap

File: `config/halcyon_elora.keymap`. Four layers, referenced by defines. Physical layout is the ZMK `halcyon_transform` order: three rows of 6 plus 6, one row of 8 plus 8, five thumbs per side, then five Halcyon module keys per side.

Layer indices and display names:

| Index | Define | Display name | Origin |
| :--- | :--- | :--- | :--- |
| 0 | `BASE` | Base | Wired layer 0 |
| 1 | `RAISE` | Raise | Wired layer 3 |
| 2 | `STARCRAFT` | StarCraft | Wired layer 6 |
| 3 | `BLUETOOTH` | Bluetooth | New |

Notation below: `_` is `&trans`, `x` is `&none`. Left block then right block per row.

### Base

```
x       x      x      x      x      x        x      x      x      x      x      x
ESC     Q      W      E      R      T        Y      U      I      O      P      BSLH
TAB     A      S      D      F      G        H      J      K      L      SEMI   SQT
LGUI    Z      X      C      V      B   &mo BLUETOOTH  CAPS     x  &tog STARCRAFT  N  M  COMMA  DOT  FSLH  RET
        MINUS  LALT   LSHFT  LCTRL  SPACE    BSPC  &mo RAISE  RSHFT  LBKT  RBKT
C_MUTE  x      x      x      x               x      x      x      x      C_MUTE
```

Changes from the wired layer 0: the custom keycode position holds the Bluetooth layer. The former MO5 key, first inner right key, is `&none` because the F-key layer is dropped. The outer left thumb is MINUS instead of DEL.

### Raise

```
x       F1     F2     F3     F4     F5       F6     F7     F8     F9     F10    F11
TILDE   _      N7     N8     N9     _        HOME   PG_DN  PG_UP  END    _      F12
EQUAL   _      N4     N5     N6     _        LEFT   DOWN   UP     RIGHT  _      GRAVE
_       _      N1     N2     N3     _    x   _        _  &rgb_ug RGB_TOG  _  _  _  _  _  _
        DEL    _      _      _      N0       _      _      _      LPAR   RPAR
_       _      _      _      _               _      _      _      _      _
```

Changes from the wired layer 3: the Bluetooth key position is `&none`. The outer left thumb is DEL instead of MINUS.

### StarCraft

```
ESC     N1     N2     N3     N4     N5       N6     N7     N8     N9     N0     _
TAB     _      _      _      _      _        _      _      _      _      _      _
EQUAL   _      _      _      _      _        _      _      _      _      _      _
LGUI    _      _      _      _      _    x   _        _      _      _      _      _      _      _      _
        _      _      LALT   _      LSHFT    _      _      _      _      _
_       _      _      _      _               _      _      _      _      _
```

Changes from the wired layer 6: number row added, left column top four keys set to ESC, TAB, EQUAL, LGUI, Bluetooth key position is `&none`.

### Bluetooth

```
&studio_unlock  &bt BT_SEL 0  &bt BT_SEL 1  &bt BT_SEL 2  &bt BT_SEL 3  &bt BT_SEL 4    _  _  _  _  _  _
&bt BT_CLR  _  _  _  _  _        _  _  _  _  _  _
_  _  _  _  _  _        _  _  _  _  _  _
_  _  _  _  _  _  _  _        _  _  _  _  _  _  _  _
   _  _  _  _  _        _  _  _  _  _
_  _  _  _  _           _  _  _  _  _
```

Held from Base. Number row keys 1 to 5 select Bluetooth profiles 1 to 5. The Esc key, on the left half, clears the active profile's bond. It must be on the left half so it works while the right half is not linked. The far left number row key unlocks Studio, which ZMK requires before a Studio session can edit the keymap. All other keys pass through.

### Encoders

Sensor bindings on every layer, in the ZMK order left Halcyon, right Halcyon, left soldered, right soldered:

```
&inc_dec_kp C_VOL_UP C_VOL_DN  &inc_dec_kp PG_DN PG_UP  &inc_dec_kp C_VOL_UP C_VOL_DN  &inc_dec_kp PG_DN PG_UP
```

No encoders are fitted. The bindings match the wired board for fidelity and are inert.

## Hardware behavior set in the keymap

### Underglow only

The Elora LED chain on each half starts with 6 underglow LEDs followed by 31 per-key LEDs. The keymap sets:

```
&led_strip { chain-length = <6>; };
```

ZMK then drives only the underglow LEDs. Per-key LEDs get no data and stay dark. Applies to both halves.

### Cirque scroll mode

The keymap includes `<input/processors.dtsi>` and `<dt-bindings/zmk/input_transform.h>` and sets on the trackpad listener:

```
input-processors = <&zip_xy_to_scroll_mapper>, <&zip_scroll_transform INPUT_TRANSFORM_Y_INVERT>, <&zip_scroll_scaler 1 8>;
```

- X and Y motion maps to horizontal and vertical scroll. The pad never moves the pointer.
- Direction is traditional: finger down scrolls down, finger right scrolls right. The right shield already inverts Y for pointer use, so a Y invert is expected for traditional scroll. If an axis comes out flipped on hardware, the fix is the transform flag: add or remove `INPUT_TRANSFORM_Y_INVERT` or `INPUT_TRANSFORM_X_INVERT`. A comment in the keymap says so.
- Scroll speed starts at 1 to 8. Tune the scaler numbers in the keymap.

### Tap to click off

The trackpad node exists only in the right half build, so the keymap cannot touch it. A local shield in this repo does:

- `boards/shields/mod_cirque_no_tap/Kconfig.shield` defines `SHIELD_MOD_CIRQUE_NO_TAP`.
- `boards/shields/mod_cirque_no_tap/mod_cirque_no_tap.overlay` contains `&trackpad { /delete-property/ primary-tap-enable; };`.

The shield is listed after `mod_cirque_hw_right` on the right half so the trackpad node exists when the overlay applies.

## Config file

Files: `config/halcyon_elora_left.conf` and `config/halcyon_elora_right.conf`. A shared file cannot be used: the display and peripheral battery options exist only in the left half build, and Zephyr aborts when a conf assigns a symbol that does not exist or has unmet dependencies. Both files carry the underglow settings. Only the left file carries the display and battery lines.

```
# Underglow: solid royal blue, on at power-up
CONFIG_ZMK_RGB_UNDERGLOW_ON_START=y
CONFIG_ZMK_RGB_UNDERGLOW_EFF_START=0
CONFIG_ZMK_RGB_UNDERGLOW_HUE_START=218
CONFIG_ZMK_RGB_UNDERGLOW_SAT_START=100
CONFIG_ZMK_RGB_UNDERGLOW_BRT_START=45

# Display: custom Elora status screen instead of the Halcyon widget
CONFIG_HALCYON_EPAPER_WIDGET_STATUS=n
CONFIG_ELORA_STATUS_SCREEN=y

# Let the central learn the peripheral battery level
CONFIG_ZMK_SPLIT_BLE_CENTRAL_BATTERY_LEVEL_FETCHING=y
```

The shield defaults stay for everything else: 50 percent brightness cap, underglow auto off when USB is unplugged, sleep, 15 minute idle timeout on the epaper build, 10 minute battery report interval. The display options are inert on the right half, which has no display.

## Custom display screen

### Module wiring

This repo becomes a full Zephyr module. `zephyr/module.yml` gains `build.cmake: .` and `build.kconfig: Kconfig` next to the existing `board_root`. A root `CMakeLists.txt` adds `src/display` when `CONFIG_ELORA_STATUS_SCREEN` is set. A root `Kconfig` defines:

```
config ELORA_STATUS_SCREEN
    bool "Custom Elora epaper status screen"
    depends on ZMK_DISPLAY && ZMK_DISPLAY_STATUS_SCREEN_CUSTOM
    select LV_FONT_MONTSERRAT_16
    select LV_FONT_MONTSERRAT_14
    select LV_FONT_UNSCII_8
    select LV_USE_IMAGE
    select LV_USE_CANVAS
    select ZMK_WPM
```

The Halcyon widget compiles only when `HALCYON_EPAPER_WIDGET_STATUS` is set. Turning it off removes its status screen, its drawing helpers, its bolt icon, and its art. This module therefore carries its own copies, MIT licensed, under `src/display`: `status_screen.c` with `zmk_display_status_screen()`, `widgets/status.c`, `widgets/util.c`, `widgets/bolt.c`, and `widgets/art.c` with the Mountain image only.

### Layout

The widget is 184 by 88 pixels. The status column uses the left 74 pixels as three rotated strips: 24 pixels for battery and output, 20 for the profile circles, 30 for the layer name. The Mountain art fills the remaining 110 by 88 pixels. Only the first strip changes:

- Row one: left half battery icon with fill bar, a bolt over it while USB power is present, the percentage as a number in the 8 pixel font, and the output symbol at the right edge.
- Row two: right half battery icon with fill bar and its percentage. Shows dashes until the peripheral has connected and reported a level. No charging indicator: the peripheral battery event carries only the level.

The profile circles, the layer name, and the art stay as in the Halcyon widget.

### Data sources

- Left level and charging: `zmk_battery_state_changed` and `zmk_usb_conn_state_changed`, as in the Halcyon widget.
- Right level: `zmk_peripheral_battery_state_changed`, field `state_of_charge`. Requires the central battery fetching option above.
- Output, profiles, and layer: same events as the Halcyon widget.

## Build

### Targets

Local builds use the same shield lists as `build.yaml`. `build.yaml` keeps them as documentation and as the single source the build script reads:

```yaml
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

The left half carries `mod_cirque_central` because the touchpad is on the right and there is no dongle. The Elora left shield defaults to central, so no central flag is needed.

### Local toolchain

`scripts/build.sh` does everything. First run:

1. Creates `../zmk-halcyon-ws` next to this repo. The workspace cannot be inside the repo because west clones Zephyr into a `zephyr` folder and this repo already uses that folder for its module file.
2. Creates `.venv` there with `uv venv --python 3.12` and installs west into it.
3. Writes a small manifest repo `manifest/` in the workspace whose `west.yml` is this repo's `config/west.yml` with `self.path` set to `manifest`. Runs `west init -l manifest` and `west update`. This keeps the workspace's manifest clone free of this repo's module file, so the repo is discovered once, as an extra module.
4. Installs Zephyr's Python requirements into the venv and runs `west zephyr-export`.
5. Downloads the Zephyr SDK minimal bundle from the 0.17 series, which Zephyr 4.1 requires, plus the `arm-zephyr-eabi` toolchain, into `../zmk-halcyon-ws/zephyr-sdk-0.17.0`, and registers it.

Every run:

1. Reads `build.yaml` and, for each target, runs `west build -s zmk/app -d build/<artifact-name> -b <board> [-S <snippet>] -p auto -- -DSHIELD="<shield>" -DZMK_CONFIG=<repo>/config -DZMK_EXTRA_MODULES=<repo> <cmake-args>`.
2. Copies `build/<artifact-name>/zephyr/zmk.uf2` to `<repo>/firmware/<artifact-name>.uf2`.

The script takes an optional target name to build one half only. It refuses to run without the workspace's venv unless it is the first run. Git ignores `firmware/`.

### Repo changes

- Origin remote set to `git@github.com:acidclouds/zmk-halcyon-config.git`. Upstream remote `upstream` set to the splitkb repo.
- `.github/workflows/build.yml` removed so pushes never build in the cloud.
- `.gitignore` with `.superpowers/`, `firmware/`, `build/`.
- Design and plan documents under `docs/superpowers/`.

## Verification

Build gate: both targets build locally with no warnings from files in this repo.

Hardware checks after flashing both halves and pairing them:

1. Display shows Base, then Raise while the second right thumb is held, StarCraft after the toggle, Bluetooth while the inner left key is held.
2. Left battery icon, bolt on USB, and percentage. Right percentage appears after the halves link.
3. Holding the Bluetooth key and pressing 1 to 5 switches profiles. The far right number key clears the bond and the profile circle returns to empty.
4. Touchpad scrolls vertically and horizontally in the traditional direction. Tapping the pad does not click.
5. Only the 6 underglow LEDs light, solid royal blue, at power-up.
6. Encoders are not fitted. Nothing to check.
7. Studio connects over USB after the unlock key on the Bluetooth layer.

## Out of scope

Dongle builds, encoder modules, custom art, RGB keys beyond the toggle, Colemak and Dvorak layers, the wired board's firmware, and any behavior tuning after first flash. The user will edit the keymap by hand before the first build.
