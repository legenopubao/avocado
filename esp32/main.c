#include <PubSubClient.h> //library for MQTT
#include <ArduinoJson.h>  //library for Parsing JSON
#include <WiFi.h>


//Sensor Libraries
#include "Adafruit_SHT31.h"


//Servo Library
#include <ESP32Servo.h>

// HTTP Server
#include <WebServer.h>
//HTTP Library
#include "esp_http_pull.h"

//SHT31
const int SHT31_SDA_PIN = 22;
const int SHT31_SCL_PIN = 21;
Adafruit_SHT31 sht31 = Adafruit_SHT31();
float t;     //온도
float h;     //습도
float pm25;  //PM 2.5
float pm10;  //PM 10
int aqi;    //AQI


//Servo Pin
int servoPin = 25;  
Servo myservo;  

// Water Pump Pin (워터펌프 제어용)
#define WATER_PUMP_PIN 33 // 워터펌프 제어 핀


//WIFI Info -> 임의로 핫스팟 사용
const char* ssid = "A2332";//WIFI SSID
const char* password = "01010202";//WIFI PASS


//MQTT Info
const char* mqttServer = "broker.hivemq.com"; //MQTT URL
const char* mqttUserName = "";  // MQTT username --> 현재는 유저 고유식별 사용X
const char* mqttPwd = "";       // MQTT password
const char* clientID = "esp0001"; // client id (기기 식별하기)


//MQTT Subscribe 주제들
const char* topic_pump = "s_window/pump"; 
const char* topic_aqi = "s_window/aqi";
const char* topic_pm25 = "s_window/pm25";
const char* topic_pm10 = "s_window/pm10";


//Wifi client, mqtt 연결
WiFiClient espClient;
PubSubClient client(espClient);

// Web server (HTTP)
WebServer server(80);


//창문 여닫이 여부: 0=닫힘, 1=열림
int is_window = 1;
char pump = "OFF";
// MQTT로 수신한 bug 상태(라즈베리파이→MQTT→ESP32)
bool bug = false;

//WiFi 연결
void setup_wifi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
}

//창문 닫기
void close_window(){
    /*
  for (int pos = 0; pos <= 180; pos += 10) {
      myservo.write(pos);
      Serial.print("Angle: ");
      Serial.println(pos);
      delay(500);
    }
      */
    Serial.println("Close the window");
}

//창문 열기
void open_window(){
  //myservo.write(0); // 원위치
    Serial.println("Open the window");
}

// 불쾌지수 계산 (재사용)
float di_calculation(float temp, float hum);

// HTTP: /data 핸들러
void handle_http_data() {
  float cur_temp = sht31.readTemperature();
  float cur_hum = sht31.readHumidity();
  float di = (!isnan(cur_temp) && !isnan(cur_hum)) ? di_calculation(cur_temp, cur_hum) : 0.0f;

  StaticJsonDocument<256> doc;
  doc["pm25"] = pm25;
  doc["pm10"] = pm10;
  doc["temperature"] = isnan(cur_temp) ? 0.0 : cur_temp;
  doc["humidity"] = isnan(cur_hum) ? 0.0 : cur_hum;
  doc["di"] = di;
  doc["bug"] = bug; // MQTT로부터 받은 최신 bug 상태 반영
  doc["window"] = (is_window == 1);
  doc["weather"] = "맑음";
  doc["timestamp"] = millis();

  String resp;
  serializeJson(doc, resp);
  server.send(200, "application/json", resp);
}

// HTTP: /control 핸들러
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
  if (strcmp(command, "ON") == 0 || strcmp(command, "window_close") == 0) {
    close_window();
    is_window = 0;
  } else if (strcmp(command, "OFF") == 0 || strcmp(command, "window_open") == 0) {
    open_window();
    is_window = 1;
  } else if (strcmp(command, "window_toggle") == 0) {
    if (is_window == 1) { close_window(); is_window = 0; } else { open_window(); is_window = 1; }
  } else if (strcmp(command, "bug_on") == 0) {
    bug = true;
    Serial.println("Bug detection ON");
  } else if (strcmp(command, "bug_off") == 0) {
    bug = false;
    Serial.println("Bug detection OFF");
  }

  server.send(200, "application/json", "{\"ok\":true}");
}

//MQTT서버 연결
void reconnect() {
  while (!client.connected()) {
    if (client.connect(clientID, mqttUserName, mqttPwd)) {
      Serial.println("MQTT connected");

      client.subscribe(topic_pump);
      Serial.println("Subscribed Pump");

      client.subscribe(topic_aqi);
      Serial.println("Subscribed AQI");

      client.subscribe(topic_pm25);
      Serial.println("Subscriebd PM 2.5");

      client.subscribe(topic_pm10);
      Serial.println("Subscriebd PM10");
    }
    else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(1000);  // wait 5sec and retry
    }
  }
}

