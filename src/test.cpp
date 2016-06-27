#include <Arduino.h>
#include <CurieBLE.h>
#include <CurieIMU.h>

#include <OneWire.h>
#include <DallasTemperature.h>

#include <LiquidCrystal.h>

#include "pulse.h"

BLEPeripheral blePeripheral;
BLEService fallService("0001");
BLEUnsignedCharCharacteristic fallCharacteristic("0001", BLENotify | BLERead);

#define ONE_WIRE_PORT 2

OneWire oneWire(ONE_WIRE_PORT);
DallasTemperature tempSensor(&oneWire);

LiquidCrystal lcd(13, 12, 11, 10, 9, 8);

volatile unsigned char falls = 0;

void initBluetooth() {
    // set advertised local name and service UUID:
    const char* deviceName = "GeriFit";
    blePeripheral.setDeviceName(deviceName);
    blePeripheral.setLocalName(deviceName);
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

void initIMU() {
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
    // Init Systems
    initBluetooth();
    initIMU();

    // Temperature Sensor
    tempSensor.begin();

    pulse_init();

    // set up the LCD's number of columns and rows:
    lcd.begin(16, 2);
    // Print a message to the LCD.
    lcd.print("GeriFit!");
}

void loop() {
    if (falls != fallCharacteristic.value()) {
        fallCharacteristic.setValue(falls);
    }

    tempSensor.requestTemperatures();

    // set the cursor to column 0, line 1
    // (note: line 1 is the second row, since counting begins with 0):
    lcd.setCursor(0, 1);
    // print the number of seconds since reset:
    lcd.print("BPM: ");
    lcd.print(pulse_bpm());
    lcd.print(" (");
    lcd.print(tempSensor.getTempCByIndex(0));
    lcd.print(")     ");
}
