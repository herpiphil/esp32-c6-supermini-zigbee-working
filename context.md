# Context — C6 SuperMini 3
# Date: 2026-04-09

## Goal
Port the working ESP32-C6 Zigbee button switch (C6Test2) to the ESP32-C6 SuperMini board.

## Status: COMPLETE AND WORKING
Button press confirmed in serial monitor and Home Assistant.

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

## Key Lessons Learned

### Flashing the SuperMini
- esptool (serial protocol) does NOT work with this board over native USB
  - Writes time out even in bootloader mode — ROM bootloader doesn't drain the USB CDC buffer
- Use upload_protocol = esp-builtin (OpenOCD via JTAG) instead
- Device must be running normally (NOT in bootloader mode) for JTAG to work
- PlatformIO has a bug: passes firmware.bin as a relative path to OpenOCD, which fails
  - Workaround: run OpenOCD directly with absolute paths (see flash command below)

### Blue LED
- Blue LED ON = device is in ROM bootloader mode (BOOT+RESET sequence)
- Blue LED OFF = device running normally
- JTAG flashing requires blue LED OFF (normal run mode)

### Build Flags for Native USB
- Must add -DARDUINO_USB_MODE=1 alongside -DARDUINO_USB_CDC_ON_BOOT=1
  - Without USB_MODE=1, Serial macro resolves to USBSerial which is undeclared

## Flash Command (use when re-flashing)
Run from any directory — uses absolute paths:

```bash
~/.platformio/packages/tool-openocd-esp32/bin/openocd \
  -s ~/.platformio/packages/tool-openocd-esp32/share/openocd/scripts \
  -f interface/esp_usb_jtag.cfg \
  -f target/esp32c6.cfg \
  -c "adapter speed 5000" \
  -c "program_esp {/home/casg/claude_code/C6 supermini 3/supermini_tfx/.pio/build/esp32-c6-supermini/firmware.bin} 0x10000 verify" \
  -c "program_esp {/home/casg/claude_code/C6 supermini 3/supermini_tfx/.pio/build/esp32-c6-supermini/bootloader.bin} 0x0000 verify" \
  -c "program_esp {/home/casg/claude_code/C6 supermini 3/supermini_tfx/.pio/build/esp32-c6-supermini/partitions.bin} 0x8000 verify" \
  -c "program_esp {/home/casg/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin} 0xe000 verify" \
  -c "reset run; shutdown"
```

## Z2M Converter
File: supermini_tfx/z2m_converter/c6_button_switch.js
Install to: /config/zigbee2mqtt/c6_button_switch.js
Add to Z2M configuration.yaml:
  external_converters:
    - c6_button_switch.js
