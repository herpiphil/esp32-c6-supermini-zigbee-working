// =============================================================
// Date:    2026-04-09
// Project: supermini_tfx — Z2M External Converter
// Notes:   Copied unchanged from C6Test2. Maps ZCL On/Off
//          commands from the ESP32-C6 button to 'action' events
//          in Z2M / HA.
//
//          Install:
//          1. Copy to /config/zigbee2mqtt/c6_button_switch.js
//          2. Add to configuration.yaml:
//               external_converters:
//                 - c6_button_switch.js
//          3. Restart Zigbee2MQTT.
// =============================================================

const definition = {
    zigbeeModel: ['C6ButtonSwitch'],
    model:       'C6ButtonSwitch',
    vendor:      'Custom',
    description: 'ESP32-C6 Zigbee button switch',

    fromZigbee: [
        {
            cluster: 'genOnOff',
            type:    ['commandToggle', 'commandOn', 'commandOff'],
            convert: (model, msg, publish, options, meta) => {
                const map = {
                    commandToggle: 'toggle',
                    commandOn:     'on',
                    commandOff:    'off',
                };
                const action = map[msg.type];
                if (action) return { action };
            },
        },
    ],

    toZigbee: [],

    exposes: [
        {
            name:        'action',
            label:       'Action',
            access:      1,
            type:        'enum',
            values:      ['toggle', 'on', 'off'],
            description: 'Button press action',
        },
    ],
};

module.exports = definition;
