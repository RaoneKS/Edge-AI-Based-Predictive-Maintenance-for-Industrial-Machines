#include <Wire.h>

const uint8_t MPU_ADDR = 0x68;

// L298N motor control
const int ENA = 5;
const int IN1 = 7;
const int IN2 = 8;

const int MOTOR_SPEED = 160; // PWM: 0-255

const unsigned long SAMPLE_INTERVAL_US = 10000; // 100 Hz
unsigned long lastSample = 0;

bool writeRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}

bool readAccelerometer(int16_t &ax, int16_t &ay, int16_t &az) {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B);

  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(MPU_ADDR, (uint8_t)6) != 6) return false;

  ax = (int16_t)((Wire.read() << 8) | Wire.read());
  ay = (int16_t)((Wire.read() << 8) | Wire.read());
  az = (int16_t)((Wire.read() << 8) | Wire.read());

  return true;
}

void setup() {
  Serial.begin(115200);

  pinMode(ENA, OUTPUT);
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);

  // Stop motor during initialization
  analogWrite(ENA, 0);
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);

  Wire.begin();
  Wire.setClock(400000);
  delay(500);

  if (!writeRegister(0x6B, 0x00)) {
    Serial.println("ERROR,I2C_INIT");
    return;
  }

  writeRegister(0x1C, 0x00); // +/- 2g
  writeRegister(0x1A, 0x03); // DLPF

  delay(100);

  // Start motor in one direction
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  analogWrite(ENA, MOTOR_SPEED);

  delay(1000);

  Serial.println("timestamp_us,ax_raw,ay_raw,az_raw");
  lastSample = micros();
}

void loop() {
  unsigned long now = micros();

  if (now - lastSample >= SAMPLE_INTERVAL_US) {
    lastSample += SAMPLE_INTERVAL_US;

    int16_t ax, ay, az;

    if (readAccelerometer(ax, ay, az)) {
      Serial.print(now);
      Serial.print(',');
      Serial.print(ax);
      Serial.print(',');
      Serial.print(ay);
      Serial.print(',');
      Serial.println(az);
    }
  }
}
