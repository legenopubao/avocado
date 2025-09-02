// lib/services/api.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // Added for Colors and Icons
import 'dart:math'; // Added for Random

// API 응답 데이터 모델
class AirQualityData {
  final double di; // 불쾌지수 (Discomfort Index)
  final double temperature;//온도
  final double humidity;//습도
  final String weather; // 날씨 정보 (맑음, 비, 눈, 흐림 등)
  final double pm25;
  final double pm10;
  final bool bug; // 벌레 감지 상태
  final bool window; // 창문 상태 (true: 열림, false: 닫힘)
  final DateTime timestamp;

  AirQualityData({
    this.di = 0, // 기본값 0. temperature, humidity 입력받은 후 계산하여 사용
    required this.temperature,
    required this.humidity,
    this.weather = '맑음', // 기본값: 맑음
    required this.pm25,
    required this.pm10,
    this.bug = false, // 기본값: 벌레 없음
    this.window = false, // 기본값: 창문 닫힘
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    // 필수 필드 확인 (DI는 온/습도로 계산 가능하므로 필수에서 제외)
    final requiredFields = ['pm25', 'pm10'];
    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        throw FormatException('필수 필드가 누락되었습니다: $field');
      }
    }

    // 데이터 타입 검사 및 변환
    // 온도/습도 파싱 (다양한 키 허용)
    final temperature = _parseNumber(
      json['temperature'] ?? json['temp'] ?? json['t'],
    );
    final humidity = _parseNumber(
      json['humidity'] ?? json['hum'] ?? json['h'],
    );
    // DI 제공 시 파싱, 없으면 뒤에서 계산
    double di = _parseNumber(json['di']);
    final weather = json.containsKey('weather') ? json['weather'] as String : '맑음';
    final pm25 = _parseNumber(json['pm25']);
    final pm10 = _parseNumber(json['pm10']);
    final bug = json.containsKey('bug') ? _parseBool(json['bug']) : false;
    final window = json.containsKey('window') ? _parseBool(json['window']) : false;

