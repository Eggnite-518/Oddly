import 'package:flutter/foundation.dart';
import '../data/database/app_database.dart';
import 'ai_service.dart';

class PersonaService {
  PersonaService._();
  static final PersonaService instance = PersonaService._();

  final AppDatabase _db = AppDatabase.instance;

  // ── 暗流提取与合并 ──────────────────────────────────────────────────────────
  //
  // 在洞察卡片生成后异步调用。不阻塞 UI，失败静默处理。
  Future<void> extractAndMerge({
    required int thoughtId,
    required InsightCard card,
    required AiService ai,
  }) async {
    try {
      // 取原始想法内容，给 AI 更完整的上下文
      final thought = await _db.getThought(thoughtId);
      final thoughtContent = thought?.content ?? '';
      final emotionTags = thought?.emotionTags ?? [];

      final existingCurrents = await _db.getAllCurrents();

      final existingForPrompt = existingCurrents
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'description': c.description,
              })
          .toList();

      final result = await ai.extractPersonaCurrent(
        thoughtContent: thoughtContent,
        emotionTags: emotionTags,
        card: card,
        existingCurrents: existingForPrompt,
      );

      final now = DateTime.now();

      if (!result.isNew && result.matchedId != null) {
        // 更新已有暗流
        final existing = existingCurrents.firstWhere(
          (c) => c.id == result.matchedId,
          orElse: () => throw Exception('matched id not found'),
        );

        final updatedThoughtIds = [
          ...existing.thoughtIds,
          if (!existing.thoughtIds.contains(thoughtId)) thoughtId,
        ];

        final mergedTheories = {
          ...existing.linkedTheories,
          ...result.linkedTheories,
        }.toList();

        final mergedEmotions = {
          ...existing.linkedEmotions,
          ...result.linkedEmotions,
        }.toList();

        final updated = existing.copyWith(
          strength: updatedThoughtIds.length.clamp(1, 5),
          lastSeenAt: now,
          linkedTheories: mergedTheories,
          linkedEmotions: mergedEmotions,
          thoughtIds: updatedThoughtIds,
        );

        await _db.upsertCurrent(updated);
        debugPrint('[Persona] 更新暗流「${updated.name}」强度→${updated.strength}');
      } else {
        // 创建新暗流
        // 如果 AI 返回的名称为空，用 core_pattern 兜底
        final name = result.newName.isNotEmpty
            ? result.newName
            : card.corePattern.isNotEmpty
                ? card.corePattern
                : '未命名暗流';
        final description = result.newDescription.isNotEmpty
            ? result.newDescription
            : card.interpretation;

        final newId = 'current_${now.millisecondsSinceEpoch}';
        final newCurrent = PersonaCurrent(
          id: newId,
          name: name,
          description: description,
          strength: 1,
          firstSeenAt: now,
          lastSeenAt: now,
          linkedTheories: result.linkedTheories,
          linkedEmotions: result.linkedEmotions,
          thoughtIds: [thoughtId],
        );
        await _db.upsertCurrent(newCurrent);
        debugPrint('[Persona] 发现新暗流「${newCurrent.name}」');
      }
    } catch (e, stack) {
      // 潜流提取是附加功能，失败不影响主流程
      debugPrint('[Persona] 提取失败，已静默: $e\n$stack');
    }
  }

  // ── 构建 persona 注入文本 ────────────────────────────────────────────────
  //
  // 只注入强度≥2 且用户未否定（confirmed != false）的暗流。
  Future<String> buildPersonaPrefix() async {
    try {
      final all = await _db.getAllCurrents();
      final active = all
          .where((c) => c.strength >= 2 && c.confirmed != false)
          .toList();

      if (active.isEmpty) return '';

      return buildPersonaPrefixFromList(active);
    } catch (e) {
      return '';
    }
  }

  static String buildPersonaPrefixFromList(List<PersonaCurrent> currents) {
    if (currents.isEmpty) return '';

    final lines = currents.map((c) {
      final bar = '～' * c.strength.clamp(1, 5);
      return '▸ 【$bar】${c.name}：${c.description}（已在 ${c.thoughtIds.length} 条想法中涌现）';
    }).join('\n');

    return 'Oddly 对你已有一些了解（潜流图谱，仅供参考，不是唯一真相）：\n$lines\n\n基于以上背景，';
  }
}
