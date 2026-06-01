import 'package:flutter/foundation.dart';
import '../data/database/app_database.dart';

/// 思维惯性的预设描述，用于 Mirror 页展示
const Map<String, String> kCognitivePatternDescriptions = {
  '灾难化联想': '倾向于把事情往最坏的方向推演，即使概率很低，也会在脑中放大它的破坏力。',
  '非此即彼': '用极端的非黑即白方式看待事物——要么完全成功，要么彻底失败，很难接受中间地带。',
  '读心术': '在没有证据的情况下，习惯于猜测别人在想什么，并把这种猜测当作事实。',
  '把一切揽到自己身上': '把发生在周围的负面事件过度归因于自己，即使并没有直接关系。',
  '用感受下判断': '因为内心强烈地"感觉"某事是真的，就认为它一定是真的，让情绪主导了对现实的判断。',
  '以偏概全': '用一次负面经历推断所有类似情境都会如此，用"总是""从来""永远"来描述世界。',
  '过滤负面信息': '自动放大负面细节，同时过滤掉积极的信息，让整体画面比实际更暗。',
  '应该句式': '用严苛的"应该""必须""不得不"要求自己或他人，产生内疚或愤怒。',
};

class CognitivePatternService {
  CognitivePatternService._();
  static final CognitivePatternService instance = CognitivePatternService._();

  final AppDatabase _db = AppDatabase.instance;

  /// 在后台聚合一条想法产生的思维惯性，不阻塞 UI
  Future<void> aggregate({
    required int thoughtId,
    required List<String> patterns,
  }) async {
    if (patterns.isEmpty) return;
    try {
      for (final pattern in patterns) {
        await _db.upsertCognitivePatternStat(pattern, thoughtId);
      }
    } catch (e) {
      debugPrint('[CognitivePattern] 聚合失败: $e');
    }
  }

  /// 检查给定 patterns 中哪些已达到高频门槛（count >= 3）
  Future<List<String>> getHighFrequencyPatterns(
      List<String> patterns) async {
    final result = <String>[];
    for (final p in patterns) {
      final stat = await _db.getCognitivePatternStat(p);
      if (stat != null && stat.isHighFrequency) result.add(p);
    }
    return result;
  }
}