    // timestamp 처리 (선택적)
    DateTime? timestamp;
    if (json.containsKey('timestamp')) {
      try {
        if (json['timestamp'] is String) {
          timestamp = DateTime.parse(json['timestamp']);
        } else if (json['timestamp'] is int) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp']);
        }
      } catch (e) {
        debugPrint('timestamp 파싱 오류: $e');
        // timestamp 파싱 실패 시 null로 설정하여 기본값 사용
      }
    }

    // DI 계산: di 값이 제공되지 않았거나 0일 때, 유효한 온/습도 기반으로 계산
    if ((di == 0 || di.isNaN) && (temperature != 0 || humidity != 0)) {
      di = computeDiscomfortIndex(temperature: temperature, humidity: humidity);
    }

    return AirQualityData(
      di: di,
      temperature: temperature,
      humidity: humidity,
      weather: weather,
      pm25: pm25,
      pm10: pm10,
      bug: bug,
      window: window,
      timestamp: timestamp,
    );
  }
  
  // 불쾌지수 계산 함수 (DI)
  static double computeDiscomfortIndex({required double temperature, required double humidity}) {
    // di = 0.81*T + 0.01*H*(0.99*T - 14.3) + 46.3
    final t = temperature;
    final h = humidity;
    return 0.81 * t + 0.01 * h * (0.99 * t - 14.3) + 46.3;
  }
  
  static double _parseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }
  
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is num) {
      return value != 0;
    }
    return false;
  }
  
  // 4단계 공기질 평가 (매우좋음, 좋음, 나쁨, 매우나쁨)
  Map<String, dynamic> getAirQualityStatus() {
    // PM2.5 기준 (WHO 기준)
    int pm25Score;
    if (pm25 <= 10) {
      pm25Score = 0; // 매우좋음
    } else if (pm25 <= 25) {
      pm25Score = 1; // 좋음
    } else if (pm25 <= 50) {
      pm25Score = 2; // 나쁨
    } else {
      pm25Score = 3; // 매우나쁨
    }
    
    // PM10 기준
    int pm10Score;
    if (pm10 <= 20) {
      pm10Score = 0;
    } else if (pm10 <= 50) {
      pm10Score = 1;
    } else if (pm10 <= 100) {
      pm10Score = 2;
    } else {
      pm10Score = 3;
    }
    
    // 불쾌지수 기준 (DI 기준)
    int diScore;
    if (di < 70) {
      diScore = 0; // 쾌적
    } else if (di < 76) {
      diScore = 1; // 보통
    } else if (di < 80) {
      diScore = 2; // 약간 불쾌
    } else {
      diScore = 3; // 불쾌
    }
    
    // 종합 점수 (PM2.5 40%, PM10 30%, 불쾌지수 30%)
    final totalScore = (pm25Score * 0.4 + pm10Score * 0.3 + diScore * 0.3);
    
    if (totalScore < 0.5) {
      return {
        "status": "매우좋음",
        "message": "공기질이 매우 좋습니다!",
        "color": Colors.green,
        "icon": Icons.sentiment_very_satisfied,
      };
    } else if (totalScore < 1.5) {
      return {
        "status": "좋음",
        "message": "공기질이 양호합니다.",
        "color": Colors.blue,
        "icon": Icons.sentiment_satisfied,
      };
    } else if (totalScore < 2.5) {
      return {
        "status": "나쁨",
        "message": "환기가 필요합니다!",
        "color": Colors.orange,
        "icon": Icons.sentiment_dissatisfied,
      };
    } else {
      return {
        "status": "매우나쁨",
        "message": "환기가 시급합니다!",
        "color": Colors.red,
        "icon": Icons.sentiment_very_dissatisfied,
      };
    }
  }
  
  // 불쾌지수 상태 설명
  Map<String, dynamic> getDiscomfortStatus() {
    if (di < 70) {
      return {
        "status": "쾌적",
        "message": "매우 쾌적한 환경입니다",
        "color": Colors.green,
        "icon": Icons.sentiment_very_satisfied,
      };
    } else if (di < 76) {
      return {
        "status": "보통",
        "message": "적당한 환경입니다",
        "color": Colors.blue,
        "icon": Icons.sentiment_satisfied,
      };
    } else if (di < 80) {
      return {
        "status": "약간 불쾌",
        "message": "약간 불쾌한 환경입니다",
        "color": Colors.orange,
        "icon": Icons.sentiment_dissatisfied,
      };
    } else if (di < 85) {
      return {
        "status": "불쾌",
        "message": "불쾌한 환경입니다",
        "color": Colors.red,
        "icon": Icons.sentiment_very_dissatisfied,
      };
    } else {
      return {
        "status": "매우 불쾌",
        "message": "매우 불쾌한 환경입니다",
        "color": Colors.purple,
        "icon": Icons.sentiment_very_dissatisfied,
      };
    }
  }
  
  // 자동 창문 제어 로직 
  String getAutoWindowControl() {
    // 벌레 감지 시 닫기
    if (bug) {
      return "닫기";
    }
    // 미세먼지 나쁨 시 닫기
    else if (pm25 > 35 || pm10 > 80) {
      return "닫기";
    }
    // 불쾌지수 76 이하(쾌적) 시 닫기
    else if (di < 76) {
      return "닫기";
    }
    // 그 외의 경우 열기
    else {
      return "열기";
    }
  }

  @override
  String toString() {
    return 'AirQualityData(DI: ${di.toStringAsFixed(1)}, '
           '날씨: $weather, '
           'PM2.5: ${pm25.toStringAsFixed(1)}μg/m³, '
           'PM10: ${pm10.toStringAsFixed(1)}μg/m³, '
           'bug: $bug, '
           'window: $window, '
           'timestamp: $timestamp)';
  }
}

// API 호출 관련 예외 클래스
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

// API 클라이언트
class ApiClient {
  String _baseUrl = '';
  bool _isTestMode = false; // 테스트 모드 플래그
  
  // 테스트 모드용 상태 변수들
  bool _testBugDetected = false;
  bool _testWindowOpen = false;
  
  String get baseUrl => _baseUrl;
  //불필요하게 getter와 setter로 변수를 감싸고 있다고 생각될 수 있지만 이후의 로직 확장성을 위해 이렇게 둠.
  set baseUrl(String value) => _baseUrl = value;
  
