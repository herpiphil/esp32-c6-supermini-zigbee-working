# supermini_tfx — ESP32-C6 SuperMini Zigbee Button Switch
# Date: 2026-04-09
# Based on working build: ~/claude_code/C6Test2

---

## What Worked (C6Test2 — the reference build)

- **Board**: ESP32-C6-DevKit 8MB SPI Flash with CH343 USB bridge (ttyACM0, VID 1a86:55d3)
- **Firmware**: `src/main.cpp` — button on GPIO4 → GND (internal pull-up), sends ZCL On/Off toggle to coordinator 0x0000
- **Z2M**: Device joined as `esp32-c6_dev`, IEEE address `0x98a316fffe9ef920`
- **HA automation topic**: `zigbee2mqtt/esp32-c6_dev/action`, payload `toggle`
- **Full chain confirmed**: button press → serial prints → Z2M publishes → HA automation fires
- **GitHub**: https://github.com/herpiphil/esp32-c6-zigbee-button-working

### Key platformio.ini settings that made it work
- `board = esp32-c6-devkitc-1`
- `build_flags = -DZIGBEE_MODE_ED` (required — links correct Zigbee End Device libs)
- `board_build.partitions = zigbee.csv` (required — includes Zigbee NVS storage regions)
- **NO** `-DARDUINO_USB_CDC_ON_BOOT` flag — serial goes through CH343 UART bridge, not native USB
- `upload_protocol = esptool`, `upload_speed = 460800`
- CH343 handles auto-reset — no manual BOOT+RESET needed for flashing

---

## What Didn't Work / Problems Encountered

- **Zigbee join failures**: Device appeared to scan but not join. Root cause was distance from coordinator. Fix: move device close to coordinator before joining.
- **NVS wipe**: After a full flash erase, the device loses its Zigbee network credentials and must rejoin. Always permit-join in Z2M after a full erase.
- **Wrong device in Z2M**: The supermini had previously joined Z2M as `c6button_test1`. This caused confusion — we thought the new board had joined when it hadn't. Always check the serial monitor to confirm `Connected. Ready.` before testing the button.
- **DevKitC-1 4MB board** (a third board, set aside): Needed special esptool patch to flash. Not recommended.

---

## Will the Working Code Run on the SuperMini?

### src/main.cpp — YES, probably unchanged
The Zigbee logic and button code are chip-level, not board-level. GPIO4 may or may not be available on the SuperMini — check its pinout. If GPIO4 is not broken out, pick another available GPIO and change `#define BUTTON_PIN`.

### platformio.ini — NEEDS CHANGES
The SuperMini is a different board. Key things to check and change:

1. **Board ID**: The SuperMini is not `esp32-c6-devkitc-1`. It may be `esp32-c6-devkitm-1` or require a custom definition. Check PlatformIO's board list:
   ```
   pio boards | grep c6
   ```

2. **Flash size**: SuperMini is likely 4MB, not 8MB. If so, confirm `zigbee.csv` fits within 4MB (it should — the standard zigbee.csv is designed for 4MB+).

3. **USB / Serial**: The SuperMini likely uses **native USB CDC** (no CH343 bridge). This means:
   - Add `-DARDUINO_USB_CDC_ON_BOOT=1` to build_flags, OR remove all Serial calls and use a different debug method
   - Flashing may require manual BOOT mode (hold BOOT, press RESET, release BOOT, then flash)
   - Device will appear as a different VID/PID (likely 303a:1001)

4. **The supermini previously joined Z2M as `c6button_test1`** — if that entry is still in Z2M, remove it before the new join to avoid confusion.

### z2m_converter/c6_button_switch.js — YES, unchanged
The converter matches on `zigbeeModel: 'C6ButtonSwitch'` which is set in firmware. It will work on any board running this firmware.

---

## Suggested Starting Point for platformio.ini

```ini
; =============================================================
; Date:    2026-04-09
; Project: supermini_tfx — ESP32-C6 SuperMini Zigbee Button Switch
; Notes:   Based on working C6Test2 build. Adjusted for SuperMini.
;          Check board ID, flash size, and USB/serial settings
;          before flashing. See NOTES.md for full details.
; =============================================================

[env:esp32-c6-supermini]
platform  = espressif32
board     = esp32-c6-devkitm-1   ; <-- VERIFY THIS for your SuperMini
framework = arduino

build_flags =
    -DZIGBEE_MODE_ED
    -DARDUINO_USB_CDC_ON_BOOT=1   ; <-- ADD if SuperMini uses native USB

board_build.partitions = zigbee.csv

monitor_speed = 115200

upload_protocol = esptool
upload_speed    = 460800
```

---

## Before You Start

1. Plug in the SuperMini and run `lsusb` to confirm its VID/PID
2. Check which port it appears on (`ls /dev/tty*`)
3. Run `pio boards | grep -i c6` to find the correct board ID
4. Remove the old `c6button_test1` device from Z2M if still present
5. Copy `src/main.cpp` and `z2m_converter/c6_button_switch.js` from C6Test2
6. Adjust `platformio.ini` as above
7. Do a full erase before first flash: `pio run -t erase`
