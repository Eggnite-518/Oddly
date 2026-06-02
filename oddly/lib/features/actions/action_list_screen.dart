import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../detail/detail_screen.dart';
import 'action_item_provider.dart';

class ActionListScreen extends ConsumerWidget {
  const ActionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(actionItemProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          Positioned.fill(child: ScatteredDots()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                Expanded(
                  child: state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent))
                      : _buildList(context, ref, state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.accentDeep),
          ),
          const SizedBox(width: 12),
          Text(
            '想试试的事',
            style: GoogleFonts.caveat(
              fontSize: 28,
              color: AppColors.accentDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, ActionItemState state) {
    final pending = state.pending;
    final completed = state.completed;

    if (pending.isEmpty && completed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.spa_outlined, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(
                '还没有收藏任何行动建议',
                style: GoogleFonts.nunito(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '打开一条洞察卡片，点击建议旁的书签收藏它',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 13, color: AppColors.textHint, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        if (pending.isNotEmpty) ...[
          _SectionHeader(label: '待完成', count: pending.length),
          ...pending.map((item) => _ActionTile(
                item: item,
                onComplete: () =>
                    ref.read(actionItemProvider.notifier).complete(item.id!),
                onTogglePin: () => ref
                    .read(actionItemProvider.notifier)
                    .togglePin(item.id!, !item.isPinned),
                onDelete: () =>
                    ref.read(actionItemProvider.notifier).remove(item.id!),
                onTap: () => _openDetail(context, item.thoughtId),
              )),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionHeader(label: '已完成', count: completed.length),
          ...completed.map((item) => _ActionTile(
                item: item,
                onDelete: () =>
                    ref.read(actionItemProvider.notifier).remove(item.id!),
                onTap: () => _openDetail(context, item.thoughtId),
              )),
        ],
      ],
    );
  }

  void _openDetail(BuildContext context, int thoughtId) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DetailScreen(thoughtId: thoughtId),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.nunito(
                  fontSize: 11, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Tile ───────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final ActionItem item;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onTogglePin;
  final VoidCallback? onDelete;

  const _ActionTile({
    required this.item,
    required this.onTap,
    this.onComplete,
    this.onTogglePin,
    this.onDelete,
  });

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '删除这条行动？',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Center(
                        child: Text(
                          '取消',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onDelete?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.shade200),
                      ),
                      child: Center(
                        child: Text(
                          '删除',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == ActionStatus.completed;
    final isDone = isCompleted;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete != null ? () => _confirmDelete(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.pageBg
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isPinned
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.cardBorder,
            width: item.isPinned ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 置顶 icon（仅待完成显示）
            if (!isDone && onTogglePin != null)
              GestureDetector(
                onTap: onTogglePin,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Icon(
                    item.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 15,
                    color: item.isPinned
                        ? AppColors.accent
                        : AppColors.textHint,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.content,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      height: 1.5,
                      color: isDone
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.link_rounded,
                          size: 11, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(
                        '来自一条想法',
                        style: GoogleFonts.nunito(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                      if (isCompleted && item.completedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· 已完成',
                          style: GoogleFonts.nunito(
                              fontSize: 11, color: AppColors.accent),
                        ),
                      ],
                      if (item.isPinned && !isDone) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· 已置顶',
                          style: GoogleFonts.nunito(
                              fontSize: 11, color: AppColors.accent),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 完成按钮（仅待完成）
            if (!isDone && onComplete != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onComplete,
                child: Icon(Icons.check_circle_outline_rounded,
                    size: 22, color: AppColors.accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
