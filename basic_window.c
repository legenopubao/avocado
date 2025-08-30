#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_SHT31.h>
#include <PMS.h>
#include <Servo.h>
#include <ESPmDNS.h>

// ================= Wi-Fi =================
const char* ssid     = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
WebServer server(80);

// ================= 핀/하드웨어 =================
// I2C 기본(ESP32: SDA=21, SCL=22). 필요시 Wire.begin(SDA,SCL) 변경
// PMS UART 핀 지정(보드 따라 조정)
static const int PMS_RX_PIN = 16;  // PMS TX -> ESP32 RX
static const int PMS_TX_PIN = 17;  // PMS RX -> ESP32 TX (보통 미사용)
HardwareSerial& PMS_Serial = Serial2;

Adafruit_SHT31 sht31 = Adafruit_SHT31();
PMS pms(PMS_Serial);
PMS::DATA pmsData;

Servo windowServo;
const int SERVO_PIN = 27;
const int SERVO_OPEN_ANGLE  = 0;
const int SERVO_CLOSE_ANGLE = 90;

// ================= 임계값 =================
#define PM_THRESHOLD    50
#define TEMP_THRESHOLD  28
#define HUM_THRESHOLD   70

// ================= 상태 =================
volatile bool bugDetected = false;  // 핸들러에서 토글
int  currentServoAngle = SERVO_CLOSE_ANGLE;
bool wifiConnected     = false;

// 샘플링 주기 관리
unsigned long lastSampleMs = 0;
const unsigned long SAMPLE_PERIOD_MS = 1000;

// 센서 최신값(EMA나 필터가 필요하면 여기 적용)
float lastTemp = NAN, lastHum = NAN;
int   lastPM25 = 0;

// ================= 유틸 =================
void setServo(int angle) {
  if (angle != currentServoAngle) {
    windowServo.write(angle);
    currentServoAngle = angle;
  }
}

void ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.disconnect();
  WiFi.begin(ssid, password);
  unsigned long t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < 8000) {
    delay(200);
  }
  wifiConnected = (WiFi.status() == WL_CONNECTED);
  if (wifiConnected) {
    Serial.print("IP: "); Serial.println(WiFi.localIP());
  }
}

// ================= HTTP 핸들러 =================
void sendJSON(int code, const String& body) {
  server.sendHeader("Cache-Control", "no-store");
  server.send(code, "application/json", body);
}

String makeDataJSON() {
  String json = "{";
  json += "\"temp\":" + String(lastTemp, 1) + ",";
  json += "\"hum\":"  + String(lastHum, 1)  + ",";
  json += "\"pm25\":" + String(lastPM25)    + ",";
  json += "\"bug\":"  + String(bugDetected ? "true" : "false") + ",";
  json += "\"servo\":" + String(currentServoAngle);
  json += "}";
  return json;
}

void handleRoot() {
  server.sendHeader("Cache-Control", "no-store");
  server.send(200, "text/plain", "스마트 창문 시스템 동작 중");
}

void handleData() {
  sendJSON(200, makeDataJSON());
}

void handleBugOn() {
  bugDetected = true;
  setServo(SERVO_CLOSE_ANGLE);
  sendJSON(200, "{\"ok\":true,\"bug\":true,\"msg\":\"벌레 감지 → 창문 닫힘\"}");
}

void handleBugOff() {
  bugDetected = false;
  // 자동 제어 루프에서 다음 샘플링에 따라 각도 결정
  sendJSON(200, "{\"ok\":true,\"bug\":false,\"msg\":\"벌레 해제 → 자동 제어 복귀\"}");
}

void handleNotFound() {
  sendJSON(404, "{\"ok\":false,\"error\":\"not_found\"}");
}

// ================= 초기화 =================
void setup() {
  Serial.begin(115200);

  // Wi-Fi
  WiFi.mode(WIFI_STA);
  ensureWiFi();

  // mDNS(선택적)
  if (MDNS.begin("smartwindow")) {
    Serial.println("mDNS: http://smartwindow.local/");
  }

  // 웹 서버 라우트
  server.on("/",      HTTP_GET, handleRoot);
  server.on("/data",  HTTP_GET, handleData);
  server.on("/bugOn", HTTP_GET, handleBugOn);
  server.on("/bugOff",HTTP_GET, handleBugOff);
  server.onNotFound(handleNotFound);
  server.begin();

  // I2C / SHT31
  Wire.begin();               // 필요시 Wire.begin(SDA,SCL)
  if (!sht31.begin(0x44)) {
    Serial.println("SHT31 센서 오류");
    // 센서 없을 때도 서버는 계속 띄워두는 편이 디버깅에 유리
  }

  // PMS UART
  PMS_Serial.begin(9600, SERIAL_8N1, PMS_RX_PIN, PMS_TX_PIN);
  // 필요시: pms.passiveMode(); pms.wakeUp();

  // 서보
  windowServo.attach(SERVO_PIN);
  setServo(SERVO_CLOSE_ANGLE);
}

// ================= 메인 루프 =================
void loop() {
  server.handleClient();

  // Wi-Fi 유지(가끔 끊기는 환경 대비)
  static unsigned long lastWiFiChk = 0;
  if (millis() - lastWiFiChk > 5000) {
    lastWiFiChk = millis();
    if (WiFi.status() != WL_CONNECTED) ensureWiFi();
  }

  // 1초 주기로 센서 샘플링 & 제어
  if (millis() - lastSampleMs >= SAMPLE_PERIOD_MS) {
    lastSampleMs = millis();

    // SHT31
    float t = sht31.readTemperature();
    float h = sht31.readHumidity();
    if (!isnan(t)) lastTemp = t;
    if (!isnan(h)) lastHum  = h;

    // PMS (타임아웃을 둔 읽기)
    if (pms.readUntil(pmsData, 1000)) {
      lastPM25 = pmsData.PM_AE_UG_2_5;
    }
    // 벌레 감지 시 무조건 닫힘
    if (bugDetected) {
      setServo(SERVO_CLOSE_ANGLE);
    } else {
      // 간단 자동 제어: 임계 초과 시 열기 / 이하 시 닫기
      if (lastPM25 > PM_THRESHOLD || lastTemp > TEMP_THRESHOLD || lastHum > HUM_THRESHOLD) {
        setServo(SERVO_OPEN_ANGLE);
      } else {
        setServo(SERVO_CLOSE_ANGLE);
      }
    }
  }
}
