import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

// ── State ───────────────────────────────────────────────────────────────────

class ActionItemState {
  final List<ActionItem> all;
  final ActionItem? featured;
  final bool isLoading;
  // 首页临时跳过的 id（只在内存里，不写 DB，重启后自动恢复）
  final Set<int> homeDismissedIds;

  ActionItemState({
    this.all = const [],
    this.featured,
    this.isLoading = true,
    Set<int>? homeDismissedIds,
  }) : homeDismissedIds = homeDismissedIds ?? {};

  List<ActionItem> get pending =>
      all.where((a) => a.status == ActionStatus.pending).toList();

  List<ActionItem> get completed =>
      all.where((a) => a.status == ActionStatus.completed).toList();

  ActionItemState copyWith({
    List<ActionItem>? all,
    ActionItem? featured,
    bool clearFeatured = false,
    bool? isLoading,
    Set<int>? homeDismissedIds,
  }) =>
      ActionItemState(
        all: all ?? this.all,
        featured: clearFeatured ? null : (featured ?? this.featured),
        isLoading: isLoading ?? this.isLoading,
        homeDismissedIds:
            homeDismissedIds ?? Set<int>.from(this.homeDismissedIds),
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ActionItemNotifier extends StateNotifier<ActionItemState> {
  final AppDatabase _db = AppDatabase.instance;

  ActionItemNotifier() : super(ActionItemState()) {
    load();
  }

  Future<void> load() async {
    final dismissed = state.homeDismissedIds;
    try {
      final all = await _db.getAllActionItems();
      final pendingVisible = all
          .where((a) =>
              a.status == ActionStatus.pending && !dismissed.contains(a.id))
          .toList()
        ..sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return a.createdAt.compareTo(b.createdAt);
        });
      state = ActionItemState(
        all: all,
        featured: pendingVisible.isEmpty ? null : pendingVisible.first,
        isLoading: false,
        homeDismissedIds: dismissed,
      );
    } catch (e, stack) {
      debugPrint('[ActionItem] 加载失败: $e\n$stack');
      state = ActionItemState(
        isLoading: false,
        homeDismissedIds: dismissed,
      );
    }
  }

  /// 收藏一条行动建议
  Future<void> save({
    required String content,
    required int insightCardId,
    required int thoughtId,
  }) async {
    try {
      await _db.insertActionItem(ActionItem(
        content: content,
        insightCardId: insightCardId,
        thoughtId: thoughtId,
        createdAt: DateTime.now(),
      ));
      await load();
    } catch (e, stack) {
      debugPrint('[ActionItem] 保存失败: $e\n$stack');
    }
  }

  /// 取消收藏（再次点书签）
  Future<void> remove(int id) async {
    await _db.deleteActionItem(id);
    await load();
  }

  /// 标记完成
  Future<void> complete(int id) async {
    await _db.updateActionStatus(id, ActionStatus.completed);
    final dismissed = Set<int>.from(state.homeDismissedIds)..remove(id);
    state = state.copyWith(homeDismissedIds: dismissed);
    await load();
  }

  /// 首页临时跳过：只换下一条，不改变 DB 状态
  void dismissOnHome(int id) {
    final dismissed = Set<int>.from(state.homeDismissedIds)..add(id);
    final pendingVisible = state.all
        .where((a) =>
            a.status == ActionStatus.pending && !dismissed.contains(a.id))
        .toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    state = state.copyWith(
      homeDismissedIds: dismissed,
      featured: pendingVisible.isEmpty ? null : pendingVisible.first,
      clearFeatured: pendingVisible.isEmpty,
    );
  }

  /// 置顶（单选）
  Future<void> togglePin(int id, bool isPinned) async {
    await _db.updateActionPinned(id, isPinned);
    await load();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final actionItemProvider =
    StateNotifierProvider<ActionItemNotifier, ActionItemState>(
  (ref) => ActionItemNotifier(),
);
