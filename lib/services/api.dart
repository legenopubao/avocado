// lib/services/api.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Added for Colors and Icons

// API 응답 데이터 모델
class AirQualityData {
  final double temperature;
  final double humidity;
  final double co2;
  final double tvoc;
  final double pm25;
  final double pm10;
  final bool bug; // 벌레 감지 상태
  final bool window; // 창문 상태 (true: 열림, false: 닫힘)
  final DateTime timestamp;
  
  AirQualityData({
    required this.temperature,
    required this.humidity,
    this.co2 = 400.0, // 기본값: 실외 CO2 농도
    this.tvoc = 0.0,  // 기본값: 0 ppb
    required this.pm25,
    required this.pm10,
    this.bug = false, // 기본값: 벌레 없음
    this.window = false, // 기본값: 창문 닫힘
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    try {
      // 필수 필드 확인
      final requiredFields = ['temp', 'hum', 'pm25', 'pm10'];
      for (final field in requiredFields) {
        if (!json.containsKey(field)) {
          throw FormatException('필수 필드가 누락되었습니다: $field');
        }
      }
      
      // 데이터 타입 검사 및 변환
      final temp = _parseNumber(json['temp']);
      final hum = _parseNumber(json['hum']);
      final co2 = json.containsKey('co2') ? _parseNumber(json['co2']) : 400.0;
      final tvoc = json.containsKey('tvoc') ? _parseNumber(json['tvoc']) : 0.0;
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
      
      return AirQualityData(
        temperature: temp,
        humidity: hum,
        co2: co2,
        tvoc: tvoc,
        pm25: pm25,
        pm10: pm10,
        bug: bug,
        window: window,
        timestamp: timestamp,
      );
    } catch (e) {
      debugPrint('JSON 파싱 오류: $e');
      debugPrint('JSON 데이터: $json');
      rethrow;
    }
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
    
    // 온도 기준 (18-26도가 적정)
    int tempScore;
    if (temperature >= 18 && temperature <= 26) {
      tempScore = 0;
    } else if (temperature >= 16 && temperature <= 28) {
      tempScore = 1;
    } else if (temperature >= 14 && temperature <= 30) {
      tempScore = 2;
    } else {
      tempScore = 3;
    }
    
    // 습도 기준 (40-60%가 적정)
    int humScore;
    if (humidity >= 40 && humidity <= 60) {
      humScore = 0;
    } else if (humidity >= 30 && humidity <= 70) {
      humScore = 1;
    } else if (humidity >= 20 && humidity <= 80) {
      humScore = 2;
    } else {
      humScore = 3;
    }
    
    // 종합 점수 (PM2.5 40%, PM10 30%, 온도 20%, 습도 10%)
    final totalScore = (pm25Score * 0.4 + pm10Score * 0.3 + tempScore * 0.2 + humScore * 0.1);
    
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
  
  @override
  String toString() {
    return 'AirQualityData(temp: ${temperature.toStringAsFixed(1)}°C, '
           'hum: ${humidity.toStringAsFixed(1)}%, '
           'CO2: ${co2.toStringAsFixed(1)}ppm, '
           'TVOC: ${tvoc.toStringAsFixed(1)}ppb, '
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

  String get baseUrl => _baseUrl;
  set baseUrl(String value) => _baseUrl = value;

  Future<AirQualityData> getData([String? customUrl]) async {
    final url = customUrl ?? _baseUrl;
    if (url.isEmpty) {
      throw ApiException('URL이 설정되지 않았습니다');
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
    if (_baseUrl.isEmpty) {
      throw ApiException('URL이 설정되지 않았습니다');
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
}