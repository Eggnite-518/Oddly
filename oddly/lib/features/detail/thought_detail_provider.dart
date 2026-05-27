import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../services/ai_service.dart';

// ── State ──────────────────────────────────────────────────────────────────

enum DetailPhase {
  loading,         // 初始加载
  askingQuestion,  // 显示 AI 问题，等待用户回答
  submittingAnswer,// 提交回答中
  generatingInsight, // 生成洞察卡片中
  showingInsight,  // 显示洞察卡片（终态）
  error,
}

class DetailState {
  final DetailPhase phase;
  final Thought? thought;
  final List<AiConversation> conversations;
  final InsightCard? insightCard;
  final String? currentQuestion;
  final int? currentConvId;
  final String? errorMessage;

  const DetailState({
    this.phase = DetailPhase.loading,
    this.thought,
    this.conversations = const [],
    this.insightCard,
    this.currentQuestion,
    this.currentConvId,
    this.errorMessage,
  });

  DetailState copyWith({
    DetailPhase? phase,
    Thought? thought,
    List<AiConversation>? conversations,
    InsightCard? insightCard,
    String? currentQuestion,
    int? currentConvId,
    String? errorMessage,
    bool clearInsight = false,
    bool clearQuestion = false,
    bool clearConvId = false,
  }) =>
      DetailState(
        phase: phase ?? this.phase,
        thought: thought ?? this.thought,
        conversations: conversations ?? this.conversations,
        insightCard: clearInsight ? null : (insightCard ?? this.insightCard),
        currentQuestion:
            clearQuestion ? null : (currentQuestion ?? this.currentQuestion),
        currentConvId:
            clearConvId ? null : (currentConvId ?? this.currentConvId),
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────

class ThoughtDetailNotifier extends StateNotifier<DetailState> {
  final int thoughtId;
  final AppDatabase _db;
  final AiService _ai;

  ThoughtDetailNotifier(this.thoughtId)
      : _db = AppDatabase.instance,
        _ai = AiService(),
        super(const DetailState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final thought = await _db.getThought(thoughtId);
      if (thought == null) {
        state = state.copyWith(phase: DetailPhase.error, errorMessage: '找不到这条想法');
        return;
      }
      final conversations = await _db.getConversationsForThought(thoughtId);
      final insightCard = await _db.getInsightCard(thoughtId);

      if (insightCard != null) {
        // 已经分析过了，直接展示
        state = state.copyWith(
          phase: DetailPhase.showingInsight,
          thought: thought,
          conversations: conversations,
          insightCard: insightCard,
        );
        return;
      }

      state = state.copyWith(thought: thought, conversations: conversations);
      await _askFirstQuestion(thought);
    } catch (e, stack) {
      debugPrint('[Oddly] 初始化失败: $e\n$stack');
      state = state.copyWith(
          phase: DetailPhase.error, errorMessage: '加载失败：$e');
    }
  }

  Future<void> _askFirstQuestion(Thought thought) async {
    try {
      final result = await _ai.generateFirstQuestion(thought.content);
      final convId = await _db.insertConversation(AiConversation(
        thoughtId: thoughtId,
        round: 1,
        question: result.question,
        createdAt: DateTime.now(),
      ));
      state = state.copyWith(
        phase: DetailPhase.askingQuestion,
        currentQuestion: result.question,
        currentConvId: convId,
      );
    } catch (e) {
      // AI 失败就直接生成洞察
      await _generateInsight();
    }
  }

  // 用户提交了回答
  Future<void> submitAnswer(String answer) async {
    final convId = state.currentConvId;
    if (convId == null) return;
    state = state.copyWith(phase: DetailPhase.submittingAnswer);

    await _db.saveAnswer(convId, answer);
    final updatedConvs = await _db.getConversationsForThought(thoughtId);
    state = state.copyWith(conversations: updatedConvs);

    await _maybeContinue(updatedConvs);
  }

  // 用户跳过了这个问题
  Future<void> skipQuestion() async {
    final convId = state.currentConvId;
    if (convId == null) return;
    state = state.copyWith(phase: DetailPhase.submittingAnswer);

    await _db.markSkipped(convId);
    final updatedConvs = await _db.getConversationsForThought(thoughtId);
    state = state.copyWith(conversations: updatedConvs);

    await _generateInsight();
  }

  // AI 决定是否继续追问
  Future<void> _maybeContinue(List<AiConversation> convs) async {
    final thought = state.thought!;
    if (convs.length >= 3) {
      await _generateInsight();
      return;
    }

    try {
      final history = convs.map((c) => {
        'question': c.question,
        'answer': c.answer,
      }).toList();

      final result = await _ai.generateContinueQuestion(
        thoughtContent: thought.content,
        conversationHistory: history,
      );

      if (!result.shouldContinue || result.question.isEmpty) {
        await _generateInsight();
        return;
      }

      final convId = await _db.insertConversation(AiConversation(
        thoughtId: thoughtId,
        round: convs.length + 1,
        question: result.question,
        createdAt: DateTime.now(),
      ));
      final updatedConvs = await _db.getConversationsForThought(thoughtId);
      state = state.copyWith(
        phase: DetailPhase.askingQuestion,
        conversations: updatedConvs,
        currentQuestion: result.question,
        currentConvId: convId,
      );
    } catch (e) {
      await _generateInsight();
    }
  }

  // 生成洞察卡片
  Future<void> _generateInsight() async {
    state = state.copyWith(
      phase: DetailPhase.generatingInsight,
      clearQuestion: true,
      clearConvId: true,
    );

    try {
      // 重新从 DB 读最新的 thought，确保拿到 ContextService 已写入的天气/城市
      final thought = await _db.getThought(thoughtId) ?? state.thought!;
      state = state.copyWith(thought: thought);
      final convs = state.conversations;
      final history = convs.map((c) => {
        'question': c.question,
        'answer': c.answer,
      }).toList();

      final result = await _ai.generateInsightCard(
        thoughtContent: thought.content,
        conversationHistory: history,
        weather: thought.weather,
        locationName: thought.locationName,
      );

      await _db.insertInsightCard(InsightCard(
        thoughtId: thoughtId,
        interpretation: result.interpretation,
        psychologyTheory: result.psychologyTheory,
        psychologyExplanation: result.psychologyExplanation,
        actionGuide: result.actionGuide,
        createdAt: DateTime.now(),
      ));

      await _db.markThoughtAnalyzed(thoughtId, result.emotionTags);

      final card = await _db.getInsightCard(thoughtId);
      final updatedThought = await _db.getThought(thoughtId);

      state = state.copyWith(
        phase: DetailPhase.showingInsight,
        insightCard: card,
        thought: updatedThought,
      );
    } catch (e, stack) {
      debugPrint('[Oddly] 洞察生成失败: $e');
      debugPrint('[Oddly] StackTrace: $stack');
      state = state.copyWith(
        phase: DetailPhase.error,
        errorMessage: '洞察生成失败：${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  // 手动重试生成洞察
  Future<void> retryInsight() async => _generateInsight();

  Future<void> addTag(String tag) async {
    final thought = state.thought;
    if (thought == null) return;
    final trimmed = tag.trim();
    if (trimmed.isEmpty || thought.emotionTags.contains(trimmed)) return;
    final updated = [...thought.emotionTags, trimmed];
    await _db.updateEmotionTags(thoughtId, updated);
    state = state.copyWith(
      thought: Thought(
        id: thought.id,
        content: thought.content,
        createdAt: thought.createdAt,
        latitude: thought.latitude,
        longitude: thought.longitude,
        locationName: thought.locationName,
        weather: thought.weather,
        temperature: thought.temperature,
        emotionTags: updated,
        isAnalyzed: thought.isAnalyzed,
      ),
    );
  }

  Future<void> removeTag(String tag) async {
    final thought = state.thought;
    if (thought == null) return;
    final updated = thought.emotionTags.where((t) => t != tag).toList();
    await _db.updateEmotionTags(thoughtId, updated);
    state = state.copyWith(
      thought: Thought(
        id: thought.id,
        content: thought.content,
        createdAt: thought.createdAt,
        latitude: thought.latitude,
        longitude: thought.longitude,
        locationName: thought.locationName,
        weather: thought.weather,
        temperature: thought.temperature,
        emotionTags: updated,
        isAnalyzed: thought.isAnalyzed,
      ),
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final thoughtDetailProvider = StateNotifierProvider.family<
    ThoughtDetailNotifier, DetailState, int>(
  (ref, thoughtId) => ThoughtDetailNotifier(thoughtId),
);
