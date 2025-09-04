#include <WiFi.h>
#include <Wire.h>
#include <PubSubClient.h>   // MQTT
#include <ArduinoJson.h>    // JSON
#include "Adafruit_SHT31.h" // SHT31
#include <ESP32Servo.h>     // Servo
#include <WebServer.h>      // HTTP

// If you actually need this header, keep it. Otherwise you can remove the include.
// #include "esp_http_pull.h"

// ---------- Pins / Hardware ----------
const int SHT31_SDA_PIN = 21;   // ESP32 default SDA
const int SHT31_SCL_PIN = 22;   // ESP32 default SCL
const int SERVO_PIN      = 25;
const int WATER_PUMP_PIN = 33;  // water pump

// ---------- Globals ----------
Adafruit_SHT31 sht31;
Servo           myservo;
WebServer       server(8000);

float pm25 = 0.0f;
float pm10 = 0.0f;
int   aqi  = 0;
int   is_window = 0;   // 0=closed, 1=open
bool  bug = false;
bool  hasSHT31 = false;

// ---------- Wi-Fi ----------
const char* ssid     = "Hahhhh";
const char* password = "12051205";

// ---------- MQTT ----------
const char* mqttServer   = "broker.hivemq.com";
const char* mqttUserName = "";
const char* mqttPwd      = "";
const char* clientID     = "esp0001";

const char* topic_pump = "s_window/pump";
const char* topic_aqi  = "s_window/aqi";
const char* topic_pm25 = "s_window/pm25";
const char* topic_pm10 = "s_window/pm10";

WiFiClient       espClient;
PubSubClient     client(espClient);

// ---------- PumpInfo ------------
unsigned long pumpStart = 0;
bool pumpActive = false;

// ---------- Forward Declarations ----------
void setup_wifi();
void close_window();
void open_window();
float di_calculation(float temp, float hum);
void handle_http_data();
void handle_http_control();
void reconnect();
void priority_decider(int aqi, float pm_25, float pm_10);
void activatePump();
void callback(char* topic, byte* payload, unsigned int length);
void i2cScan();

  // ---------- Utility ----------
  float di_calculation(float temp, float hum) {
    return 0.81f * temp + 0.01f * hum * (0.99f * temp - 14.3f) + 46.3f;
  }

  // ---------- Wi-Fi ----------
  void setup_wifi() {
    Serial.print("Connecting to WiFi");
    WiFi.mode(WIFI_STA);
    WiFi.setSleep(false);
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
      delay(500);
      Serial.print(".");
    }
    Serial.println("\nWiFi connected!");
    Serial.print("WiFi SSID: ");   Serial.println(ssid);
    Serial.print("IP Address: ");  Serial.println(WiFi.localIP());
    Serial.print("Gateway: ");     Serial.println(WiFi.gatewayIP());
    Serial.print("Subnet: ");      Serial.println(WiFi.subnetMask());
  }

     // ---------- Window Control ----------
void open_window() {
  // 이미 열려있으면 중복 실행 방지
  if (is_window == 1) {
    Serial.println("⚠️ Window already open, skipping");
    return;
  }
  
  Serial.println("🔄 Opening window...");
  // 서보모터를 0도로 이동 (창문 열기)
  for (int i = 90; i >= 0; i--) {
    myservo.write(i);  // 90도 → 0도
    delay(40);
  }
  is_window = 1;  // 루프 밖에서 한 번만 설정
  Serial.println("✅ Window opened");
}
void close_window() {
  // 이미 닫혀있으면 중복 실행 방지
  if (is_window == 0) {
    Serial.println("⚠️ Window already closed, skipping");
    return;
  }
  
  Serial.println("🔄 Closing window...");
  // 서보모터를 90도로 이동 (창문 닫기)
  for (int i = 0; i <= 90; i++) {
    myservo.write(i);  // 0도 → 90도
    delay(40);
  }
  is_window = 0;  // 루프 밖에서 한 번만 설정
  Serial.println("✅ Window closed");
}

// ---------- HTTP Handlers (define ONCE) ----------
void handle_http_data() {
  float cur_temp = NAN, cur_hum = NAN, di = 0.0f;

  if (hasSHT31) {
    cur_temp = sht31.readTemperature();
    cur_hum  = sht31.readHumidity();
    if (!isnan(cur_temp) && !isnan(cur_hum)) {
      di = di_calculation(cur_temp, cur_hum);
    }
  }

  StaticJsonDocument<256> doc;
   doc["pm25"]        = pm25;
   doc["pm10"]        = pm10;
   doc["temperature"] = isnan(cur_temp) ? 0.0 : cur_temp;
   doc["humidity"]    = isnan(cur_hum)  ? 0.0 : cur_hum;
   doc["di"]          = di;
   doc["bug"]         = bug;
   doc["window"]      = (is_window == 1);
   doc["sensor_control_enabled"] = !bug;  // 벌레 감지 시 센서 제어 비활성화
   doc["timestamp"]   = millis();

  String resp;
  serializeJson(doc, resp);
  server.send(200, "application/json", resp);
}

