'''// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api.dart';

void main() {
  runApp(const SmartWindowApp());
}

class SmartWindowApp extends StatelessWidget {
  const SmartWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스마트 창문',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SmartWindowHomePage(),
    );
  }
}

class SmartWindowHomePage extends StatefulWidget {
  const SmartWindowHomePage({super.key});

  @override
  State<SmartWindowHomePage> createState() => _SmartWindowHomePageState();
}

class _SmartWindowHomePageState extends State<SmartWindowHomePage> with WidgetsBindingObserver {
  final ApiClient _apiClient = ApiClient();
  String? _baseUrl;
  AirQualityData? _airQualityData;
  DateTime? _lastUpdated;
  bool _isPolling = true;
  bool _isLoading = false;
  int _errorCount = 0;
  String? _lastError;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBaseUrlAndStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPolling) {
        _startPolling();
      }
    } else if (state == AppLifecycleState.paused) {
      _pollingTimer?.cancel();
    }
  }

  Future<void> _loadBaseUrlAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('baseUrl');
    if (savedUrl == null || savedUrl.isEmpty) {
      _showSettingsDialog();
    } else {
      setState(() {
        _baseUrl = savedUrl;
      });
      _startPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (!_isPolling || _baseUrl == null) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (_baseUrl == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await _apiClient.getData(_baseUrl!);
      setState(() {
        _airQualityData = data;
        _lastUpdated = DateTime.now();
        _errorCount = 0;
        _lastError = null;
      });
    } catch (e) {
      setState(() {
        _errorCount++;
        _lastError = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _controlBug(Future<Map<String, dynamic>> Function(String) apiFunc) async {
    if (_baseUrl == null) return;
    try {
      final result = await apiFunc(_baseUrl!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['msg'] ?? '성공')),
      );
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  // 등급 산출
  Map<String, dynamic> _evaluateAirQuality(AirQualityData data) {
    int pmScore;
    if (data.pm25 <= 15) {
      pmScore = 0;
    } else if (data.pm25 <= 35) {
      pmScore = 1;
    } else if (data.pm25 <= 75) {
      pmScore = 2;
    } else {
      pmScore = 3;
    }

    int tempScore;
    final tempDiff = (data.temp - 22).abs();
    if (tempDiff <= 3) {
      tempScore = 0;
    } else if (tempDiff <= 6) {
      tempScore = 1;
    } else {
      tempScore = 2;
    }

    int humScore;
    if (data.hum >= 40 && data.hum <= 60) {
      humScore = 0;
    } else if ((data.hum >= 30 && data.hum < 40) || (data.hum > 60 && data.hum <= 70)) {
      humScore = 1;
    } else {
      humScore = 2;
    }

    final total = 0.6 * pmScore + 0.25 * tempScore + 0.15 * humScore;

    if (total < 0.5) {
      return {"status": "매우 좋음", "color": Colors.green};
    } else if (total < 1.2) {
      return {"status": "좋음", "color": Colors.blue};
    } else if (total < 2.0) {
      return {"status": "나쁨", "color": Colors.orange};
    } else {
      return {"status": "환기 필수", "color": Colors.red};
    }
  }

  void _showSettingsDialog() {
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController(text: _baseUrl);
        return AlertDialog(
          title: const Text("ESP32 주소 설정"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "http://192.168.x.xx",
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final data = await _apiClient.getData(controller.text, timeout: const Duration(seconds: 2));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('연결 성공: 온도 ${data.temp}°C, 습도 ${data.hum}%, PM2.5 ${data.pm25}')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('연결 실패: $e')),
                    );
                  }
                },
                child: const Text("연결 테스트"),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            ElevatedButton(
              onPressed: () async {
                final newUrl = controller.text;
                if (newUrl.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('baseUrl', newUrl);
                  setState(() {
                    _baseUrl = newUrl;
                  });
                  _startPolling();
                  if(mounted) Navigator.pop(context);
                }
              },
              child: const Text("저장"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final airData = _airQualityData;
    Map<String, dynamic> airStatus = {"status": "연결 안 됨", "color": Colors.grey};

    if (airData != null && _errorCount < 3) {
      airStatus = _evaluateAirQuality(airData);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("스마트 창문"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 공기질 상태 배너
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: airStatus["color"],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    airStatus["status"],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (airData != null && _errorCount < 3)
                    Text(
                      "${airData.temp.toStringAsFixed(1)}°C • ${airData.hum.toStringAsFixed(1)}% • PM2.5 ${airData.pm25.toStringAsFixed(1)}",
                      style: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
            ),
            // 센서 데이터 카드
            if (airData != null) ...[
              _buildDataCard(Icons.thermostat, "온도", "${airData.temp.toStringAsFixed(1)} °C"),
              _buildDataCard(Icons.water_drop, "습도", "${airData.hum.toStringAsFixed(1)} %"),
              _buildDataCard(Icons.blur_on, "PM2.5", "${airData.pm25.toStringAsFixed(1)} µg/m³"),
            ],
            const SizedBox(height: 16),
            // 벌레 감지 섹션
            _buildControlSection(),
            const SizedBox(height: 16),
            // 폴링 상태
            _buildPollingStatus(),
          ],
        ),
      ),
      floatingActionButton: !_isPolling
          ? FloatingActionButton(
              onPressed: _fetchData,
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }

  Widget _buildDataCard(IconData icon, String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 18)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildControlSection() {
    final bool isBugDetected = _airQualityData?.bug ?? false;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isBugDetected ? 1.0 : 0.4,
              child: const Icon(Icons.pest_control, size: 32, color: Colors.brown),
            ),
            const SizedBox(width: 8),
            Text(
              isBugDetected ? '벌레 감지됨' : '감지 해제',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.block),
              label: const Text('벌레 감지 (닫기)'),
              onPressed: () => _controlBug(_apiClient.bugOn),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.autorenew),
              label: const Text('해제 (자동 복귀)'),
              onPressed: () => _controlBug(_apiClient.bugOff),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPollingStatus() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('자동 갱신'),
            Switch(
              value: _isPolling,
              onChanged: (value) {
                setState(() {
                  _isPolling = value;
                  if (_isPolling) {
                    _startPolling();
                  } else {
                    _pollingTimer?.cancel();
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isLoading ? 1.0 : 0.0,
          child: const LinearProgressIndicator(),
        ),
        const SizedBox(height: 8),
        Text(
          _lastUpdated != null
              ? '마지막 갱신: ${DateFormat('HH:mm:ss').format(_lastUpdated!)}'
              : '갱신 대기 중...',
          style: const TextStyle(color: Colors.grey),
        ),
        if (_errorCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '연결 오류: $_lastError ($_errorCount회)',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }
}
''