// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'services/communication_service.dart';
import 'services/api.dart';
import 'widgets/air_quality_card.dart';
import 'widgets/sensor_grid.dart';
import 'widgets/control_section.dart';
import 'widgets/polling_status.dart';
import 'widgets/connection_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 웹 환경이 아닐 때만 .env 파일 로드
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: ".env");
      debugPrint('환경 변수 로드 완료');
    } catch (e) {
      debugPrint('환경 변수 로드 실패: $e');
    }
  } else {
    debugPrint('웹 환경: 환경 변수 로드 건너뜀');
  }
  
  runApp(const SmartWindowApp());
}

class SmartWindowApp extends StatelessWidget {
  const SmartWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airocado',
      debugShowCheckedModeBanner: false, // 디버그 배너 제거
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
  bool _isAutoMode = true; // 자동 창문 제어 모드
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
    _initializeWeather(); // 날씨 서비스 초기화
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
    _pollingTimer = Timer.periodic(
      // 테스트 모드일 때는 2초, 실제 모드일 때는 5초
      _commService.isTestMode ? const Duration(seconds: 2) : const Duration(seconds: 5),
      (timer) => _fetchData(),
    );
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
        debugPrint('데이터 수신: ${data.toString()}');
        debugPrint('불쾌지수: ${data.di.toStringAsFixed(1)}');
        debugPrint('PM2.5: ${data.pm25.toStringAsFixed(1)}');
        debugPrint('PM10: ${data.pm10.toStringAsFixed(1)}');
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

  // 벌레 감지 제어
  Future<void> _controlBug(String command) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final success = await _commService.controlBug(command);
      
      if (success) {
        // 테스트 모드일 때는 즉시 데이터 새로고침
        if (_commService.isTestMode) {
          await _fetchData();
        }
        
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$command 명령이 성공적으로 처리되었습니다.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // 창문 제어 명령인 경우 즉시 상태 업데이트
        if (command == 'window_toggle') {
          // 창문 상태 토글
          if (_airQualityData != null) {
            _airQualityData = AirQualityData(
              di: _airQualityData!.di,
              weather: _airQualityData!.weather,
              pm25: _airQualityData!.pm25,
              pm10: _airQualityData!.pm10,
              bug: _airQualityData!.bug,
              window: !_airQualityData!.window, // 창문 상태 토글
              timestamp: DateTime.now(),
            );
            
            // 상태 변경 확인을 위한 추가 디버그 출력
            debugPrint('창문 상태 업데이트 완료: ${_airQualityData!.window ? "열림" : "닫힘"}');
          }
        }
      } else {
        // 실패 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('제어 명령 처리에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('벌레 감지 제어 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('제어 오류: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  // 날씨 서비스 초기화
  Future<void> _initializeWeather() async {
    try {
      await _commService.initializeWeather();
      debugPrint('날씨 서비스 초기화 완료');
    } catch (e) {
      debugPrint('날씨 서비스 초기화 오류: $e');
    }
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
                          isAutoMode: _isAutoMode,
                          onBugDetect: () => _controlBug('bug_on'),
                          onBugRelease: () => _controlBug('bug_off'),
                          onWindowToggle: () => _controlBug('window_toggle'),
                          onAutoModeToggle: () {
                            setState(() {
                              _isAutoMode = !_isAutoMode;
                            });
                          },
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
                        
                        // 테스트 모드 토글
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.science,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "테스트 모드",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      _commService.isTestMode 
                                        ? "ESP32 연결 없이 더미 데이터로 테스트 중"
                                        : "실제 ESP32 데이터 사용",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _commService.isTestMode,
                                onChanged: (value) {
                                  setState(() {
                                    _commService.setTestMode(value);
                                    if (value) {
                                      // 테스트 모드 활성화 시 즉시 데이터 가져오기
                                      _fetchData();
                                    }
                                  });
                                },
                                activeThumbColor: Colors.orange,
                              ),
                            ],
                          ),
                        ),
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
