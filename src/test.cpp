#include <Arduino.h>
#include <CurieBLE.h>
#include <CurieIMU.h>

BLEPeripheral blePeripheral;
BLEService fallService("0001");
BLEUnsignedCharCharacteristic fallCharacteristic("0001", BLENotify | BLERead);

volatile unsigned char falls = 0;

void init_bluetooth() {
    // set advertised local name and service UUID:
    blePeripheral.setDeviceName("OldBit");
    blePeripheral.setLocalName("OldBit");
    blePeripheral.setAdvertisedServiceUuid(fallService.uuid());

    // add service and characteristic:
    blePeripheral.addAttribute(fallService);
    blePeripheral.addAttribute(fallCharacteristic);

    blePeripheral.setEventHandler(BLEPeripheralEvent::BLEConnected, [](BLECentral& central) {
        digitalWrite(LED_BUILTIN, HIGH);
    });

    blePeripheral.setEventHandler(BLEPeripheralEvent::BLEDisconnected, [](BLECentral& central) {
        digitalWrite(LED_BUILTIN, LOW);
    });

    //set the initial value for the characeristic:
    fallCharacteristic.setValue(0);

    // begin advertising BLE service:
    blePeripheral.begin();
}

void init_imu() {
    /* Initialise the IMU */
    CurieIMU.begin();
    CurieIMU.attachInterrupt([] {
        if (CurieIMU.getInterruptStatus(CURIE_IMU_SHOCK)) {
            falls++;
        }
    });

    /* Enable Shock Detection */
    CurieIMU.setDetectionThreshold(CURIE_IMU_SHOCK, 4000); // 1.5g = 1500 mg
    CurieIMU.setDetectionDuration(CURIE_IMU_SHOCK, 50);   // 50ms
    CurieIMU.interrupts(CURIE_IMU_SHOCK);
}

void setup() {
    // Setup pins
    pinMode(LED_BUILTIN, OUTPUT);

    // Init System
    init_bluetooth();
    init_imu();

    // Startup completed feedback
    digitalWrite(LED_BUILTIN, HIGH);
    delay(200);
    digitalWrite(LED_BUILTIN, LOW);
}

void loop() {
    delay(100);
    if (falls != fallCharacteristic.value()) {
        fallCharacteristic.setValue(falls);
    }
}
