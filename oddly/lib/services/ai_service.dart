import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/constants/prompts.dart';
import '../data/database/app_database.dart';

class AiQuestionResult {
  final String question;
  const AiQuestionResult({required this.question});
}

class AiContinueResult {
  final bool shouldContinue;
  final String question;
  const AiContinueResult({required this.shouldContinue, required this.question});
}

class AiInsightResult {
  final String interpretation;
  final String psychologyTheory;
  final String psychologyExplanation;
  final List<String> actionGuide;
  final List<String> emotionTags;
  final String corePattern;
  final List<String> recommendedNextFrameworks;

  const AiInsightResult({
    required this.interpretation,
    required this.psychologyTheory,
    required this.psychologyExplanation,
    required this.actionGuide,
    required this.emotionTags,
    required this.corePattern,
    this.recommendedNextFrameworks = const [],
  });

  factory AiInsightResult.fromJson(Map<String, dynamic> json) {
    return AiInsightResult(
      interpretation: json['interpretation'] as String,
      psychologyTheory: json['psychology_theory'] as String,
      psychologyExplanation: json['psychology_explanation'] as String,
      actionGuide: (json['action_guide'] as List).cast<String>(),
      emotionTags: (json['emotion_tags'] as List).cast<String>(),
      corePattern: json['core_pattern'] as String? ?? '',
      recommendedNextFrameworks:
          (json['recommended_next_frameworks'] as List? ?? []).cast<String>(),
    );
  }
}

class AiAlternativePerspectiveResult {
  final String interpretation;
  final String psychologyTheory;
  final String psychologyExplanation;
  final List<String> actionGuide;

  const AiAlternativePerspectiveResult({
    required this.interpretation,
    required this.psychologyTheory,
    required this.psychologyExplanation,
    required this.actionGuide,
  });

  factory AiAlternativePerspectiveResult.fromJson(Map<String, dynamic> json) {
    return AiAlternativePerspectiveResult(
      interpretation: json['interpretation'] as String,
      psychologyTheory: json['psychology_theory'] as String,
      psychologyExplanation: json['psychology_explanation'] as String,
      actionGuide: (json['action_guide'] as List).cast<String>(),
    );
  }
}

class AiPersonaResult {
  final bool isNew;
  final String? matchedId;
  final String newName;
  final String newDescription;
  final List<String> linkedTheories;
  final List<String> linkedEmotions;

  const AiPersonaResult({
    required this.isNew,
    this.matchedId,
    required this.newName,
    required this.newDescription,
    required this.linkedTheories,
    required this.linkedEmotions,
  });

  factory AiPersonaResult.fromJson(Map<String, dynamic> json) {
    final newCurrent = json['new_current'] as Map<String, dynamic>? ?? {};
    return AiPersonaResult(
      isNew: json['is_new'] as bool? ?? true,
      matchedId: json['matched_id'] as String?,
      newName: newCurrent['name'] as String? ?? '',
      newDescription: newCurrent['description'] as String? ?? '',
      linkedTheories:
          (json['linked_theories'] as List? ?? []).cast<String>(),
      linkedEmotions:
          (json['linked_emotions'] as List? ?? []).cast<String>(),
    );
  }
}

class AiService {
  late final Dio _dio;
  static const String _baseUrl = 'https://api.deepseek.com/v1';
  static const String _model = 'deepseek-chat';

