import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 阿里云 NLS 一句话识别服务
/// 流程：后端换 Token（24h 缓存）→ 客户端直接上传音频给阿里云
class AliASRService {
  static final instance = AliASRService._();
  AliASRService._();

  final _dio = Dio();

  static const _backendUrl = 'https://oddly-backend-euyqpaxdet.cn-hangzhou.fcapp.run';

  String? _cachedToken;
  String? _cachedAppKey;
  int _tokenExpiresAt = 0;

  // ── Token 获取（从后端，不再在客户端签名）────────────────────────────────────

  Future<({String token, String appKey})> _getToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_cachedToken != null && _cachedAppKey != null && now < _tokenExpiresAt - 300) {
      return (token: _cachedToken!, appKey: _cachedAppKey!);
    }

    final resp = await _dio.post<Map<String, dynamic>>(
      '$_backendUrl/asr/token',
      data: <String, dynamic>{},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    _cachedToken  = resp.data!['token']  as String;
    _cachedAppKey = resp.data!['appKey'] as String;
    // 后端 token 有效期 24h，本地记录过期时间（当前时间 + 23h）
    _tokenExpiresAt = now + 23 * 3600;

    debugPrint('[AliASR] ✅ Token 已从后端刷新');
    return (token: _cachedToken!, appKey: _cachedAppKey!);
  }

  // ── 一句话识别 ──────────────────────────────────────────────────────────────

  /// 传入录音文件路径（wav/pcm），返回识别结果文本，失败返回 null
  Future<String?> transcribe(String audioPath) async {
    try {
      final (:token, :appKey) = await _getToken();
      final file  = File(audioPath);
      final bytes = await file.readAsBytes();

      final ext    = audioPath.split('.').last.toLowerCase();
      final format = ext == 'wav' ? 'wav' : 'pcm';

      final resp = await _dio.post<Map<String, dynamic>>(
        'https://nls-gateway.cn-shanghai.aliyuncs.com/stream/v1/asr'
        '?appkey=$appKey&format=$format&sample_rate=16000'
        '&enable_punctuation_prediction=true&enable_inverse_text_normalization=true',
        data: bytes,
        options: Options(
          headers: {
            'X-NLS-Token':   token,
            'Content-Type':  'application/octet-stream',
            'Content-Length': bytes.length,
          },
          responseType: ResponseType.json,
          sendTimeout:    const Duration(seconds: 30),
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
}
