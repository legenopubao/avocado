// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'services/communication_service.dart';
import 'services/api.dart';
import 'widgets/air_quality_card.dart';
import 'widgets/sensor_grid.dart';
import 'widgets/control_section.dart';
import 'widgets/polling_status.dart';
import 'widgets/connection_dialog.dart';

void main() {
  runApp(const SmartWindowApp());
}

class SmartWindowApp extends StatelessWidget {
  const SmartWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airocado',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
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

class _SmartWindowHomePageState extends State<SmartWindowHomePage> 
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final CommunicationService _commService = CommunicationService();
  AirQualityData? _airQualityData;
  DateTime? _lastUpdated;
  bool _isPolling = true;
  bool _isLoading = false;
  int _errorCount = 0;
  String? _lastError;
  Timer? _pollingTimer;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _loadBaseUrlAndStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _commService.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPolling) _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollingTimer?.cancel();
    }
  }

  Future<void> _loadBaseUrlAndStart() async {
    await _commService.loadSettings();
    
    _commService.dataStream.listen((data) {
      setState(() {
        _airQualityData = data;
        _lastUpdated = DateTime.now();
        _errorCount = 0;
        _lastError = null;
      });
    });
    
    if (!_commService.httpConnected && !_commService.mqttConnected) {
      _showWifiConnectionDialog();
    } else {
      _startPolling();
    }
    
    _fadeController.forward();
  }

  void _showWifiConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ConnectionDialog(
        onAutoConnect: _tryAutoConnect,
        onManualConnect: _showHttpSettings,
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _tryAutoConnect() async {
    final messenger = ScaffoldMessenger.of(context);
    final commonUrls = [
      'http://192.168.1.100:8000',
      'http://192.168.4.1:8000',
      'http://esp32.local:8000',
      'http://192.168.1.101:8000',
      'http://192.168.1.102:8000',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              const SizedBox(height: 16),
              const Text(
                "ESP32 연결 시도 중...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    bool connected = false;
    String? successfulUrl;

    for (String url in commonUrls) {
      try {
        debugPrint('자동 연결 시도: $url');
        final success = await _commService.setHttpConfig(url);
        if (success) {
          connected = true;
          successfulUrl = url;
          break;
        }
      } catch (e) {
        debugPrint('연결 실패: $url - $e');
        continue;
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }

    if (connected && successfulUrl != null) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('ESP32 연결 성공! ($successfulUrl)')),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      _startPolling();
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('자동 연결 실패. 수동 설정을 시도해주세요.')),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFFF9800),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      _showHttpSettings();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    if (!_isPolling || (!_commService.httpConnected && !_commService.mqttConnected)) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (!_commService.httpConnected && !_commService.mqttConnected) return;
    setState(() {
      _isLoading = true;
    });
    try {
      debugPrint('데이터 요청 시작');
      final data = await _commService.fetchData();
      if (data != null) {
        debugPrint('데이터 수신 성공: ${data.temperature}°C, ${data.humidity}%, PM2.5 ${data.pm25}');
      }
    } catch (e) {
      debugPrint('데이터 요청 실패: $e');
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

  Future<void> _controlBug(String command) async {
    if (!_commService.httpConnected && !_commService.mqttConnected) return;
    try {
      final success = await _commService.controlBug(command);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '성공' : '실패')),
      );
      if (success) {
        await _fetchData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }



  void _showSettingsDialog() {
    _showWifiConnectionDialog();
  }

  void _showHttpSettings() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wifi, size: 64, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  "ESP32 수동 연결",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "ESP32의 IP 주소를 입력해주세요",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: "ESP32 주소",
                      hintText: "http://192.168.1.100:8000",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      labelStyle: TextStyle(color: Color(0xFF666666)),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(3), width: 1),
                  ),
                  child: const Text(
                    "일반적인 ESP32 주소:\n• http://192.168.1.100:8000\n• http://192.168.4.1:8000\n• http://esp32.local:8000",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("취소", style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            final testUrl = controller.text.trim();
                            if (testUrl.isEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.warning, color: Colors.white),
                                        const SizedBox(width: 8),
                                        const Text('URL을 입력해주세요'),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFFFF9800),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                              return;
                            }
                            
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                      const SizedBox(height: 16),
                                      const Text(
                                        "ESP32 연결 테스트 중...",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            
                            try {
                              debugPrint('HTTP 연결 테스트 시작: $testUrl');
                              final success = await _commService.setHttpConfig(testUrl);
                              
                              if (mounted) {
                                Navigator.pop(context);
                              }
                              
                              if (success) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle, color: Colors.white),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text('ESP32 연결 성공! ($testUrl)')),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 3),
                                      backgroundColor: const Color(0xFF4CAF50),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                                _startPolling();
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error),
                                          const SizedBox(width: 8),
                                          const Expanded(child: Text('ESP32 연결 실패. 주소를 확인해주세요.')),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 5),
                                      backgroundColor: const Color(0xFFFF6B6B),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.pop(context);
                              }
                              
                              debugPrint('HTTP 연결 테스트 실패: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('연결 실패: $e')),
                                      ],
                                    ),
                                    duration: const Duration(seconds: 5),
                                    backgroundColor: const Color(0xFFFF6B6B),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            "연결 테스트",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final airData = _airQualityData;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        AirQualityCard(airData: airData),
                        const SizedBox(height: 24),
                        if (airData != null) ...[
                          SensorGrid(airData: airData),
                          const SizedBox(height: 24),
                        ],
                        ControlSection(
                          isBugDetected: airData?.bug ?? false,
                          isWindowOpen: airData?.window ?? false,
                          onBugDetect: () => _controlBug('bug_on'),
                          onBugRelease: () => _controlBug('bug_off'),
                          onWindowToggle: () => _controlBug('window_toggle'),
                        ),
                        const SizedBox(height: 24),
                        PollingStatus(
                          isPolling: _isPolling,
                          isLoading: _isLoading,
                          lastUpdated: _lastUpdated,
                          errorCount: _errorCount,
                          lastError: _lastError,
                          onPollingChanged: (value) {
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
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: !_isPolling ? _buildRefreshButton() : null,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'icons/Icon-512.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Airocado",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
                      child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: _showSettingsDialog,
            ),
        ),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return FloatingActionButton(
      onPressed: () {
        _fetchData();
      },
      backgroundColor: const Color(0xFF4CAF50),
      elevation: 8,
      child: const Icon(Icons.refresh, color: Colors.white),
    );
  }
}