  AiService() {
    final apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? '';
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120), // 洞察生成需要更长时间
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    ));

    // 打印请求/响应到控制台，方便调试
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: true,
      error: true,
      logPrint: (obj) => debugPrint('[AI] $obj'),
    ));
  }

  Future<AiQuestionResult> generateFirstQuestion(
    String thoughtContent, {
    String personaPrefix = '',
  }) async {
    final response = await _chat(
      systemPrompt: OddlyPrompts.socraticQuestionSystem,
      userMessage: OddlyPrompts.buildFirstQuestionUserMessage(
        thoughtContent: thoughtContent,
        personaPrefix: personaPrefix,
      ),
    );
    final json = _parseJson(response);
    return AiQuestionResult(question: json['question'] as String);
  }

  Future<AiContinueResult> generateContinueQuestion({
    required String thoughtContent,
    required List<Map<String, String?>> conversationHistory,
  }) async {
    final response = await _chat(
      systemPrompt: OddlyPrompts.continueQuestionSystem,
      userMessage: OddlyPrompts.buildContinueQuestionUserMessage(
        thoughtContent: thoughtContent,
        conversationHistory: conversationHistory,
      ),
    );
    final json = _parseJson(response);
    return AiContinueResult(
      shouldContinue: json['should_continue'] as bool,
      question: json['question'] as String? ?? '',
    );
  }

  Future<AiInsightResult> generateInsightCard({
    required String thoughtContent,
    required List<Map<String, String?>> conversationHistory,
    String? weather,
    String? locationName,
    String personaPrefix = '',
  }) async {
    final userMsg = OddlyPrompts.buildInsightCardUserMessage(
      thoughtContent: thoughtContent,
      conversationHistory: conversationHistory,
      weather: weather,
      locationName: locationName,
    );
    final response = await _chat(
      systemPrompt: OddlyPrompts.insightCardSystem,
      userMessage: personaPrefix.isEmpty ? userMsg : '$personaPrefix$userMsg',
    );
    final json = _parseJson(response);
    return AiInsightResult.fromJson(json);
  }

  Future<AiAlternativePerspectiveResult> generateAlternativePerspective({
    required String thoughtContent,
    required List<Map<String, String?>> conversationHistory,
    required String targetFramework,
    String? weather,
    String? locationName,
  }) async {
    final response = await _chat(
      systemPrompt: OddlyPrompts.alternativePerspectiveSystem,
      userMessage: OddlyPrompts.buildAlternativePerspectiveUserMessage(
        thoughtContent: thoughtContent,
        conversationHistory: conversationHistory,
        targetFramework: targetFramework,
        weather: weather,
        locationName: locationName,
      ),
    );
    final json = _parseJson(response);
    return AiAlternativePerspectiveResult.fromJson(json);
  }

  Future<AiPersonaResult> extractPersonaCurrent({
    required String thoughtContent,
    required List<String> emotionTags,
    required InsightCard card,
    required List<Map<String, dynamic>> existingCurrents,
  }) async {
    final response = await _chat(
      systemPrompt: OddlyPrompts.personaExtractionSystem,
      userMessage: OddlyPrompts.buildPersonaExtractionUserMessage(
        thoughtContent: thoughtContent,
        corePattern: card.corePattern,
        interpretation: card.interpretation,
        psychologyTheory: card.psychologyTheory,
        emotionTags: emotionTags,
        existingCurrents: existingCurrents,
      ),
    );
    final json = _parseJson(response);
    return AiPersonaResult.fromJson(json);
  }

  Future<String> _chat({
    required String systemPrompt,
    required String userMessage,
  }) async {
    try {
      final res = await _dio.post('/chat/completions', data: {
        'model': _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'response_format': {'type': 'json_object'},
        'temperature': 0.8,
      });
      return res.data['choices'][0]['message']['content'] as String;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data?.toString() ?? '';
      if (status == 401) throw Exception('API Key 无效或未设置 (401)');
      if (status == 429) throw Exception('请求过于频繁，稍后再试 (429)');
      if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('AI 响应超时，请重试');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception('网络连接失败，请检查网络');
      }
      throw Exception('API 错误 $status: $body');
    }
  }

  Map<String, dynamic> _parseJson(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      // 有时模型会在 JSON 外面包裹 markdown 代码块，做一次清洗
      final cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      try {
        return jsonDecode(cleaned) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('AI 返回格式解析失败，原始内容：${raw.length > 200 ? raw.substring(0, 200) : raw}');
      }
    }
  }
}
