import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 阿里云 NLS 一句话识别服务
/// 流程：AccessKey → NLS Token（有效期 24h，自动缓存）→ 音频 POST → 转写文本
class AliASRService {
  static final instance = AliASRService._();
  AliASRService._();

  final _dio = Dio();

  String? _cachedToken;
  int _tokenExpiresAt = 0; // Unix timestamp (seconds)

  String get _keyId => dotenv.env['ALI_KEY_ID'] ?? '';
  String get _keySecret => dotenv.env['ALI_KEY_SECRET'] ?? '';
  String get _appKey => dotenv.env['ALI_NLS_APP_KEY'] ?? '';

  // ── Token 获取 ─────────────────────────────────────────────────────────────

  Future<String> _getToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // 提前 5 分钟刷新
    if (_cachedToken != null && now < _tokenExpiresAt - 300) {
      return _cachedToken!;
    }

    final date = _httpDate(DateTime.now().toUtc());
    const host = 'nls-meta.cn-shanghai.aliyuncs.com';
    const path = '/pop/2018-05-18/tokens';
    const accept = 'application/json';
    const contentType = 'application/json';

    // 签名字符串：POST\nAccept\nContent-MD5\nContent-Type\nDate\nResource
    // Body 为空 → Content-MD5 为空
    final stringToSign = 'POST\n$accept\n\n$contentType\n$date\n$path';
    final signature = _hmacSha1Base64(stringToSign, _keySecret);

    final resp = await _dio.post(
      'https://$host$path',
      data: '',
      options: Options(headers: {
        'Accept': accept,
        'Content-Type': contentType,
        'Date': date,
        'Host': host,
        'Authorization': 'acs $_keyId:$signature',
      }),
    );

    final token = resp.data['Token'];
    _cachedToken = token['Id'] as String;
    _tokenExpiresAt = token['ExpireTime'] as int;
    debugPrint('[AliASR] ✅ Token 已刷新，有效至 ${DateTime.fromMillisecondsSinceEpoch(_tokenExpiresAt * 1000)}');
    return _cachedToken!;
  }

  // ── 一句话识别 ──────────────────────────────────────────────────────────────

  /// 传入录音文件路径（wav/pcm），返回识别结果文本，失败返回 null
  Future<String?> transcribe(String audioPath) async {
    try {
      final token = await _getToken();
      final file = File(audioPath);
      final bytes = await file.readAsBytes();

      final ext = audioPath.split('.').last.toLowerCase();
      final format = ext == 'wav' ? 'wav' : 'pcm';

      final resp = await _dio.post<Map<String, dynamic>>(
        'https://nls-gateway.cn-shanghai.aliyuncs.com/stream/v1/asr'
        '?appkey=$_appKey&format=$format&sample_rate=16000'
        '&enable_punctuation_prediction=true&enable_inverse_text_normalization=true',
        data: bytes,
        options: Options(
          headers: {
            'X-NLS-Token': token,
            'Content-Type': 'application/octet-stream',
            'Content-Length': bytes.length,
          },
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      final status = resp.data?['status'];
      if (status == 20000000) {
        final result = resp.data?['result'] as String?;
        debugPrint('[AliASR] ✅ 识别结果: $result');
        return result;
      } else {
        debugPrint('[AliASR] ❌ 识别失败 status=$status msg=${resp.data?['message']}');
        return null;
      }
    } catch (e) {
      debugPrint('[AliASR] ❌ 请求异常: $e');
      return null;
    }
  }

  // ── 工具函数 ────────────────────────────────────────────────────────────────

  String _hmacSha1Base64(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha1, keyBytes);
    final digest = hmac.convert(dataBytes);
    return base64Encode(digest.bytes);
  }

  /// RFC 2822 格式日期，如 Mon, 01 Jun 2026 06:00:00 GMT
  String _httpDate(DateTime utc) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = days[utc.weekday - 1];
    final m = months[utc.month - 1];
    final dd = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return '$d, $dd $m ${utc.year} $hh:$mm:$ss GMT';
  }
}
