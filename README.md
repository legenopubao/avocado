# ESP32 Mock Server

ESP32와 Flutter 앱 통신 테스트를 위한 목업 서버입니다.

## 기능

- **HTTP API**: 센서 데이터 조회 및 제어
- **WebSocket**: 실시간 데이터 업데이트
- **센서 데이터 시뮬레이션**: 온도, 습도, PM2.5, 벌레 감지 등
- **장치 제어**: 서보 모터, 벌레 감지 모드 제어

## 설치 및 실행

### 1. 의존성 설치
```bash
pip install -r requirements.txt
```

### 2. 서버 실행
```bash
python esp32_mock_server.py
```

서버가 시작되면 다음 URL에 접근할 수 있습니다:
- **메인 엔드포인트**: http://localhost:8000/data
- **WebSocket**: ws://localhost:8000/ws

## API 엔드포인트

### HTTP API

#### GET /data
현재 센서 데이터 조회
```json
{
  "temp": 25.0,
  "hum": 60.0,
  "pm25": 15.3,
  "bug": false,
  "servo": 0
}
```

#### GET /bugOn
벌레 감지 모드 활성화
```json
{
  "ok": true,
  "msg": "벌레 감지 모드 활성화"
}
```

#### GET /bugOff
벌레 감지 모드 비활성화
```json
{
  "ok": true,
  "msg": "벌레 감지 모드 비활성화"
}
```

### WebSocket API

#### 연결
```
ws://localhost:8000/ws
```

WebSocket을 통해 5초마다 자동으로 센서 데이터가 전송됩니다.

## Flutter 앱 연동 예제

### HTTP API 사용 (Dart/Flutter)

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ESP32Service {
  static const String baseUrl = 'http://localhost:8000';
  
  static Future<Map<String, dynamic>> getData() async {
    final response = await http.get(Uri.parse('$baseUrl/data'));
    return json.decode(response.body);
  }
  
  static Future<Map<String, dynamic>> setBugDetection(bool enabled) async {
    final endpoint = enabled ? '/bugOn' : '/bugOff';
    final response = await http.get(Uri.parse('$baseUrl$endpoint'));
    return json.decode(response.body);
  }
}
```

### WebSocket 사용 (Dart/Flutter)

```dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class ESP32WebSocketService {
  WebSocketChannel? _channel;
  
  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8000/ws'),
    );
    
    _channel!.stream.listen(
      (message) {
        final data = json.decode(message);
        print('센서 데이터: $data');
      },
      onError: (error) => print('WebSocket 오류: $error'),
      onDone: () => print('WebSocket 연결 종료'),
    );
  }
  
  void disconnect() {
    _channel?.sink.close();
  }
}
```

## 참고사항

- 이 서버는 개발 및 테스트 목적으로만 사용됩니다.
- 실제 운영 환경에서는 실제 ESP32 디바이스를 사용해야 합니다.
- 모든 데이터는 시뮬레이션된 값입니다.