  // 테스트 모드 설정
  void setTestMode(bool enabled) {
    _isTestMode = enabled;
    if (enabled) {
      // 테스트 모드 초기화
      _testBugDetected = false;
      _testWindowOpen = false;
    }
    debugPrint('테스트 모드: ${enabled ? "활성화" : "비활성화"}');
  }
  
  bool get isTestMode => _isTestMode;

  Future<AirQualityData> getData([String? customUrl]) async {
    // 테스트 모드일 때 더미 데이터 반환
    if (_isTestMode) {
      debugPrint('테스트 모드: 더미 데이터 반환');
      return _generateTestData();
    }
    
    final url = customUrl ?? _baseUrl;
    if (url.isEmpty) {
      throw ApiException('URL이 설정되지 않았습니다.');
    }

    try {
      // URL 정규화
      String normalizedUrl = url;
      if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'http://$normalizedUrl';
      }
      if (!normalizedUrl.endsWith('/')) {
        normalizedUrl += '/';
      }

      final response = await http.get(
        Uri.parse('${normalizedUrl}data'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('API 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return AirQualityData.fromJson(jsonData);
      } else {
        throw ApiException('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API 요청 오류: $e');
      if (e is ApiException) rethrow;
      throw ApiException('연결 오류: $e');
    }
  }

  Future<bool> controlBug(String command) async {
    // 테스트 모드일 때는 상태 업데이트 후 성공 반환
    if (_isTestMode) {
      debugPrint('테스트 모드: 제어 명령 "$command" 처리');
      
      switch (command) {
        case 'bug_on':
          _testBugDetected = true;
          debugPrint('테스트 모드: 벌레 감지 ON');
          break;
        case 'bug_off':
          _testBugDetected = false;
          debugPrint('테스트 모드: 벌레 감지 OFF');
          break;
        case 'window_toggle':
          _testWindowOpen = !_testWindowOpen;
          debugPrint('테스트 모드: 창문 상태 변경 - ${_testWindowOpen ? "열림" : "닫힘"}');
          break;
        default:
          debugPrint('테스트 모드: 알 수 없는 명령 "$command"');
      }
      
      return true;
    }
    
    final url = _baseUrl;
    if (url.isEmpty) {
      throw ApiException('URL이 설정되지 않았습니다.');
    }

    try {
      String normalizedUrl = _baseUrl;
      if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'http://$normalizedUrl';
      }
      if (!normalizedUrl.endsWith('/')) {
        normalizedUrl += '/';
      }

      final response = await http.post(
        Uri.parse('${normalizedUrl}control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'command': command}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('제어 명령 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['ok'] == true;
      } else {
        throw ApiException('HTTP 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('제어 명령 오류: $e');
      if (e is ApiException) rethrow;
      throw ApiException('제어 오류: $e');
    }
  }

  // 테스트용 더미 데이터 생성
  AirQualityData _generateTestData() {
    // 랜덤하게 변하는 테스트 데이터 생성
    final random = Random();
    
    // 온도/습도 생성 후 DI 공식으로 계산
    final temperature = 20.0 + random.nextDouble() * 10.0; // 20~30°C
    final humidity = 40.0 + random.nextDouble() * 40.0; // 40~80%
    final di = AirQualityData.computeDiscomfortIndex(temperature: temperature, humidity: humidity);
    
    // PM2.5: 10~60 범위 (좋음~나쁨)
    final pm25 = 10.0 + random.nextDouble() * 50.0;
    
    // PM10: 20~120 범위 (좋음~매우나쁨)
    final pm10 = 20.0 + random.nextDouble() * 100.0;
    
    // CO2: 400~1000 범위 (실외~실내)
    final weather = ['맑음', '비', '눈', '흐림'][random.nextInt(4)];
    
    // 테스트 모드에서 제어된 상태 사용
    final bug = _testBugDetected;
    final window = _testWindowOpen;
    
    return AirQualityData(
      di: di,
      temperature: temperature,
      humidity: humidity,
      weather: weather,
      pm25: pm25,
      pm10: pm10,
      bug: bug,
      window: window,
      timestamp: DateTime.now(),
    );
  }
}