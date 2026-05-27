import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

class HomeStats {
  final int totalCount;
  final int weekCount;
  final int streakDays;
  final String? topEmotion;
  final DateTime? lastRecordAt;

  const HomeStats({
    this.totalCount = 0,
    this.weekCount = 0,
    this.streakDays = 0,
    this.topEmotion,
    this.lastRecordAt,
  });
}

class HomeStatsNotifier extends StateNotifier<AsyncValue<HomeStats>> {
  HomeStatsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final thoughts = await AppDatabase.instance.getAllThoughts();
      final stats = _compute(thoughts);

      state = AsyncValue.data(HomeStats(
        totalCount: stats['total'] as int,
        weekCount: stats['week'] as int,
        streakDays: stats['streak'] as int,
        topEmotion: stats['topEmotion'] as String?,
        lastRecordAt: stats['lastRecordAt'] as DateTime?,
      ));
    } catch (e, st) {
      debugPrint('[HomeStats] 加载失败: $e\n$st');
      state = AsyncValue.error(e, st);
    }
  }

  Map<String, dynamic> _compute(List<Thought> thoughts) {
    if (thoughts.isEmpty) {
      return {
        'total': 0,
        'week': 0,
        'streak': 0,
        'topEmotion': null,
        'lastRecordAt': null,
      };
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1)); // 本周一

    int weekCount = 0;
    final tagCount = <String, int>{};

    for (final t in thoughts) {
      if (!t.createdAt.isBefore(weekStart)) weekCount++;
      for (final tag in t.emotionTags) {
        tagCount[tag] = (tagCount[tag] ?? 0) + 1;
      }
    }

    // 连续天数：从今天往前，每天只要有一条就算
    final daysWithThoughts = thoughts
        .map((t) => DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day))
        .toSet();

    int streak = 0;
    var checking = today;
    while (daysWithThoughts.contains(checking)) {
      streak++;
      checking = checking.subtract(const Duration(days: 1));
    }
    // 如果今天没有记录但昨天有，连续天数从昨天起算
    if (streak == 0) {
      checking = today.subtract(const Duration(days: 1));
      while (daysWithThoughts.contains(checking)) {
        streak++;
        checking = checking.subtract(const Duration(days: 1));
      }
    }

    // 最高频情绪
    String? topEmotion;
    if (tagCount.isNotEmpty) {
      topEmotion = tagCount.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    return {
      'total': thoughts.length,
      'week': weekCount,
      'streak': streak,
      'topEmotion': topEmotion,
      'lastRecordAt': thoughts.first.createdAt, // 已按 created_at DESC 排序
    };
  }
}

final homeStatsProvider =
    StateNotifierProvider<HomeStatsNotifier, AsyncValue<HomeStats>>(
  (_) => HomeStatsNotifier(),
);
