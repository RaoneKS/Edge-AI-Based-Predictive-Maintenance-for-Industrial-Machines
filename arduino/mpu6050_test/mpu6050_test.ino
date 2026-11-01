#include <Wire.h>

void setup() {
  Serial.begin(115200);
  Wire.begin();
  delay(1000);

  Serial.println("MPU6050 I2C Scanner");

  Wire.beginTransmission(0x68);
  byte error = Wire.endTransmission();

  if (error == 0) {
    Serial.println("Device found at 0x68");

    Wire.beginTransmission(0x68);
    Wire.write(0x75);
    Wire.endTransmission(false);
    Wire.requestFrom(0x68, 1);

    if (Wire.available()) {
      byte id = Wire.read();
      Serial.print("WHO_AM_I: 0x");
      Serial.println(id, HEX);
    }
  } else {
    Serial.println("Device not found at 0x68");
  }

  Wire.beginTransmission(0x69);
  error = Wire.endTransmission();

  if (error == 0) {
    Serial.println("Device also responds at 0x69");
  }
}

void loop() {}