void handle_http_control() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"ok\":false,\"error\":\"no body\"}");
    return;
  }

  StaticJsonDocument<128> doc;
  DeserializationError err = deserializeJson(doc, server.arg("plain"));
  if (err) {
    server.send(400, "application/json", "{\"ok\":false,\"error\":\"bad json\"}");
    return;
  }

  const char* command = doc["command"] | "";
  Serial.print("HTTP command: "); Serial.println(command);

     if (strcmp(command, "ON") == 0 || strcmp(command, "window_close") == 0) {
     close_window(); is_window = 0;
   } else if (strcmp(command, "OFF") == 0 || strcmp(command, "window_open") == 0) {
     open_window();  is_window = 1;
   } else if (strcmp(command, "window_toggle") == 0) {
     if (is_window == 1) { close_window(); is_window = 0; }
     else                { open_window();  is_window = 1; }
   } else if (strcmp(command, "bug_on") == 0) {
     bug = true;  
     Serial.println("=== Bug detection ON - Sensor control disabled ===");
     Serial.println("창문이 벌레 감지로 인해 닫혀있습니다. 센서 제어가 중단됩니다.");
   } else if (strcmp(command, "bug_off") == 0) {
     bug = false; 
     Serial.println("=== Bug detection OFF - Sensor control enabled ===");
     Serial.println("벌레 감지 해제. 센서 기반 창문 제어가 재개됩니다.");
     // 벌레 감지 해제 시 우선순위 판단 실행
     Serial.println("Execute priority decider after bug detection OFF");
     priority_decider(aqi, pm25, pm10);
   }

  server.send(200, "application/json", "{\"ok\":true}");
}

// ---------- MQTT ----------
void reconnect() {
  while (!client.connected()) {
    if (client.connect(clientID, mqttUserName, mqttPwd)) {
      Serial.println("MQTT connected");
      client.subscribe(topic_pump); Serial.println("Subscribed Pump");
      client.subscribe(topic_aqi);  Serial.println("Subscribed AQI");
      client.subscribe(topic_pm25); Serial.println("Subscribed PM2.5");
      client.subscribe(topic_pm10); Serial.println("Subscribed PM10");
    } else {
      Serial.print("failed, rc="); Serial.print(client.state());
      Serial.println(" try again in 1 second");
      delay(1000);
    }
  }
}

 void priority_decider(int aqi, float pm_25, float pm_10) {
   Serial.println("=== Priority decider started ===");
   
   // 벌레 감지 상태 확인 - 벌레 감지 중에는 센서 제어 완전 중단
   if (bug) {
     Serial.println("🚫 Bug detected - Sensor control DISABLED");
     Serial.println("창문이 벌레 감지로 인해 닫혀있습니다. 센서 제어가 중단됩니다.");
     Serial.println("Flutter 앱에서 '벌레 감지 OFF' 버튼을 눌러야 센서 제어가 재개됩니다.");
     return;
   }
   
   Serial.println("✅ Bug not detected - Sensor control ENABLED");

   float calc_temp = NAN, calc_hum = NAN;

   if (hasSHT31) {
     calc_temp = sht31.readTemperature();
     calc_hum  = sht31.readHumidity();
   }

   if (!isnan(calc_temp)) { Serial.print("Temp C = "); Serial.print(calc_temp); Serial.print("\t"); }
   else                   { Serial.println("Temp read failed"); }

   if (!isnan(calc_hum))  { Serial.print("Hum %  = ");  Serial.println(calc_hum); }
   else                   { Serial.println("Hum read failed"); }

   float di_in = (!isnan(calc_temp) && !isnan(calc_hum)) ? di_calculation(calc_temp, calc_hum) : 0.0f;
   Serial.print("DI: "); Serial.println(di_in);
   Serial.print("PM2.5: "); Serial.print(pm_25); Serial.print(", PM10: "); Serial.println(pm_10);

   if (pm_25 > 35 || pm_10 > 80) { 
     Serial.println("PM2.5 or PM10 is bad -> close the window");
     close_window(); is_window = 0; 
   }
   else if (di_in < 76) { 
     Serial.println("DI is comfortable -> close the window");
     close_window(); is_window = 0; 
   }
   else { 
     Serial.println("Ventilation needed -> open the window");
     open_window(); is_window = 1;  
   }
   
   Serial.println("Priority decider done");
 }

void activatePump() {
  digitalWrite(WATER_PUMP_PIN, HIGH);
  pumpStart = millis();
  pumpActive = true;
  Serial.println("Water pump ON - spraying");
}

