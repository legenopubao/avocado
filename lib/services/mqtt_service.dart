// lib/services/mqtt_service.dart
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';

class MqttService {
  MqttServerClient? _client;
  bool _isConnected = false;
  String _statusMessage = '연결되지 않음';
  
  // 라즈베리파이 코드 설정
  static const String _broker = 'broker.hivemq.com';
  static const int _port = 1883;
  static const String _clientId = 'flutter_app_001';
  static const String _pumpTopic = 's_window/pump';
  static const String _sensorTopic = 's_window/sensor';
  
  // 콜백 함수들
  Function(String)? onPumpMessage;
  Function(String)? onSensorMessage;
  Function(bool)? onConnectionStatusChanged;
  
  bool get isConnected => _isConnected;
  String get statusMessage => _statusMessage;
  
  Future<bool> connect() async {
    try {
      _client = MqttServerClient(_broker, _clientId);
      _client!.port = _port;
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 2000;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.onSubscribed = _onSubscribed;
      
      // 연결 시도
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .withWillTopic('s_window/status')
          .withWillMessage('Flutter App Disconnected')
          .startClean();
      
      _client!.connectionMessage = connMessage;
      
      debugPrint('MQTT 연결 시도 중... $_broker:$_port');
      
      await _client!.connect();
      
      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _isConnected = true;
        _statusMessage = '연결됨';
        debugPrint('MQTT 연결 성공!');
        
        // 토픽 구독
        await _subscribeToTopics();
        
        // 연결 상태 변경 콜백 호출
        onConnectionStatusChanged?.call(true);
        
        return true;
      } else {
        _statusMessage = '연결 실패: ${_client!.connectionStatus!.state}';
        debugPrint('MQTT 연결 실패: ${_client!.connectionStatus!.state}');
        return false;
      }
    } catch (e) {
      _statusMessage = '연결 오류: $e';
      debugPrint('MQTT 연결 오류: $e');
      return false;
    }
  }
  
  Future<void> _subscribeToTopics() async {
    try {
      // 펌프 제어 토픽 구독
      _client!.subscribe(_pumpTopic, MqttQos.atLeastOnce);
      debugPrint('토픽 구독: $_pumpTopic');
      
      // 센서 데이터 토픽 구독 (향후 확장용)
      _client!.subscribe(_sensorTopic, MqttQos.atLeastOnce);
      debugPrint('토픽 구독: $_sensorTopic');
      
      // 메시지 수신 리스너 설정
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);
        final topic = c[0].topic;
        
        debugPrint('MQTT 메시지 수신: $topic -> $payload');
        
        // 토픽별 메시지 처리
        if (topic == _pumpTopic) {
          onPumpMessage?.call(payload);
        } else if (topic == _sensorTopic) {
          onSensorMessage?.call(payload);
        }
      });
      
    } catch (e) {
      debugPrint('토픽 구독 오류: $e');
    }
  }
  
  Future<bool> publishMessage(String topic, String message) async {
    if (!_isConnected || _client == null) {
      debugPrint('MQTT가 연결되지 않음');
      return false;
    }
    
    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint('MQTT 메시지 발행: $topic -> $message');
      return true;
    } catch (e) {
      debugPrint('MQTT 메시지 발행 오류: $e');
      return false;
    }
  }
  
  // 펌프 제어 메시지 발행 (라즈베리파이와 통신)
  Future<bool> controlPump(String command) async {
    return await publishMessage(_pumpTopic, command);
  }
  
  // 센서 데이터 요청
  Future<bool> requestSensorData() async {
    return await publishMessage(_sensorTopic, 'REQUEST');
  }
  
  void _onConnected() {
    debugPrint('MQTT 연결됨');
    _isConnected = true;
    _statusMessage = '연결됨';
    onConnectionStatusChanged?.call(true);
  }
  
  void _onDisconnected() {
    debugPrint('MQTT 연결 해제됨');
    _isConnected = false;
    _statusMessage = '연결 해제됨';
    onConnectionStatusChanged?.call(false);
  }
  
  void _onSubscribed(String topic) {
    debugPrint('토픽 구독 완료: $topic');
  }
  
  void disconnect() {
    if (_client != null && _isConnected) {
      _client!.disconnect();
      _client = null;
      _isConnected = false;
      _statusMessage = '연결 해제됨';
      onConnectionStatusChanged?.call(false);
      debugPrint('MQTT 연결 해제');
    }
  }
  
  void dispose() {
    disconnect();
  }
}
