#!/bin/bash
# Date:    2026-04-09
# Project: supermini_tfx — two-stage flash for sleeping device
# Notes:
#   The -302 flasher stub error happens because halting mid-sleep leaves the
#   CPU in a dirty state. Fix: catch device awake with "init; halt", then
#   immediately do "reset halt" to get a clean CPU state before flash ops.
#
#   Stage 1: Catch device during brief wake window, reset halt for clean state,
#            erase zb_storage NVS (0x3EB000, 0x4000). Device reboots with no
#            Zigbee credentials.
#   Stage 2: Device now scans for ~30 seconds without sleeping. Flash firmware.bin
#            during that window.
#   Usage:   Run script, then press and release RESET on the board once.

OPENOCD=~/.platformio/packages/tool-openocd-esp32/bin/openocd
SCRIPTS=~/.platformio/packages/tool-openocd-esp32/share/openocd/scripts
BUILD="/home/casg/claude_code/C6 supermini 3/supermini_tfx/.pio/build/esp32-c6-supermini"

OCD() {
  "$OPENOCD" -s "$SCRIPTS" \
    -f interface/esp_usb_jtag.cfg \
    -f target/esp32c6.cfg \
    -c "adapter speed 20000" \
    "$@" 2>&1
}

# ── Stage 1: erase Zigbee NVS ────────────────────────────────────────────────
echo "=== Stage 1: erasing Zigbee storage ==="
echo "Press and release RESET on the board now."

ERASED=0
for i in $(seq 1 200); do
  OUT=$(OCD \
    -c "init; halt" \
    -c "reset halt" \
    -c "flash erase_address 0x3EB000 0x4000" \
    -c "reset run; shutdown")
  echo "$OUT" | grep -E "erased|Error|halted|shutdown|stub"
  if echo "$OUT" | grep -q "erased"; then
    echo "Zigbee storage erased. Device rebooting..."
    ERASED=1
    break
  fi
  sleep 0.1
done

if [ $ERASED -eq 0 ]; then
  echo "ERROR: Could not erase Zigbee storage after 20 seconds. Aborting."
  exit 1
fi

# ── Stage 2: flash firmware during 30-second join scan ───────────────────────
echo ""
echo "=== Stage 2: flashing firmware (30-second window) ==="
echo "No action needed — device is scanning for Zigbee network."

sleep 2

FLASHED=0
for i in $(seq 1 150); do
  OUT=$(OCD \
    -c "init; halt" \
    -c "reset halt" \
    -c "program_esp {$BUILD/firmware.bin} 0x10000 verify" \
    -c "reset run; shutdown")
  echo "$OUT" | grep -E "Verify OK|Failed|shutdown|Error|halted|stub"
  if echo "$OUT" | grep -q "Verify OK"; then
    echo ""
    echo "=== Flash successful. Non-sleep firmware is running. ==="
    FLASHED=1
    break
  fi
  sleep 0.2
done

if [ $FLASHED -eq 0 ]; then
  echo "ERROR: Firmware flash failed."
  exit 1
fi
