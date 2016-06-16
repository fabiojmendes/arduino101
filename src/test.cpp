#include <Arduino.h>
#include <CurieBLE.h>

BLEPeripheral blePeripheral;
BLEService ledService("A0E0");
BLEUnsignedCharCharacteristic switchCharacteristic("FEFE", BLERead | BLEWrite);

void init_bluetooth() {
    // set advertised local name and service UUID:
    // blePeripheral.setDeviceName("TestBLE");
    blePeripheral.setLocalName("Led Switch");
    blePeripheral.setAdvertisedServiceUuid(ledService.uuid());

    // add service and characteristic:
    blePeripheral.addAttribute(ledService);
    blePeripheral.addAttribute(switchCharacteristic);

    switchCharacteristic.setEventHandler(BLECharacteristicEvent::BLEWritten, [](BLECentral& central, BLECharacteristic& characteristic) {
        if (switchCharacteristic.value()) {
            Serial.println("LED on");
            digitalWrite(LED_BUILTIN, HIGH);
        } else {
            Serial.println("LED off");
            digitalWrite(LED_BUILTIN, LOW);
        }
    });

    //set the initial value for the characeristic:
    switchCharacteristic.setValue(0);

    // begin advertising BLE service:
    blePeripheral.begin();
}

void setup() {
    pinMode(13, OUTPUT);
    digitalWrite(LED_BUILTIN, HIGH);
    init_bluetooth();
    delay(200);
    digitalWrite(LED_BUILTIN, LOW);
}

void loop() {
    delay(500);
}
