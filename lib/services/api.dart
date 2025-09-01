// lib/services/api.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// API 응답 데이터 모델
class AirQualityData {
  final double temperature;
  final double humidity;
  final double co2;
  final double tvoc;
  final double pm25;
  final double pm10;
  final DateTime timestamp;
  
  AirQualityData({
    required this.temperature,
    required this.humidity,
    this.co2 = 400.0, // 기본값: 실외 CO2 농도
    this.tvoc = 0.0,  // 기본값: 0 ppb
    required this.pm25,
    required this.pm10,
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
  
  @override
  String toString() {
    return 'AirQualityData(temp: ${temperature.toStringAsFixed(1)}°C, '
           'hum: ${humidity.toStringAsFixed(1)}%, '
           'CO2: ${co2.toStringAsFixed(1)}ppm, '
           'TVOC: ${tvoc.toStringAsFixed(1)}ppb, '
           'PM2.5: ${pm25.toStringAsFixed(1)}μg/m³, '
           'PM10: ${pm10.toStringAsFixed(1)}μg/m³, '
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