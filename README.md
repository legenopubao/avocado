# 🌱 Airocado - 스마트 창문 IoT 앱

ESP32와 라즈베리파이를 연동한 실시간 공기질 모니터링 및 자동 창문 제어 Flutter 앱입니다.

## 🚀 주요 기능

### 📊 실시간 공기질 모니터링
- **온도/습도**: 실내 환경 상태 실시간 표시
- **CO2**: 이산화탄소 농도 모니터링 (기본값: 400ppm)
- **TVOC**: 휘발성 유기화합물 농도 (기본값: 0ppb)
- **미세먼지**: PM2.5, PM10 실시간 측정
- **공기질 평가**: 종합적인 공기질 상태 자동 분석

### 🔌 이중 통신 지원
- **ESP32 (HTTP)**: 센서 데이터 수신 및 창문 제어
- **라즈베리파이 (MQTT)**: 벌레 감지 및 펌프 제어
- **자동 백업**: HTTP 실패 시 MQTT로 자동 전환

### 🎨 모던 UI/UX
- **반응형 디자인**: 모바일, 태블릿, 웹 지원
- **실시간 애니메이션**: 부드러운 전환 효과
- **직관적 인터페이스**: 사용자 친화적 디자인
- **다크/라이트 모드**: 자동 테마 전환

## 🛠 기술 스택

- **프레임워크**: Flutter 3.x
- **언어**: Dart
- **통신**: HTTP (ESP32), MQTT (라즈베리파이)
- **상태 관리**: StreamController
- **로컬 저장소**: SharedPreferences
- **플랫폼**: Android, iOS, Web

## 📱 설치 및 실행

### 1. 환경 설정
```bash
# Flutter SDK 설치 확인
flutter doctor

# 의존성 설치
flutter pub get
```

### 2. 앱 실행
```bash
# 웹 버전
flutter run -d web-server --web-port 8080

# Android
flutter run -d android

# iOS
flutter run -d ios
```

### 3. 빌드
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# 웹 배포
flutter build web
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
  "temp": 25.5,
  "hum": 60.0,
  "co2": 450.0,
  "tvoc": 5.0,
  "pm25": 15.0,
  "pm10": 30.0,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### 제어 명령 (POST /control)
```json
{
  "command": "bug_on"
}
```

## 🎯 사용법

### 1. 초기 연결
- 앱 실행 시 자동으로 ESP32 WiFi 연결 시도
- 실패 시 수동으로 IP 주소 입력 가능
- MQTT 브로커 자동 연결

### 2. 데이터 모니터링
- 실시간 센서 데이터 자동 업데이트
- 공기질 상태 자동 평가
- 이력 데이터 저장

### 3. 창문 제어
- 벌레 감지 시 자동 창문 닫기
- 수동 제어 버튼으로 즉시 제어
- 안전 모드 설정 가능

## 🔒 보안 설정

### Android 권한
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS 설정
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 📁 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── services/
│   ├── api.dart             # HTTP 통신 (ESP32)
│   ├── mqtt_service.dart    # MQTT 통신 (라즈베리파이)
│   └── communication_service.dart # 통합 통신 관리
└── widgets/
    ├── air_quality_card.dart    # 공기질 카드
    ├── sensor_grid.dart         # 센서 그리드
    ├── control_section.dart     # 제어 섹션
    ├── polling_status.dart      # 연결 상태
    └── connection_dialog.dart   # 연결 다이얼로그
```

## 🐛 문제 해결

### 연결 문제
1. **ESP32 연결 실패**: IP 주소 확인, WiFi 연결 상태 점검
2. **MQTT 연결 실패**: 브로커 상태 확인, 네트워크 연결 점검
3. **센서 데이터 오류**: JSON 형식 확인, 필수 필드 점검

### 빌드 문제
1. **의존성 오류**: `flutter pub get` 실행
2. **플랫폼 오류**: `flutter clean` 후 재빌드
3. **권한 오류**: Android/iOS 설정 파일 확인

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 👥 팀원

- **개발**: Flutter 앱 개발 및 UI/UX 설계
- **하드웨어**: ESP32 센서 통합 및 라즈베리파이 MQTT 구현
- **기획**: 프로젝트 기획 및 요구사항 분석

## 📞 연락처

프로젝트 링크: [https://github.com/legenopubao/avocado](https://github.com/legenopubao/avocado)

---

**Airocado** - 더 건강한 실내 환경을 위한 스마트 창문 솔루션 🌱