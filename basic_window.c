/**
 * 스마트 창문 제어 시스템 - ESP32 기반
 * 
 * 기능:
 * - SHT31 온습도 센서로 실내 환경 모니터링
 * - PMS5003 미세먼지 센서로 공기질 측정
 * - 서보모터로 창문 자동 제어
 * - 웹 인터페이스를 통한 원격 제어 및 모니터링
 * - 벌레 감지 시 긴급 창문 닫기 기능
 * 
 * 하드웨어 구성:
 * - ESP32 개발보드
 * - SHT31 온습도 센서 (I2C)
 * - PMS5003 미세먼지 센서 (UART)
 * - JX-PDI 서보모터 (창문 제어용)
 */

#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_SHT31.h>
#include <PMS.h>
#include <Servo.h>
#include <ESPmDNS.h>

// ==================== 네트워크 설정 ====================
const char* ssid = "YOUR_WIFI_SSID";        // WiFi SSID 설정
const char* password = "YOUR_WIFI_PASSWORD"; // WiFi 비밀번호 설정
WebServer server(80);                        // 웹서버 객체 (포트 80)

// ==================== 하드웨어 핀 설정 ====================
// I2C 기본 핀 (ESP32: SDA=21, SCL=22). 필요시 Wire.begin(SDA,SCL) 변경
// PMS UART 핀 지정 (보드에 따라 조정 필요)
static const int PMS_RX_PIN = 16; // PMS TX -> ESP32 RX
static const int PMS_TX_PIN = 17; // PMS RX -> ESP32 TX (보통 미사용)
HardwareSerial& PMS_Serial = Serial2;

// ==================== 센서 객체 초기화 ====================
Adafruit_SHT31 sht31 = Adafruit_SHT31();    // 온습도 센서 객체
PMS pms(PMS_Serial);                        // 미세먼지 센서 객체
PMS::DATA pms_data;                         // 미세먼지 데이터 구조체

// ==================== 서보모터 설정 ====================
Servo windowServo;                          // 서보모터 객체
const int SERVO_PIN = 27;                   // 서보모터 제어 핀
const int SERVO_OPEN_ANGLE = 0;             // 창문 열림 각도
const int SERVO_CLOSE_ANGLE = 90;           // 창문 닫힘 각도 (오타 수정: sERVO -> SERVO)

// ==================== 환경 임계값 설정 ====================
#define PM_THRESHOLD 50    // 미세먼지 PM2.5 임계값 (μg/m³)
#define TEMP_THRESHOLD 28  // 온도 임계값 (°C)
#define HUM_THRESHOLD 70   // 습도 임계값 (%)

// ==================== 시스템 상태 변수 ====================
volatile bool bugDetected = false;          // 벌레 감지 상태 (웹 핸들러에서 on/off 제어)
int currentServoAngle = SERVO_CLOSE_ANGLE;  // 현재 서보모터 각도
bool wifiConnected = false;                 // WiFi 연결 상태

// ==================== 샘플링 및 타이밍 관리 ====================
unsigned long lastSampleMs = 0;             // 마지막 센서 샘플링 시간
const unsigned long SAMPLE_INTERVAL = 1000; // 센서 샘플링 간격 (1초)
unsigned long lastWifiCheckMs = 0;          // 마지막 WiFi 체크 시간
const unsigned long WIFI_CHECK_INTERVAL = 5000; // WiFi 체크 간격 (5초)

// ==================== 센서 데이터 저장 ====================
// EMA나 필터가 필요하면 여기에 적용
float lastTemp = NAN;   // 마지막 온도 값
float lastHum = NAN;    // 마지막 습도 값
int lastPM25 = 0;       // 마지막 PM2.5 값

// ==================== 유틸리티 함수 ====================

/**
 * 서보모터 각도 설정 함수
 * @param angle 설정할 각도 (0-180)
 * 
 * 현재 각도와 다를 때만 서보모터를 움직여 불필요한 동작을 방지
 */
