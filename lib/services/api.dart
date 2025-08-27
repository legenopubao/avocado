// lib/services/api.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

// API 응답 데이터 모델
class AirQualityData {
  final double temp;
  final double hum;
  final double pm25;
  final bool bug;
  final int servo;

  AirQualityData({
    required this.temp,
    required this.hum,
    required this.pm25,
    required this.bug,
    required this.servo,
  });

  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    return AirQualityData(
      temp: (json['temp'] as num).toDouble(),
      hum: (json['hum'] as num).toDouble(),
      pm25: (json['pm25'] as num).toDouble(),
      bug: json['bug'] as bool,
      servo: (json['servo'] as num).toInt(),
    );
  }
}

// API 호출 관련 예외 클래스
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

// API 클라이언트
class ApiClient {
  // GET /data
  Future<AirQualityData> getData(String baseUrl, {Duration timeout = const Duration(seconds: 3)}) async {
    final uri = Uri.parse('$baseUrl/data');
    try {
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode == 200) {
        return AirQualityData.fromJson(json.decode(response.body));
      } else {
        throw ApiException('서버 응답 오류: \${response.statusCode}');
      }
    } on TimeoutException {
      throw ApiException('요청 시간 초과');
    } on SocketException {
      throw ApiException('네트워크에 연결할 수 없습니다.');
    } catch (e) {
      throw ApiException('알 수 없는 오류: \$e');
    }
  }

  // GET /bugOn
  Future<Map<String, dynamic>> bugOn(String baseUrl) async {
    return _controlRequest('$baseUrl/bugOn');
  }

  // GET /bugOff
  Future<Map<String, dynamic>> bugOff(String baseUrl) async {
    return _controlRequest('$baseUrl/bugOff');
  }

  // 공통 제어 로직
  Future<Map<String, dynamic>> _controlRequest(String url) async {
    final uri = Uri.parse(url);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true) {
          return data;
        } else {
          throw ApiException(data['msg'] ?? '알 수 없는 제어 오류');
        }
      } else {
        throw ApiException('서버 응답 오류: \${response.statusCode}');
      }
    } on TimeoutException {
      throw ApiException('요청 시간 초과');
    } on SocketException {
      throw ApiException('네트워크에 연결할 수 없습니다.');
    } catch (e) {
      throw ApiException('알 수 없는 오류: \$e');
    }
  }
}