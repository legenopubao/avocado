#!/usr/bin/python
# A simple script to get air quality data from OpenWeatherMap and print to the console.
#
import requests
import os
import time
from dotenv import load_dotenv
import paho.mqtt.publish as publish

# .env 파일 로드
load_dotenv()

# 환경변수에서 설정 가져오기
settings = {
    'api_key': os.getenv('OPENWEATHER_API_KEY'),  # .env 파일에서 API 키 가져오기
    'lat': os.getenv('LATITUDE', '37.5665'),     # .env 파일에서 위도 가져오기 (기본값: 서울)
    'lon': os.getenv('LONGITUDE', '126.9780')    # .env 파일에서 경도 가져오기 (기본값: 서울)
}

# MQTT 설정
mqtt_broker = os.getenv('MQTT_BROKER', 'broker.hivemq.com')
mqtt_port = int(os.getenv('MQTT_PORT', '1883'))
esp32_topic_prefix = os.getenv('ESP32_TOPIC_PREFIX', 's_window')

# OpenWeatherMap Air Quality API의 기본 URL
BASE_URL = "http://api.openweathermap.org/data/2.5/air_pollution?lat={0}&lon={1}&appid={2}"

def get_air_quality():
    """
    OpenWeatherMap Air Quality API를 호출하여 현재 위치의 미세먼지 데이터를 가져옵니다.
    """
    final_url = BASE_URL.format(settings["lat"], settings["lon"], settings["api_key"])

    try:
        response = requests.get(final_url)
        # API 응답 상태 코드가 성공(200)인지 확인
        if response.status_code == 200:
            data = response.json()
            return data
        else:
            print(f"오류: 데이터를 가져올 수 없습니다. 상태 코드: {response.status_code}")
            return None
    except requests.exceptions.RequestException as e:
        print(f"오류: API 요청 중 문제가 발생했습니다: {e}")
        return None

def send_to_esp32(aqi, pm25, pm10):
    """
    ESP32로 MQTT를 통해 대기질 데이터를 전송합니다.
    """
    try:
        # ESP32로 데이터 전송
        publish.single(f"{esp32_topic_prefix}/aqi", str(aqi), 
                      hostname=mqtt_broker, port=mqtt_port)
        publish.single(f"{esp32_topic_prefix}/pm25", str(pm25), 
                      hostname=mqtt_broker, port=mqtt_port)
        publish.single(f"{esp32_topic_prefix}/pm10", str(pm10), 
                      hostname=mqtt_broker, port=mqtt_port)
        
        print(f"✅ MQTT 데이터 전송 완료:")
        print(f"   - AQI: {aqi} → {esp32_topic_prefix}/aqi")
        print(f"   - PM2.5: {pm25} → {esp32_topic_prefix}/pm25")
        print(f"   - PM10: {pm10} → {esp32_topic_prefix}/pm10")
        return True
    except Exception as e:
        print(f"❌ MQTT 전송 실패: {e}")
        return False

def main():
    """
    메인 함수: 대기질 데이터를 가져와서 시리얼 창에 출력합니다.
    """
    print("대기질 데이터를 가져오는 중...")
    air_quality_data = get_air_quality()

    if air_quality_data:
        try:
            # 현재 대기질 정보 추출
            current_aqi = air_quality_data["list"][0]["main"]["aqi"]
            components = air_quality_data["list"][0]["components"]
            pm2_5 = components.get("pm2_5")
            pm10 = components.get("pm10")

            print("\n--- 현재 대기질 데이터 ---")
            print(f"대기질 지수 (AQI): {current_aqi}")
            print(f"미세먼지 (PM2.5): {pm2_5} µg/m³")
            print(f"초미세먼지 (PM10): {pm10} µg/m³")
            print("-------------------------")
            
            # ESP32로 MQTT 전송
            print("\n📡 ESP32로 MQTT 전송 중...")
            if send_to_esp32(current_aqi, pm2_5, pm10):
                print("✅ ESP32로 데이터 전송 완료!")
            else:
                print("❌ ESP32로 데이터 전송 실패!")
            
            print("\n✅ 데이터를 성공적으로 가져왔습니다.")

        except (KeyError, IndexError) as e:
            print(f"오류: 대기질 데이터를 파싱하는 데 실패했습니다. 누락된 키: {e}")
    else:
        print("\n❌ 대기질 데이터를 가져오는 데 실패했습니다.")

if __name__ == "__main__":
    main()