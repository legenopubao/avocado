import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class WeatherService {
  // 공공데이터포털 기상청 API 설정
  String get _apiKey {
    if (kIsWeb) {
      // 웹 환경에서는 기본값 사용
      return 'WEB_MODE_API_KEY';
    }
    return dotenv.env['PUBLIC_DATA_API_KEY'] ?? 'YOUR_PUBLIC_DATA_API_KEY';
  }
  static const String _baseUrl = 'http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0';
  bool _isLocationEnabled = false;
  bool _isWeatherEnabled = false;
  String _currentWeather = '날씨 OFF';
  String _currentLocation = '위치 없음';
  double _currentTemperature = 0.0;
  double _currentHumidity = 0.0;
  
  bool get isLocationEnabled => _isLocationEnabled;
  bool get isWeatherEnabled => _isWeatherEnabled;
  String get currentWeather => _currentWeather;
  String get currentLocation => _currentLocation;
  double get currentTemperature => _currentTemperature;
  double get currentHumidity => _currentHumidity;
  
  // 위치 권한 확인 및 활성화
  Future<bool> checkLocationPermission() async {
    try {
      // 웹 환경에서는 위치 서비스 사용 불가
      if (kIsWeb) {
        debugPrint('웹 환경: 위치 서비스 사용 불가');
        _isLocationEnabled = false;
        _isWeatherEnabled = false;
        return false;
      }
      
      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('위치 서비스가 비활성화되어 있습니다.');
        _isLocationEnabled = false;
        _isWeatherEnabled = false;
        return false;
      }
      
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('위치 권한이 거부되었습니다.');
          _isLocationEnabled = false;
          _isWeatherEnabled = false;
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('위치 권한이 영구적으로 거부되었습니다.');
        _isLocationEnabled = false;
        _isWeatherEnabled = false;
        return false;
      }
      
      _isLocationEnabled = true;
      debugPrint('위치 권한이 허용되었습니다.');
      return true;
      
    } catch (e) {
      debugPrint('위치 권한 확인 오류: $e');
      _isLocationEnabled = false;
      _isWeatherEnabled = false;
      return false;
    }
  }
  
  // 현재 위치 가져오기
  Future<Position?> getCurrentLocation() async {
    if (!_isLocationEnabled) {
      return null;
    }
    
    try {
      // 웹 환경에서는 기본 위치 반환
      if (kIsWeb) {
        debugPrint('웹 환경: 기본 위치 사용');
        return null;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugPrint('현재 위치: ${position.latitude}, ${position.longitude}');
      return position;
      
    } catch (e) {
      debugPrint('위치 가져오기 오류: $e');
      return null;
    }
  }
  
  // 좌표를 주소로 변환
  Future<String> getAddressFromCoordinates(double lat, double lon) async {
    try {
      // 웹 환경에서는 기본 주소 반환
      if (kIsWeb) {
        debugPrint('웹 환경: 기본 주소 사용');
        return '웹 환경';
      }
      
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '${place.locality ?? ''} ${place.administrativeArea ?? ''}'.trim();
        _currentLocation = address.isNotEmpty ? address : '알 수 없는 위치';
        return _currentLocation;
      }
    } catch (e) {
      debugPrint('주소 변환 오류: $e');
    }
    
    _currentLocation = '알 수 없는 위치';
    return _currentLocation;
  }
  
  // 날씨 정보 가져오기
  Future<String> getWeatherInfo(double lat, double lon) async {
    if (_apiKey == 'YOUR_PUBLIC_DATA_API_KEY') {
      debugPrint('공공데이터포털 기상청 API 키가 설정되지 않았습니다. 더미 날씨 데이터를 사용합니다.');
      return _getDummyWeather();
    }
    
    try {
      // 현재 날짜와 시간 계산
      DateTime now = DateTime.now();
      String baseDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      String baseTime = _getBaseTime(now);
      
      // 좌표를 기상청 격자 좌표로 변환 (간단한 변환)
      int nx = (lon * 100).round();
      int ny = (lat * 100).round();
      
      String url = '$_baseUrl/getVilageFcst?serviceKey=$_apiKey&pageNo=1&numOfRows=1000&dataType=JSON&base_date=$baseDate&base_time=$baseTime&nx=$nx&ny=$ny';
      debugPrint('날씨 정보 요청 URL: $url');
      
      http.Response response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        
        // 공공데이털 응답 구조 파싱
        if (data.containsKey('response') && data['response'] != null) {
          Map<String, dynamic> responseData = data['response'];
          if (responseData.containsKey('body') && responseData['body'] != null) {
            Map<String, dynamic> body = responseData['body'];
            if (body.containsKey('items') && body['items'] != null) {
              Map<String, dynamic> items = body['items'];
              if (items.containsKey('item') && items['item'] != null) {
                List<dynamic> itemList = items['item'];
                
                // 온도, 습도, 날씨 상태 파싱
                String temperature = '0';
                String humidity = '0';
                String weatherState = '맑음';
                
                for (var item in itemList) {
                  String category = item['category'] ?? '';
                  String value = item['fcstValue'] ?? '';
                  
                  if (category == 'TMP') { // 기온
                    temperature = value;
                    _currentTemperature = double.tryParse(value) ?? 0.0;
                  } else if (category == 'REH') { // 습도
                    humidity = value;
                    _currentHumidity = double.tryParse(value) ?? 0.0;
                  } else if (category == 'SKY') { // 하늘상태
                    weatherState = _translateSkyState(value);
                  }
                }
                
                _currentWeather = weatherState;
                _isWeatherEnabled = true;
                
                debugPrint('공공데이털 응답: 온도=$temperature°C, 습도=$humidity%, 날씨=$weatherState');
                return _currentWeather;
              }
            }
          }
        }
        
        debugPrint('공공데이털 응답 파싱 실패');
        _currentWeather = '날씨 OFF';
        _isWeatherEnabled = false;
        return _currentWeather;
        
      } else {
        debugPrint('날씨 정보 가져오기 실패 (상태 코드: ${response.statusCode})');
        debugPrint('응답 내용: ${response.body}');
        _currentWeather = '날씨 OFF';
        _isWeatherEnabled = false;
        return _currentWeather;
      }
      
    } catch (e) {
      debugPrint('날씨 정보 가져오기 오류: $e');
      _currentWeather = '날씨 OFF';
      _isWeatherEnabled = false;
      return _currentWeather;
    }
  }
  
  // 기상청 기준 시간 계산 (매시 45분에 발표)
  String _getBaseTime(DateTime now) {
    int hour = now.hour;
    int minute = now.minute;
    
    if (minute < 45) {
      hour = hour - 1;
    }
    
    if (hour < 0) {
      hour = 23;
    }
    
    return '${hour.toString().padLeft(2, '0')}00';
  }
  
  // 하늘상태 코드를 한국어로 변환
  String _translateSkyState(String skyCode) {
    switch (skyCode) {
      case '1':
        return '맑음';
      case '3':
        return '구름많음';
      case '4':
        return '흐림';
      default:
        return '맑음';
    }
  }
  
  // 더미 날씨 데이터 (API 키가 없을 때)
  String _getDummyWeather() {
    // DI 기반으로 더 현실적인 날씨 데이터 생성
    List<String> weathers = ['맑음', '구름', '비', '눈', '흐림', '안개'];
    _currentWeather = weathers[DateTime.now().millisecond % weathers.length];
    
    // 온도와 습도도 함께 생성 (DI 기반)
    _currentTemperature = 20.0 + (DateTime.now().millisecond % 20) - 10.0; // 10-30도
    _currentHumidity = 40.0 + (DateTime.now().millisecond % 40); // 40-80%
    
    _isWeatherEnabled = true;
    debugPrint('더미 날씨 데이터 생성: $_currentWeather, 온도: ${_currentTemperature.toStringAsFixed(1)}°C, 습도: ${_currentHumidity.toStringAsFixed(1)}%');
    return _currentWeather;
  }
  
  // 공공데이털 한국어 응답을 한국어로 번역
  String _translateWeather(String koreanWeather) {
    // 공공데이털은 한국어로 응답하므로 직접 반환
    // 필요시 추가 번역 로직 구현 가능
    
    // 기본적인 날씨 상태 매핑
    if (koreanWeather.contains('맑음') || koreanWeather.contains('clear')) {
      return '맑음';
    } else if (koreanWeather.contains('비') || koreanWeather.contains('rain')) {
      return '비';
    } else if (koreanWeather.contains('눈') || koreanWeather.contains('snow')) {
      return '눈';
    } else if (koreanWeather.contains('구름') || koreanWeather.contains('cloud')) {
      return '구름';
    } else if (koreanWeather.contains('천둥') || koreanWeather.contains('thunder')) {
      return '천둥번개';
    } else if (koreanWeather.contains('안개') || koreanWeather.contains('fog') || koreanWeather.contains('mist')) {
      return '안개';
    } else if (koreanWeather.contains('흐림') || koreanWeather.contains('overcast')) {
      return '흐림';
    } else {
      // 한국어 응답이면 그대로 반환, 영어면 번역
      return koreanWeather;
    }
  }
  
  // 날씨 기능 초기화
  Future<void> initializeWeather() async {
    if (kIsWeb) {
      debugPrint('웹 환경: 날씨 기능 비활성화');
      _isWeatherEnabled = false;
      _currentWeather = '웹 모드';
      return;
    }
    
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('위치 권한 거부됨');
        _isWeatherEnabled = false;
        _currentWeather = '위치 권한 거부';
        return;
      }
      
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('위치 서비스 비활성화');
        _isWeatherEnabled = false;
        _currentWeather = '위치 서비스 OFF';
        return;
      }
      
      _isLocationEnabled = true;
      _isWeatherEnabled = true;
      debugPrint('날씨 기능 초기화 완료');
      
    } catch (e) {
      debugPrint('날씨 기능 초기화 오류: $e');
      _isWeatherEnabled = false;
      _currentWeather = '초기화 오류';
    }
  }
  
  // 날씨 기능 비활성화
  void disableWeather() {
    _isWeatherEnabled = false;
    _currentWeather = '날씨 OFF';
    _currentLocation = '위치 없음';
  }
}