//불쾌지수 계산
float di_calculation(float temp, float hum){
  return 0.81*temp + 0.01*hum * (0.99 * temp - 14.3) + 46.3;
}

//우선순위 결정
void  priority_decider(int aqi, float pm_25, float pm_10){

  float calc_temp = sht31.readTemperature();
  float calc_hum = sht31.readHumidity();

  if (!isnan(calc_temp)) {
    Serial.print("Temp *C = "); Serial.print(calc_temp); Serial.print("\t");
  } else { 
    Serial.println("Failed to read temperature");
  }
  
  if (!isnan(calc_hum)) {
    Serial.print("Hum. % = "); Serial.println(calc_hum);
  } else { 
    Serial.println("Failed to read humidity");
  }

  float di_in = di_calculation(calc_temp, calc_hum);

  if(pm_25>35 || pm_10>80){
    close_window(); //미세먼지 나쁨으로 닫기
    is_window = 0;

  }else if(di_in<76) {
    close_window(); //불쾌지수 76이하(쾌적)이므로 닫기
    is_window = 0;

  }else{
    open_window(); //벌레없고, 미세먼지 안좋고, 불쾌지수 높으므로 열기. 
    is_window = 1;
  }

}

void activatePump(){
  Serial.println("=== 워터펌프 작동 시작 ===");
  // 워터펌프 작동 (HIGH = ON, LOW = OFF)
  digitalWrite(WATER_PUMP_PIN, HIGH);
  Serial.println("워터펌프 ON - 벌레 제거를 위한 물 분사 시작");
  // 3초간 물 분사 (벌레 제거 효과)
  delay(3000);
  // 워터펌프 정지
  digitalWrite(WATER_PUMP_PIN, LOW);
  Serial.println("워터펌프 OFF - 물 분사 완료");
  Serial.println("=== 워터펌프 작동 완료 ===");
}

//메시지 수신 및 작동 명령
void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived in topic: ");
  Serial.println(topic);

  String data = "";
  for (int i = 0; i < length; i++) {
    data += (char)payload[i];
  }
  data.trim();
  Serial.print("Message: ");
  Serial.println(data);

  if (strcmp(topic, "s_window/aqi") == 0) { //AQI 정보 받기
    aqi = data.toInt();
    Serial.print("Updated AQI: "); Serial.println(aqi);
  }
  else if (strcmp(topic, "s_window/pm25") == 0) {  //PM2.5 정보 받기
    pm25 = data.toFloat();
    Serial.print("Updated PM2.5: "); Serial.println(pm25);
  }
  else if (strcmp(topic, "s_window/pm10") == 0) {  //PM10 정보 받기
    pm10 = data.toFloat();
    Serial.print("Updated PM10: "); Serial.println(pm10);
  }
  else if (strcmp(topic, "s_window/pump") == 0) {  //Pump 작동 여부

    if (data.equals("ON")) {  //벌레 일정 수 이상 감지
      Serial.println("Pump ON -> Servo 동작 & LED 켜기");
      is_window = 0;
      close_window();
      activatePump();
      bug = true; // bug 감지
    } 
    else if (data.equals("OFF")) {  //벌레x, 센서로 여닫이 판단
      Serial.println("Pump OFF -> 우선순위 판단 실행");
      bug = false; // bug 해제
      priority_decider(aqi, pm25, pm10);
    }
  }
}



void setup() {
  Serial.begin(115200);

  //Servo Setup
  myservo.attach(servoPin, 500, 2500);  

  pinMode(LED, OUTPUT);
  digitalWrite(LED, LOW); // 초기 OFF
  
  // 워터펌프 핀 초기화
  pinMode(WATER_PUMP_PIN, OUTPUT);
  digitalWrite(WATER_PUMP_PIN, LOW); // 초기 OFF

  Wire.begin(SHT31_SDA_PIN, SHT31_SCL_PIN);

  setup_wifi();

  client.setServer(mqttServer, 1883); //MQTT Setup
  client.setCallback(callback); //MQTT 수신 함수 부르기

  if (!sht31.begin(0x44)) {  //SHT 센서 연결 오류 시
    Serial.println("Couldn't find SHT31");
    while (1) delay(1);
  }

  // HTTP 서버 라우트 등록
  server.on("/data", HTTP_GET, handle_http_data);
  server.on("/control", HTTP_POST, handle_http_control);
  server.begin();
}



void loop() {
  if (!client.connected()) {  //연결 계속 재시도
    reconnect(); 
  }
  client.loop(); //MQTT 수신 유지/반복

  // HTTP 요청 처리
  server.handleClient();

  //보내는 온습도
  float send_temp = sht31.readTemperature(); 
  float send_hum = sht31.readHumidity();

  //**********************************8

  delay(2000);