void handlePump() {
  if (pumpActive && millis() - pumpStart >= 3000) {
    digitalWrite(WATER_PUMP_PIN, LOW);
    pumpActive = false;
    Serial.println("Water pump OFF - done");
  }
}
void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message topic: "); Serial.println(topic);

  String data;
  data.reserve(length);
  for (unsigned int i = 0; i < length; i++) data += (char)payload[i];
  data.trim();
  Serial.print("Message: "); Serial.println(data);

  if      (strcmp(topic, "s_window/aqi")  == 0) { aqi  = data.toInt();   Serial.print("Updated AQI: ");  Serial.println(aqi);  }
  else if (strcmp(topic, "s_window/pm25") == 0) { pm25 = data.toFloat(); Serial.print("Updated PM2.5: ");Serial.println(pm25); }
  else if (strcmp(topic, "s_window/pm10") == 0) { pm10 = data.toFloat(); Serial.print("Updated PM10: "); Serial.println(pm10); }
     else if (strcmp(topic, "s_window/pump") == 0) {
     // 중복 메시지 처리 방지
     static String lastPumpState = "";
     String currentPumpState = String(data);
     
     if (lastPumpState == currentPumpState) {
       Serial.println("🔄 Duplicate pump message ignored: " + currentPumpState);
       return;
     }
     
     lastPumpState = currentPumpState;
     Serial.println("📨 New pump message received: " + currentPumpState);
     
     if (data.equals("ON")) {
       Serial.println("=== MQTT: Bug detected, close window and activate pump ===");
       is_window = 0; 
       close_window();     // 창문 닫기
       activatePump(); 
       bug = true;
       Serial.println("Bug detected: true - Sensor control DISABLED");
       Serial.println("창문이 벌레 감지로 인해 닫혀있습니다. 센서 제어가 중단됩니다.");
     } else if (data.equals("OFF")) {
       Serial.println("=== MQTT: Bug detection OFF ===");
       bug = false; 
       Serial.println("Bug detected: false - Sensor control ENABLED");
       Serial.println("벌레 감지 해제. 센서 기반 창문 제어가 재개됩니다.");
       
       // 워터펌프 완료 후 5초 대기 (벌레 완전 제거 확인)
       Serial.println("Wait 5 seconds and run priority decider");
       delay(5000);
       
       Serial.println("Execute priority decider");
       priority_decider(aqi, pm25, pm10);
     }
   }
}

// ---------- Optional: I2C scanner ----------
void i2cScan() {
  Serial.println("I2C scan start");
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.print("Found device at 0x");
      if (addr < 16) Serial.print("0");
      Serial.println(addr, HEX);
      delay(2);
    }
  }
  Serial.println("I2C scan done");
}

// ---------- Setup / Loop ----------
void setup() {
  Serial.begin(115200, SERIAL_8N1);
  delay(300);

  // Servo
  myservo.attach(SERVO_PIN, 500, 2500);

  // Water pump
  pinMode(WATER_PUMP_PIN, OUTPUT);
  digitalWrite(WATER_PUMP_PIN, LOW);

  // I2C
  Wire.begin(SHT31_SDA_PIN, SHT31_SCL_PIN);
  Wire.setClock(100000); // 100kHz for stability

  setup_wifi();

  client.setServer(mqttServer, 1883);
  client.setCallback(callback);

  // Try SHT31 on both common addresses
  hasSHT31 = sht31.begin(0x44);
  if (!hasSHT31) {
    Serial.println("SHT31 @0x44 not found, trying 0x45...");
    hasSHT31 = sht31.begin(0x45);
  }
  if (!hasSHT31) {
    Serial.println("WARN: SHT31 not found. Continuing without sensor.");
    // i2cScan(); // uncomment if you want to scan the bus once
  }

  // HTTP routes
  server.on("/",        HTTP_GET,  [](){ server.send(200, "text/plain", "ok"); });
  server.on("/data",    HTTP_GET,  handle_http_data);
  server.on("/control", HTTP_POST, handle_http_control);
  server.begin();

  Serial.println("HTTP server started!");
  Serial.print("HTTP URL: http://"); Serial.print(WiFi.localIP()); Serial.println(":8000");
  Serial.println("Endpoints: /, /data, /control");
  Serial.println("========================");
}

void loop() {
  if (!client.connected()) reconnect();
  client.loop();

  server.handleClient();

  handlePump();

  // Optional periodic status
  static unsigned long lastStatus = 0;
  if (millis() - lastStatus > 10000) {
    Serial.println("=== HTTP server status ===");
    Serial.print("WiFi: ");  Serial.println(WiFi.status() == WL_CONNECTED ? "connected" : "disconnected");
    Serial.print("IP: ");    Serial.println(WiFi.localIP());
    Serial.print("HTTP: ");  Serial.println("http://" + WiFi.localIP().toString() + ":8000");
    Serial.println("========================");
    lastStatus = millis();
  }

  delay(2); // keep loop responsive
}
