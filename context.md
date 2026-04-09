# Context — C6 SuperMini 3
# Date: 2026-04-09

## Goal
Port the working ESP32-C6 Zigbee button switch (C6Test2) to the ESP32-C6 SuperMini board.

## Status: COMPLETE AND WORKING (non-sleep firmware on device)

## Hardware
- Board: ESP32-C6 SuperMini
- USB: Native USB CDC/JTAG (VID 303a:1001, /dev/ttyACM0)
- IEEE address: 0x58e6c5fffe16f0c4
- Z2M device name: C6ButtonSwitch
- Button: GPIO4 → GND (internal pull-up)

## What Was Done
- Copied src/main.cpp from C6Test2 unchanged (Zigbee logic is chip-level)
- Copied z2m_converter/c6_button_switch.js unchanged
- Created platformio.ini with:
  - board = esp32-c6-devkitm-1 (4MB, correct for SuperMini)
  - -DZIGBEE_MODE_ED
  - -DARDUINO_USB_MODE=1
  - -DARDUINO_USB_CDC_ON_BOOT=1
  - board_build.partitions = zigbee.csv
  - upload_protocol = esp-builtin (JTAG via OpenOCD)
- Attempted light sleep experiment (try-sleep branch) — abandoned
- Reverted to non-sleep master firmware using two-stage flash

## Git Branches
- master: working non-sleep firmware (current)
- try-sleep: light sleep experiment (abandoned — USB suspend makes reflashing very difficult)
- Tag v1.0-working: first confirmed working build

## Key Lessons Learned

### Flashing the SuperMini
- esptool (serial protocol) does NOT work with this board over native USB
- Use upload_protocol = esp-builtin (OpenOCD via JTAG) instead
- Device must be running normally (NOT in bootloader mode) for JTAG to work
- PlatformIO bug: passes firmware.bin as relative path to OpenOCD — fails with spaces in path
  - Workaround: run OpenOCD directly with absolute paths (see flash.sh)

### Blue LED
- Blue LED ON = device is in ROM bootloader mode (BOOT+RESET sequence)
- Blue LED OFF = device running normally
- JTAG flashing requires blue LED OFF (normal run mode)

### Build Flags for Native USB
- Must add -DARDUINO_USB_MODE=1 alongside -DARDUINO_USB_CDC_ON_BOOT=1

### Light Sleep Warning
- esp_light_sleep_start() suspends USB on ESP32-C6 — JTAG becomes inaccessible
- Zigbee stored credentials cause fast (~1-2 second) rejoin then immediately sleeps again
- Recovering from a sleeping device requires the two-stage flash (see flash.sh)
- DO NOT add sleep without a boot-time escape hatch (e.g. hold button at boot = stay awake)

### Two-Stage Flash (for recovering sleeping device)
- Stage 1: catch device during brief wake window, erase zb_storage NVS (0x3EB000, 0x4000)
  - Device reboots with no stored credentials → scans for ~30 seconds without sleeping
- Stage 2: flash firmware.bin during that 30-second scan window
- Key fix: use "reset halt" after "init; halt" — halting mid-sleep leaves CPU in dirty state
  causing flasher stub error (-302). "reset halt" resets to clean CPU state first.
- After zb_storage erase: Z2M must have permit join open for device to reconnect

### Zigbee Partition Table (zigbee.csv)
- nvs:        0x9000,   0x5000
- otadata:    0xe000,   0x2000
- app0:       0x10000,  0x140000
- app1:       0x150000, 0x140000
- spiffs:     0x290000, 0x15B000
- zb_storage: 0x3EB000, 0x4000   ← erase this to clear Zigbee credentials
- zb_fct:     0x3EF000, 0x1000
- coredump:   0x3F0000, 0x10000

## Flash Script
See flash.sh — two-stage script handles both sleeping and normal devices.
Build first: cd "/home/casg/claude_code/C6 supermini 3/supermini_tfx" && ~/.platformio/penv/bin/pio run

## Serial Monitor
~/.platformio/penv/bin/pio device monitor --port /dev/ttyACM0 --baud 115200 --project-dir "/home/casg/claude_code/C6 supermini 3/supermini_tfx"

## Z2M Converter
File: supermini_tfx/z2m_converter/c6_button_switch.js
Install to: /config/zigbee2mqtt/c6_button_switch.js
Add to Z2M configuration.yaml:
  external_converters:
    - c6_button_switch.js