void setServo(int angle) {
    if (angle != currentServoAngle) {
        windowServo.write(angle);
        currentServoAngle = angle;
        Serial.printf("서보모터 각도 변경: %d°\n", angle);
    }
}

/**
 * WiFi 연결 상태 확인 및 재연결 함수
 * 
 * WiFi 연결이 끊어진 경우 자동으로 재연결을 시도
 * 최대 8초간 연결 시도 후 타임아웃
 */
void ensureWifi() {
    if (WiFi.status() == WL_CONNECTED) return;
    
    Serial.println("WiFi 재연결 시도 중...");
    WiFi.disconnect();
    WiFi.begin(ssid, password);
    
    unsigned long timeout = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - timeout < 8000) {
        delay(200);
        Serial.print(".");
    }
    Serial.println();
    
    wifiConnected = (WiFi.status() == WL_CONNECTED);
    if (wifiConnected) {
        Serial.printf("WiFi 연결 성공! IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("WiFi 연결 실패");
    }
}

// ==================== HTTP 응답 유틸리티 ====================

/**
 * JSON 형식으로 HTTP 응답 전송
 * @param code HTTP 상태 코드
 * @param body JSON 응답 본문
 */
void sendJSON(int code, const String& body) {
    server.sendHeader("Cache-Control", "no-store");
    server.send(code, "application/json", body);
}

/**
 * 센서 데이터를 JSON 형식으로 변환
 * @return JSON 문자열
 */
String makeDataJSON() {
    String json = "{";
    json += "\"temp\":" + String(lastTemp, 1) + ",";
    json += "\"hum\":" + String(lastHum, 1) + ",";
    json += "\"pm25\":" + String(lastPM25) + ",";
    json += "\"bug\":" + String(bugDetected ? "true" : "false") + ",";
    json += "\"servo\":" + String(currentServoAngle) + ",";
    json += "\"wifi\":" + String(wifiConnected ? "true" : "false");
    json += "}";
    return json;
}

// ==================== HTTP 핸들러 함수들 ====================

/**
 * 루트 페이지 핸들러
 * 시스템 상태 확인용 간단한 메시지 반환
 */
void handleRoot() {
    server.sendHeader("Cache-Control", "no-store");
    server.send(200, "text/plain", "스마트 창문 시스템 동작 중");
}

/**
 * 404 에러 핸들러
 * 존재하지 않는 페이지 요청 시 처리
 */
void handleNotFound() {
    server.send(404, "text/plain", "페이지를 찾을 수 없습니다.");
}

/**
 * 센서 데이터 요청 핸들러
 * 현재 센서 값들을 JSON 형식으로 반환
 */
void handleData() {
    sendJSON(200, makeDataJSON());
}

/**
 * 벌레 감지 활성화 핸들러
 * 벌레 감지 모드를 켜고 창문을 닫음
 */
void handleBugOn() {
    bugDetected = true;
    setServo(SERVO_CLOSE_ANGLE);
    sendJSON(200, "{\"ok\":true,\"bug\":true,\"msg\":\"벌레 감지 -> 창문 닫힘\"}");
}

/**
 * 벌레 감지 비활성화 핸들러
 * 벌레 감지 모드를 끄고 자동 제어로 복귀
 */
void handleBugOff() {
    bugDetected = false;
    // 자동 제어 루프에서 다음 샘플링에 따라 각도 결정
    sendJSON(200, "{\"ok\":true,\"bug\":false,\"msg\":\"벌레 해제 -> 자동 제어 복귀\"}");
}

// ==================== 시스템 초기화 ====================

/**
 * 시스템 초기화 함수
 * WiFi, 웹서버, 센서, 서보모터 등을 초기화
 */
