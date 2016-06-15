#include <Arduino.h>

const int blink_delay = 250;

void setup() {
    pinMode(13, OUTPUT);
    Serial.begin(9600);
}

void loop() {
    Serial.println("Toggle 1!");
    digitalWrite(13, HIGH);
    delay(blink_delay);
    Serial.println("Toggle 0!");
    digitalWrite(13, LOW);
    delay(blink_delay);
}
