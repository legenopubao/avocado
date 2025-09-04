# 🌱 Airocado - 스마트 창문 IoT 앱

ESP32와 라즈베리파이를 연동한 실시간 공기 질 모니터링 및 자동 창문 제어 Flutter 앱입니다.

# 앱 배포
안드로이드(원스토어): https://m.onestore.co.kr/v2/ko-kr/app/0001002169

## 🚀 주요 기능

### 📊 실시간 공기질 모니터링
- **불쾌지수 (DI)**: 온도와 습도를 기반으로 한 쾌적도 지수
- **미세먼지**: PM2.5, PM10 실시간 측정 및 4단계 평가
- **날씨 정보**: 공공데이터포털 기상청 API 연동
- **벌레 감지**: 실시간 벌레 감지 상태 모니터링
- **창문 상태**: 현재 창문 열림/닫힘 상태 표시

### 🎯 자동 창문 제어
- **로직**: 불쾌지수, 미세먼지, 벌레 감지를 종합한 자동 제어
- **수동 제어**: 즉시 창문 열기/닫기 제어
- **테스트 모드**: 더미 데이터로 기능 테스트 가능

### 🔌 이중 통신 지원
- **ESP32 (HTTP)**: 센서 데이터 수신 및 창문 제어
- **라즈베리파이 (MQTT)**: 벌레 감지 및 펌프 제어
- **자동 백업**: HTTP 실패 시 MQTT로 자동 전환

### 🎨 모던 UI/UX
- **반응형 디자인**: 모바일, 태블릿, 웹 지원
- **실시간 애니메이션**: 부드러운 전환 효과
- **직관적 인터페이스**: 사용자 친화적 디자인
- **자동 창문 제어 모드**: 토글 스위치로 모드 전환

## 🛠 기술 스택

- **프레임워크**: Flutter 3.x
- **언어**: Dart
- **통신**: HTTP (ESP32), MQTT (라즈베리파이)
- **상태 관리**: StreamController
- **로컬 저장소**: SharedPreferences
- **위치 서비스**: Geolocator, Geocoding
- **날씨 API**: 공공데이터포털 기상청
- **플랫폼**: Android, iOS, Web

## 📱 설치 및 실행

### 1. 환경 변수 설정

프로젝트 루트에 `.env` 파일을 생성하고 다음 내용을 추가하세요:

```bash
# 공공데이터포털 기상청 API 키
PUBLIC_DATA_API_KEY=YOUR_ACTUAL_API_KEY_HERE

# 기타 환경 변수들
APP_NAME=Airocado
APP_VERSION=1.0.0
```

#### API 키 발급 방법:

1. [공공데이터포털](https://www.data.go.kr/) 가입
2. "단기예보 조회서비스" 검색
3. API 신청 및 승인
4. 발급받은 API 키를 `.env` 파일에 입력

### 2. 의존성 설치

```bash
flutter pub get
```

### 3. 앱 실행

```bash
flutter run
```

## 🔧 하드웨어 설정

### ESP32 설정
```cpp
// WiFi 설정
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// 웹서버 포트
const int port = 8000;

// 센서 핀 설정
#define DHT_PIN 4
#define PM25_PIN 5
```

### 라즈베리파이 설정
```python
# MQTT 브로커 설정
BROKER = "broker.hivemq.com"
PORT = 1883
CLIENT_ID = "raspi_0001"

# 토픽 설정
PUMP_TOPIC = "s_window/pump"
SENSOR_TOPIC = "s_window/sensor"
```

## 📡 API 구조

### 센서 데이터 (GET /data)
```json
{
  "di": 75.5,
  "weather": "맑음",//weather api data
  "pm25": 15.0,
  "pm10": 30.0,
  "bug": false,
  "window": false,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### 제어 명령 (POST /control)
```json
{
  "command": "window_toggle"
}
```

**지원하는 명령어:**
- `bug_on`: 벌레 감지 활성화
- `bug_off`: 벌레 감지 비활성화
- `window_toggle`: 창문 상태 토글

## 🎯 사용법

### 1. 초기 연결
- 앱 실행 시 자동으로 ESP32 WiFi 연결 시도
- 실패 시 수동으로 IP 주소 입력 가능
- MQTT 브로커 자동 연결

### 2. 데이터 모니터링
- 실시간 센서 데이터 자동 업데이트 (5초 간격)
- 테스트 모드 시 2초 간격으로 더미 데이터 생성
- 공기질 상태 자동 평가 (매우좋음, 좋음, 나쁨, 매우나쁨)

### 3. 창문 제어
- **자동 모드**: 불쾌지수, 미세먼지, 벌레 감지 기반 자동 제어
- **수동 모드**: 즉시 창문 열기/닫기 제어
- **테스트 모드**: 더미 데이터로 모든 기능 테스트

### 4. 날씨 서비스
- GPS 기반 현재 위치 자동 감지
- 공공데이터포털에서 실시간 날씨 정보 수신
- 위치 권한 거부 시 "날씨 기능 OFF" 표시

## 🔒 보안 설정

### Android 권한
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS 설정
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
<key>NSLocationWhenInUseUsageDescription</key>
<string>날씨 정보를 위해 위치 정보가 필요합니다.</string>
```

## 📁 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점 및 메인 화면
├── services/
│   ├── api.dart             # HTTP API 클라이언트 (ESP32)
│   ├── weather_service.dart # 날씨 서비스 (공공데이터포털)
│   ├── mqtt_service.dart    # MQTT 통신 (라즈베리파이)
│   └── communication_service.dart # 통합 통신 관리
└── widgets/
    ├── air_quality_card.dart    # 공기질 카드 (4단계 평가)
    ├── sensor_grid.dart         # 센서 그리드 (PM2.5, PM10, 날씨)
    ├── control_section.dart     # 제어 섹션 (자동/수동 모드)
    ├── polling_status.dart      # 연결 상태 표시
    └── connection_dialog.dart   # WiFi 연결 다이얼로그
```

## 🧪 테스트 모드

앱 상단의 "테스트 모드" 토글을 활성화하면:

- **더미 데이터 생성**: 랜덤한 센서 값으로 기능 테스트
- **빠른 폴링**: 2초 간격으로 데이터 업데이트
- **제어 명령 시뮬레이션**: 실제 하드웨어 없이 제어 기능 테스트
- **상태 지속성**: 벌레 감지 및 창문 상태 변경 유지

## 🐛 문제 해결

### 연결 문제
1. **ESP32 연결 실패**: IP 주소 확인, WiFi 연결 상태 점검
2. **MQTT 연결 실패**: 브로커 상태 확인, 네트워크 연결 점검
3. **센서 데이터 오류**: JSON 형식 확인, 필수 필드 점검

### 빌드 문제
1. **의존성 오류**: `flutter pub get` 실행
2. **플랫폼 오류**: `flutter clean` 후 재빌드
3. **권한 오류**: Android/iOS 설정 파일 확인

### 날씨 서비스 문제
1. **위치 권한 거부**: 설정에서 위치 권한 허용
2. **API 키 오류**: `.env` 파일의 API 키 확인
3. **네트워크 오류**: 인터넷 연결 상태 점검

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 연락처

프로젝트 링크: [https://github.com/legenopubao/avocado](https://github.com/legenopubao/avocado)

---


**Airocado** - 더 건강한 실내 환경을 위한 스마트 창문 솔루션 🌱
