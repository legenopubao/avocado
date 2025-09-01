// lib/services/communication_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'mqtt_service.dart';

class CommunicationService {
  final ApiClient _apiClient = ApiClient();
  final MqttService _mqttService = MqttService();
  
  bool _httpConnected = false;
  bool _mqttConnected = false;
  String _httpStatus = '연결되지 않음';
  String _mqttStatus = '연결되지 않음';
  
  // 스트림 컨트롤러들
  final StreamController<AirQualityData> _dataController = StreamController<AirQualityData>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  
  Stream<AirQualityData> get dataStream => _dataController.stream;
  Stream<String> get statusStream => _statusController.stream;
  
  bool get httpConnected => _httpConnected;
  bool get mqttConnected => _mqttConnected;
  String get httpStatus => _httpStatus;
  String get mqttStatus => _mqttStatus;
  
  CommunicationService() {
    _initializeMqttCallbacks();
  }
  
  void _initializeMqttCallbacks() {
    // MQTT 연결 상태 변경 콜백
    _mqttService.onConnectionStatusChanged = (bool connected) {
      _mqttConnected = connected;
      _mqttStatus = connected ? '연결됨' : '연결 해제됨';
      _statusController.add('MQTT: $_mqttStatus');
      debugPrint('MQTT 연결 상태 변경: $connected');
    };
    
    // 펌프 메시지 수신 콜백
    _mqttService.onPumpMessage = (String message) {
      debugPrint('펌프 메시지 수신: $message');
      _statusController.add('라즈베리파이에서 펌프 제어: $message');
    };
    
    // 센서 메시지 수신 콜백
    _mqttService.onSensorMessage = (String message) {
      debugPrint('센서 메시지 수신: $message');
      // 향후 센서 데이터 파싱 로직 추가 가능
    };
  }
  
  // 설정 로드
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final httpUrl = prefs.getString('http_url') ?? '';
      
      if (httpUrl.isNotEmpty) {
        await setHttpConfig(httpUrl);
      }
      
      // MQTT 자동 연결 시도
      await _connectMqtt();
      
    } catch (e) {
      debugPrint('설정 로드 오류: $e');
    }
  }
  
  // 설정 저장
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_httpConnected) {
        await prefs.setString('http_url', _apiClient.baseUrl);
      }
    } catch (e) {
      debugPrint('설정 저장 오류: $e');
    }
  }
  
  // HTTP 설정
  Future<bool> setHttpConfig(String baseUrl) async {
    try {
      _apiClient.baseUrl = baseUrl;
      final success = await _testHttpConnection();
      _httpConnected = success;
      _httpStatus = success ? '연결됨' : '연결 실패';
      return success;
    } catch (e) {
      _httpConnected = false;
      _httpStatus = '오류: $e';
      debugPrint('HTTP 설정 오류: $e');
      return false;
    }
  }
  
  // MQTT 설정
  Future<bool> setMqttConfig() async {
    return await _connectMqtt();
  }
  
  // MQTT 연결
  Future<bool> _connectMqtt() async {
    try {
      final success = await _mqttService.connect();
      if (success) {
        _mqttConnected = true;
        _mqttStatus = '연결됨';
        _statusController.add('MQTT 연결 성공');
      }
      return success;
    } catch (e) {
      _mqttConnected = false;
      _mqttStatus = '연결 실패: $e';
      debugPrint('MQTT 연결 오류: $e');
      return false;
    }
  }
  
  // HTTP 연결 테스트
  Future<bool> _testHttpConnection() async {
    try {
      await _apiClient.getData();
      return true;
    } catch (e) {
      debugPrint('HTTP 연결 테스트 실패: $e');
      return false;
    }
  }
  
  // 데이터 가져오기 (HTTP 우선, MQTT 백업)
  Future<AirQualityData?> fetchData() async {
    try {
      // HTTP가 연결되어 있으면 HTTP 사용
      if (_httpConnected) {
        final data = await _apiClient.getData();
        _dataController.add(data);
        return data;
      }
      
      // HTTP가 실패하거나 연결되지 않은 경우 MQTT로 센서 데이터 요청
      if (_mqttConnected) {
        await _mqttService.requestSensorData();
        _statusController.add('MQTT로 센서 데이터 요청');
      }
      
      return null;
    } catch (e) {
      debugPrint('데이터 가져오기 오류: $e');
      _statusController.add('데이터 가져오기 실패: $e');
      return null;
    }
  }
  
  // 벌레 감지 제어 (HTTP 우선, MQTT 백업)
  Future<bool> controlBug(String command) async {
    try {
      // HTTP가 연결되어 있으면 HTTP 사용
      if (_httpConnected) {
        final success = await _apiClient.controlBug(command);
        if (success) {
          _statusController.add('HTTP로 제어 명령 전송: $command');
          return true;
        }
      }
      
      // HTTP가 실패하거나 연결되지 않은 경우 MQTT 사용
      if (_mqttConnected) {
        final success = await _mqttService.controlPump(command);
        if (success) {
          _statusController.add('MQTT로 펌프 제어: $command');
          return true;
        }
      }
      
      _statusController.add('제어 명령 전송 실패');
      return false;
    } catch (e) {
      debugPrint('벌레 감지 제어 오류: $e');
      _statusController.add('제어 오류: $e');
      return false;
    }
  }
  
  // 연결 해제
  Future<void> disconnect() async {
    try {
      if (_httpConnected) {
        _httpConnected = false;
        _httpStatus = '연결 해제됨';
      }
      
      if (_mqttConnected) {
        _mqttService.disconnect();
        _mqttConnected = false;
        _mqttStatus = '연결 해제됨';
      }
      
      _statusController.add('모든 연결 해제됨');
    } catch (e) {
      debugPrint('연결 해제 오류: $e');
    }
  }
  
  // 리소스 해제
  void dispose() {
    _mqttService.dispose();
    _dataController.close();
    _statusController.close();
  }
}
