#!/usr/bin/python
# A simple script to get air quality data from OpenWeatherMap and print to the console.
#
import requests

# ==================== change these settings ===============
settings = {
    'api_key': '2a4b08ce1569f345464d086e1abce532',  # 제공된 API 키를 사용
    'lat': 'YOUR_LATITUDE',                      # 현재 위치의 위도를 입력하세요.
    'lon': 'YOUR_LONGITUDE'                     # 현재 위치의 경도를 입력하세요.
}
# ==========================================================

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
            
            print("\n✅ 데이터를 성공적으로 가져왔습니다.")

        except (KeyError, IndexError) as e:
            print(f"오류: 대기질 데이터를 파싱하는 데 실패했습니다. 누락된 키: {e}")
    else:
        print("\n❌ 대기질 데이터를 가져오는 데 실패했습니다.")

if __name__ == "__main__":
    main()