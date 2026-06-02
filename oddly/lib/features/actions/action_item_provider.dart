import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';

// ── State ───────────────────────────────────────────────────────────────────

class ActionItemState {
  final List<ActionItem> all;
  final ActionItem? featured;
  final bool isLoading;

  const ActionItemState({
    this.all = const [],
    this.featured,
    this.isLoading = true,
  });

  List<ActionItem> get pending =>
      all.where((a) => a.status == ActionStatus.pending).toList();

  List<ActionItem> get completed =>
      all.where((a) => a.status == ActionStatus.completed).toList();

  List<ActionItem> get skipped =>
      all.where((a) => a.status == ActionStatus.skipped).toList();

  ActionItemState copyWith({
    List<ActionItem>? all,
    ActionItem? featured,
    bool clearFeatured = false,
    bool? isLoading,
  }) =>
      ActionItemState(
        all: all ?? this.all,
        featured: clearFeatured ? null : (featured ?? this.featured),
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class ActionItemNotifier extends StateNotifier<ActionItemState> {
  final AppDatabase _db = AppDatabase.instance;

  ActionItemNotifier() : super(const ActionItemState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final all = await _db.getAllActionItems();
      final featured = await _db.getFeaturedActionItem();
      state = ActionItemState(all: all, featured: featured, isLoading: false);
    } catch (e) {
      debugPrint('[ActionItem] 加载失败（不影响主流程）: $e');
      state = ActionItemState(isLoading: false);
    }
  }

  /// 收藏一条行动建议（从洞察卡片点书签调用）
  Future<void> save({
    required String content,
    required int insightCardId,
    required int thoughtId,
  }) async {
    await _db.insertActionItem(ActionItem(
      content: content,
      insightCardId: insightCardId,
      thoughtId: thoughtId,
      createdAt: DateTime.now(),
    ));
    await load();
  }

  /// 取消收藏（再次点书签）
  Future<void> remove(int id) async {
    await _db.deleteActionItem(id);
    await load();
  }

  /// 标记完成
  Future<void> complete(int id) async {
    await _db.updateActionStatus(id, ActionStatus.completed);
    await load();
  }

  /// 跳过（移至列表底部，保留在 skipped 区域）
  Future<void> skip(int id) async {
    await _db.updateActionStatus(id, ActionStatus.skipped);
    await load();
  }

  /// 置顶（单选，同时会取消其他置顶）
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
