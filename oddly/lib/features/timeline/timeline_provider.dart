import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

class TimelineState {
  final List<Thought> thoughts;
  final bool isLoading;
  final String? selectedTag; // null = 全部

  const TimelineState({
    this.thoughts = const [],
    this.isLoading = true,
    this.selectedTag,
  });

  TimelineState copyWith({
    List<Thought>? thoughts,
    bool? isLoading,
    String? selectedTag,
    bool clearTag = false,
  }) =>
      TimelineState(
        thoughts: thoughts ?? this.thoughts,
        isLoading: isLoading ?? this.isLoading,
        selectedTag: clearTag ? null : (selectedTag ?? this.selectedTag),
      );

  // 当前筛选后的想法列表
  List<Thought> get filtered {
    if (selectedTag == null) return thoughts;
    return thoughts
        .where((t) => t.emotionTags.contains(selectedTag))
        .toList();
  }

  // 所有出现过的情绪标签（去重）
  List<String> get allTags {
    final tags = <String>{};
    for (final t in thoughts) {
      tags.addAll(t.emotionTags);
    }
    return tags.toList()..sort();
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  TimelineNotifier() : super(const TimelineState()) {
    load();
  }

  Future<void> load() async {
    try {
      state = state.copyWith(isLoading: true);
      final thoughts = await AppDatabase.instance.getAllThoughts();
      state = state.copyWith(thoughts: thoughts, isLoading: false);
    } catch (e, stack) {
      debugPrint('[Timeline] 加载失败: $e\n$stack');
      state = state.copyWith(isLoading: false);
    }
  }

  void selectTag(String? tag) {
    if (tag == state.selectedTag) {
      state = state.copyWith(clearTag: true);
    } else {
      state = state.copyWith(selectedTag: tag);
    }
  }

  Future<void> deleteThought(int id) async {
    // 乐观更新：先从内存里移除，再删 DB；失败则重新加载兜底
    final removed = state.thoughts.where((t) => t.id != id).toList();
    state = state.copyWith(thoughts: removed);
    try {
      await AppDatabase.instance.deleteThought(id);
    } catch (e, stack) {
      debugPrint('[Timeline] 删除失败: $e\n$stack');
      await load();
    }
  }
}

final timelineProvider =
    StateNotifierProvider<TimelineNotifier, TimelineState>(
  (_) => TimelineNotifier(),
);
