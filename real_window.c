#include <WiFi.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <Adafruit_SHT31.h>
#include <Servo.h>

const char* ssid = "A2332";
const char* password = "01010202";
const char* mqtt_server = "broker.hivemq.com"; // Token: Smartwindow
const int mqtt_port = 1883;

WiFiClient espClient;
PubSubClient client(espClient);

void setup_wifi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
}

void reconnect() {
  while (!client.connected()) {
    Serial.print("Connecting to MQTT...");
    if (client.connect("ESP32TestClient")) {
      Serial.println("connected");
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
  Serial.println("Type messsages");
}

//Data code: s_window/data
void loop() {
  if (!client.connected()) reconnect();
  client.loop();

  if (Serial.available() > 0) {
    String msg = Serial.readStringUntil('\n');  
    msg.trim();
    if (msg.length() > 0) {
      client.publish("s_window/data", msg.c_str()); 
      Serial.print("Sent message: ");
      Serial.println(msg);
    }
  }
}
