# supermini_tfx — ESP32-C6 SuperMini Zigbee Button Switch
# Date: 2026-04-09
# Status: WORKING

---

## Hardware

- **Board**: ESP32-C6 SuperMini
- **USB**: Native USB CDC/JTAG — VID 303a:1001, appears as /dev/ttyACM0
- **IEEE address**: 0x58e6c5fffe16f0c4
- **Button**: GPIO4 → GND (internal pull-up) — same as C6Test2, works unchanged
- **Z2M device name**: C6ButtonSwitch

---

## What Works (confirmed 2026-04-09)

- Button press → serial monitor → Z2M publishes → HA automation fires
- Full chain confirmed working

---

## platformio.ini — Key Settings

```ini
board     = esp32-c6-devkitm-1   ; 4MB, correct for SuperMini
framework = arduino

build_flags =
    -DZIGBEE_MODE_ED
    -DARDUINO_USB_MODE=1          ; required — must pair with CDC_ON_BOOT
    -DARDUINO_USB_CDC_ON_BOOT=1   ; required for native USB serial

board_build.partitions = zigbee.csv
upload_protocol = esp-builtin     ; JTAG via OpenOCD — see flashing notes below
```

---

## src/main.cpp and z2m_converter

Copied unchanged from C6Test2. Zigbee logic is chip-level, not board-level.

---

## WARNING: Do Not Add Sleep Without an Escape Hatch

Light sleep (esp_light_sleep_start) suspends USB on ESP32-C6. This makes JTAG
inaccessible during sleep. Zigbee stored credentials cause fast (~1-2 second)
rejoin, after which the device sleeps immediately — too short a window for JTAG
to flash new firmware.

Recovering requires the two-stage flash in flash.sh (erase zb_storage to force
a 30-second scan window, then flash during that window). This is fragile and
difficult.

**Before adding any sleep: add a boot-time escape hatch** — e.g. hold the button
at boot to keep the device awake for 30 seconds so it can be reflashed normally.

---

## Sticking Points and Solutions

### 1. Build error: USBSerial not declared
`-DARDUINO_USB_CDC_ON_BOOT=1` alone causes a compile error — `Serial` is redefined
as `USBSerial` but that symbol is not in scope.  
**Fix**: Also add `-DARDUINO_USB_MODE=1`. Both flags are required together.

### 2. esptool serial does NOT work on this board
Every esptool attempt gave "Write timeout" even in confirmed bootloader mode.
The ROM bootloader does not drain the USB CDC receive buffer, so writes block
indefinitely. This is not a configuration problem — it is a fundamental
incompatibility between esptool's serial protocol and this board's native USB.  
**Fix**: Use `upload_protocol = esp-builtin` (JTAG via OpenOCD). Do not use esptool.

### 3. The blue LED
- Blue LED **ON** = device is in ROM bootloader mode (after BOOT+RESET sequence)
- Blue LED **OFF** = device running normally
- JTAG flashing requires blue LED OFF. If you see "JTAG scan chain: all ones",
  the device is in bootloader mode — press RESET once (without BOOT) to fix.

### 4. PlatformIO path bug — spaces in folder name
PlatformIO passes `firmware.bin` to OpenOCD as a relative path while passing all
other binaries as absolute paths. When the project folder contains a space, the
relative path fails with `couldn't open {.pio/build/.../firmware.bin}`.  
**Fix**: Call OpenOCD directly with absolute paths (see flash command below).

---

## Flash Command (use instead of `pio run -t upload`)

Device must be running normally (blue LED off) before running this:

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

Build first with: `cd "/home/casg/claude_code/C6 supermini 3/supermini_tfx" && ~/.platformio/penv/bin/pio run`

---

## Z2M Converter

File: `z2m_converter/c6_button_switch.js`  
Install to: `/config/zigbee2mqtt/c6_button_switch.js`  
Add to Z2M `configuration.yaml`:
```yaml
external_converters:
  - c6_button_switch.js
```

---

## Reference: C6Test2 (the original working build)

- GitHub: https://github.com/herpiphil/esp32-c6-zigbee-button-working
- Board: ESP32-C6-DevKit 8MB with CH343 USB bridge
- IEEE: 0x98a316fffe9ef920
- That build used esptool (CH343 handles auto-reset). Do not confuse with this one.
