import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ContextInfo {
  final String timePeriod;  // 清晨 / 上午 / 下午 / 傍晚 / 深夜
  final String? city;
  final String? weather;
  final int? temperature;
  final double? latitude;
  final double? longitude;

  const ContextInfo({
    required this.timePeriod,
    this.city,
    this.weather,
    this.temperature,
    this.latitude,
    this.longitude,
  });

  // 用于 UI 展示的单行摘要
  String get summary {
    final parts = <String>[timePeriod];
    if (weather != null) parts.add(weather!);
    if (temperature != null) parts.add('$temperature°');
    if (city != null) parts.add(city!);
    return parts.join(' · ');
  }

  bool get hasLocation => city != null;
  bool get hasWeather => weather != null;
}

class ContextService {
  static final ContextService instance = ContextService._();
  ContextService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // 入口：拿全部情境，任何子步骤失败都不影响整体
  Future<ContextInfo> capture() async {
    debugPrint('[Context] ========== 开始抓取情境 ==========');
    final timePeriod = _getTimePeriod();
    double? lat, lon;
    String? city;
    String? weather;
    int? temperature;

    try {
      final loc = await _getLocation();
      lat = loc['lat'];
      lon = loc['lon'];
      city = loc['city'];
      debugPrint('[Context] ✅ IP 定位成功: city=$city, lat=$lat, lon=$lon');
    } catch (e) {
      debugPrint('[Context] ❌ IP 定位失败: $e');
    }

    if (lat != null && lon != null) {
      try {
        final w = await _getWeather(lat, lon);
        weather = w['weather'];
        temperature = w['temperature'];
        debugPrint('[Context] ✅ 天气成功: weather=$weather, temp=$temperature');
      } catch (e) {
        debugPrint('[Context] ❌ 天气获取失败: $e');
      }
    }

    final info = ContextInfo(
      timePeriod: timePeriod,
      city: city,
      weather: weather,
      temperature: temperature,
      latitude: lat,
      longitude: lon,
    );
    debugPrint('[Context] ========== 完成: ${info.summary} ==========');
    return info;
  }

  // ── 时间段 ──────────────────────────────────────────────────────────────

  String _getTimePeriod() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 9) return '清晨';
    if (hour >= 9 && hour < 12) return '上午';
    if (hour >= 12 && hour < 14) return '午后';
    if (hour >= 14 && hour < 18) return '下午';
    if (hour >= 18 && hour < 21) return '傍晚';
    if (hour >= 21 && hour < 24) return '深夜';
    return '凌晨'; // 0-5点
  }

  // ── IP 定位（获取省份 + 经纬度）────────────────────────────────────────
  // 使用 Bilibili 的公共 IP 接口：HTTPS、国内可达、返回中文省份和经纬度
  // 注意：只返回省份级别，对直辖市（北京/上海/天津/重庆）就是城市本身
  Future<Map<String, dynamic>> _getLocation() async {
    final res = await _dio.get(
      'https://api.bilibili.com/x/web-interface/zone',
    );
    final body = res.data as Map<String, dynamic>;
    if (body['code'] != 0) throw Exception('IP 定位返回失败: ${body['message']}');

    final data = body['data'] as Map<String, dynamic>;
    final province = data['province'] as String?;

    return {
      'lat': (data['latitude'] as num).toDouble(),
      'lon': (data['longitude'] as num).toDouble(),
      'city': province,
    };
  }

  // ── 天气（open-meteo.com，完全免费，无需 Key）──────────────────────────
  Future<Map<String, dynamic>> _getWeather(double lat, double lon) async {
    final res = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
        'forecast_days': 1,
      },
    );
    final current = res.data['current'] as Map<String, dynamic>;
    final code = (current['weather_code'] as num).toInt();
    final temp = (current['temperature_2m'] as num).round();

    return {
      'weather': _weatherCodeToLabel(code),
      'temperature': temp,
    };
  }

  // WMO 天气代码 → 中文标签
  String _weatherCodeToLabel(int code) {
    if (code == 0) return '晴';
    if (code <= 2) return '多云';
    if (code == 3) return '阴';
    if (code <= 49) return '雾';
    if (code <= 59) return '小雨';
    if (code <= 69) return '雨';
    if (code <= 79) return '雪';
    if (code <= 84) return '阵雨';
    if (code <= 94) return '雷阵雨';
    return '雷雨';
  }
}
