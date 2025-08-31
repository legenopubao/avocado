#include <Wire.h>
#include <HardwareSerial.h>
#include <Servo.h>
#include "Adafruit_SHT31.h"
#include "PMS.h"   //필요한 라이브러리 헤더파일 설치

// 핀 정의 및 객체 생성
// PMS5003 (미세먼지 센서)
const int PMS_RX_PIN = 17;
const int PMS_TX_PIN = 16;
PMS pms(Serial2); // ESP32의 UART2를 사용 (GPIO16/17)

// SHT31 (온습도 센서)
// I2C 통신 (기본 핀: GPIO21, GPIO22)
const int SHT31_SDA_PIN = 21;
const int SHT31_SCL_PIN = 22;
Adafruit_SHT31 sht31 = Adafruit_SHT31();

// 서보 모터
const int SERVO_PWM_PIN = 25;
Servo myServo;

void setup() {
  // 시리얼 모니터 초기화 
  Serial.begin(115200);
  
  // PMS5003 센서 시리얼 통신 설정
  // Serial2.begin(baudrate, protocol, RX_pin, TX_pin)
  Serial2.begin(9600, SERIAL_8N1, PMS_RX_PIN, PMS_TX_PIN);
  pms.begin();

  // SHT31 센서 I2C 통신 설정
  // Wire.begin(SDA_pin, SCL_pin)
  Wire.begin(SHT31_SDA_PIN, SHT31_SCL_PIN);  //통신 시작
  if (!sht31.begin(0x44)) { // 0x44는 SHT31의 기본 I2C 주소
    Serial.println("SHT31 센서 초기화 실패. 회로를 확인해주세요!");
    while (1); // 초기화 실패 시 무한 대기
  }

  // 서보 모터 핀 연결
  myServo.attach(SERVO_PWM_PIN);
}

void loop() {
  // 센서 데이터 읽기 및 서보 제어 코드를 여기에 추가
}