void setup() {
    Serial.begin(115200);
    Serial.println("스마트 창문 시스템 시작...");
    
    // ==================== WiFi 초기화 ====================
    WiFi.mode(WIFI_STA);
    ensureWifi();
    
    // ==================== mDNS 설정 (선택적) ====================
    if (MDNS.begin("smartwindow")) {
        Serial.println("mDNS 시작: https://smartwindow.local/");
    }
    
    // ==================== 웹서버 라우트 설정 ====================
    server.on("/", HTTP_GET, handleRoot);
    server.on("/data", HTTP_GET, handleData);
    server.on("/bugOn", HTTP_GET, handleBugOn);
    server.on("/bugOff", HTTP_GET, handleBugOff);
    server.onNotFound(handleNotFound);
    server.begin();
    Serial.println("웹서버 시작됨");
    
    // ==================== I2C 및 SHT31 센서 초기화 ====================
    Wire.begin();  // 필요시 Wire.begin(SDA, SCL)로 핀 변경
    if (!sht31.begin(0x44)) {
        Serial.println("SHT31 센서 초기화 실패");
        // 센서가 없어도 서버는 계속 동작하도록 유지 (디버깅에 유리)
    } else {
        Serial.println("SHT31 센서 초기화 성공");
    }
    
    // ==================== PMS 센서 초기화 ====================
    PMS_Serial.begin(9600, SERIAL_8N1, PMS_RX_PIN, PMS_TX_PIN);
    // 필요시 pms.passiveMode(); pms.wakeUp();
    Serial.println("PMS 센서 초기화 완료");
    
    // ==================== 서보모터 초기화 ====================
    windowServo.attach(SERVO_PIN);
    setServo(SERVO_CLOSE_ANGLE);
    Serial.println("서보모터 초기화 완료");
    
    Serial.println("시스템 초기화 완료!");
}

// ==================== 메인 루프 ====================

/**
 * 메인 루프 함수
 * 웹서버 클라이언트 처리, 센서 읽기, 자동 제어 로직 수행
 */
void loop() {
    // 웹서버 클라이언트 요청 처리
    server.handleClient();
    
    // WiFi 연결 상태 주기적 확인 (5초마다)
    if (millis() - lastWifiCheckMs > WIFI_CHECK_INTERVAL) {
        lastWifiCheckMs = millis();
        ensureWifi();
    }
    
    // 센서 샘플링 및 제어 로직 (1초마다)
    if (millis() - lastSampleMs > SAMPLE_INTERVAL) {
        lastSampleMs = millis();
        
        // ==================== SHT31 온습도 센서 읽기 ====================
        float temp = sht31.readTemperature();
        float hum = sht31.readHumidity();
        
        if (!isnan(temp)) {
            lastTemp = temp;
            Serial.printf("온도: %.1f°C\n", temp);
        }
        if (!isnan(hum)) {
            lastHum = hum;
            Serial.printf("습도: %.1f%%\n", hum);
        }
        
        // ==================== PMS 미세먼지 센서 읽기 ====================
        if (pms.read(pms_data, 1000)) {  // 1초 타임아웃
            lastPM25 = pms_data.PM_AE_UG_2_5;
            Serial.printf("PM2.5: %d μg/m³\n", lastPM25);
        }
        
        // ==================== 자동 제어 로직 ====================
        if (bugDetected) {
            // 벌레 감지 시 무조건 창문 닫기
            setServo(SERVO_CLOSE_ANGLE);
            Serial.println("벌레 감지 모드: 창문 닫힘");
        } else {
            // 자동 제어: 임계값 초과 시 창문 열기, 이하 시 닫기
            bool shouldOpen = (lastPM25 > PM_THRESHOLD || 
                              lastTemp > TEMP_THRESHOLD || 
                              lastHum > HUM_THRESHOLD);
            
            if (shouldOpen) {
                setServo(SERVO_OPEN_ANGLE);
                Serial.println("자동 제어: 창문 열림 (임계값 초과)");
            } else {
                setServo(SERVO_CLOSE_ANGLE);
                Serial.println("자동 제어: 창문 닫힘 (임계값 이하)");
            }
        }
    }
}
