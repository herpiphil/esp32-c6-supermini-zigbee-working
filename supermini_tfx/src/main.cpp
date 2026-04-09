// =============================================================
// Date:    2026-04-09
// Project: supermini_tfx — ESP32-C6 SuperMini Zigbee Button Switch
// Notes:   Ported from working C6Test2 build. Code unchanged —
//          Zigbee logic is chip-level, not board-level.
//          Button on GPIO4 → GND (internal pull-up).
//          On press: sends ZCL toggle to coordinator (0x0000).
//          Joins Z2M as End Device. No sleep.
// =============================================================

#include "Arduino.h"
#include "Zigbee.h"
#include "zcl/esp_zigbee_zcl_command.h"

#define BUTTON_PIN  4
#define ENDPOINT    1

ZigbeeSwitch zbSwitch = ZigbeeSwitch(ENDPOINT);

static unsigned long lastPress = 0;

void sendToggle() {
  esp_zb_zcl_on_off_cmd_t cmd = {};
  cmd.zcl_basic_cmd.src_endpoint          = ENDPOINT;
  cmd.zcl_basic_cmd.dst_addr_u.addr_short = 0x0000;
  cmd.zcl_basic_cmd.dst_endpoint          = 1;
  cmd.address_mode  = ESP_ZB_APS_ADDR_MODE_16_ENDP_PRESENT;
  cmd.on_off_cmd_id = ESP_ZB_ZCL_CMD_ON_OFF_TOGGLE_ID;

  if (esp_zb_lock_acquire(pdMS_TO_TICKS(2000))) {
    esp_zb_zcl_on_off_cmd_req(&cmd);
    esp_zb_lock_release();
    Serial.println("Toggle sent.");
  } else {
    Serial.println("Lock timeout — not sent.");
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("supermini_tfx starting...");

  pinMode(BUTTON_PIN, INPUT_PULLUP);

  zbSwitch.setManufacturerAndModel("Custom", "C6ButtonSwitch");
  zbSwitch.setPowerSource(ZB_POWER_SOURCE_MAINS, 100);
  Zigbee.addEndpoint(&zbSwitch);

  esp_zb_cfg_t cfg = ZIGBEE_DEFAULT_ED_CONFIG();
  Zigbee.setTimeout(30000);

  if (!Zigbee.begin(&cfg, false)) {
    Serial.println("Zigbee.begin() failed — rebooting.");
    delay(2000);
    ESP.restart();
  }

  Serial.print("Joining network");
  while (!Zigbee.connected()) {
    Serial.print(".");
    delay(500);
  }
  Serial.println("\nConnected. Ready.");
}

void loop() {
  static bool prev = HIGH;
  bool state = digitalRead(BUTTON_PIN);

  if (state == LOW && prev == HIGH && millis() - lastPress > 50) {
    lastPress = millis();
    Serial.println("Button pressed.");
    sendToggle();
  }
  prev = state;
}
