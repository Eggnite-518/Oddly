import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../detail/detail_screen.dart';
import 'timeline_provider.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timelineProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          const Positioned.fill(child: ScatteredDots()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                if (state.allTags.isNotEmpty) _buildTagFilter(ref, state),
                Expanded(
                  child: state.isLoading
                      ? _buildLoading()
                      : state.filtered.isEmpty
                          ? _buildEmpty(state.selectedTag != null)
                          : _buildList(context, ref, state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 顶栏 ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HandwrittenText('碎念集',
                  fontSize: 22, color: AppColors.accentDeep),
              const SizedBox(height: 1),
              Text('你所有的奇怪想法都在这里',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 情绪标签筛选栏 ────────────────────────────────────────────────────────

  Widget _buildTagFilter(WidgetRef ref, TimelineState state) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // 「全部」标签
          _TagChip(
            label: '全部',
            selected: state.selectedTag == null,
            onTap: () => ref.read(timelineProvider.notifier).selectTag(null),
          ),
          const SizedBox(width: 8),
          ...state.allTags.map((tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _TagChip(
                  label: tag,
                  selected: state.selectedTag == tag,
                  onTap: () =>
                      ref.read(timelineProvider.notifier).selectTag(tag),
                ),
              )),
        ],
      ),
    );
  }

  // ── 列表 ─────────────────────────────────────────────────────────────────

  Widget _buildList(
      BuildContext context, WidgetRef ref, TimelineState state) {
    // 按日期分组
    final groups = _groupByDate(state.filtered);

    return RefreshIndicator(
      onRefresh: () => ref.read(timelineProvider.notifier).load(),
      color: AppColors.accent,
      backgroundColor: AppColors.cardBg,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final group = groups[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(group.label),
              ...group.thoughts.map(
                (t) => _ThoughtCard(
                  thought: t,
                  onTap: () => _openDetail(context, ref, t.id!),
                  onLongPress: () => _confirmDelete(context, ref, t),
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 10),
      child: Row(
        children: [
          HandwrittenText(label, fontSize: 15, color: AppColors.accentDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1, color: AppColors.divider),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Thought thought) async {
    HapticFeedback.mediumImpact();
    final preview = thought.content.length > 30
        ? '${thought.content.substring(0, 30)}…'
        : thought.content;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: HandwrittenText('删除这条想法？',
            fontSize: 18, color: AppColors.textPrimary),
        content: Text(
          '"$preview"\n\n这条想法和它的洞察、对话都会被永久删除。',
          style: GoogleFonts.nunito(
              fontSize: 14, color: AppColors.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: GoogleFonts.nunito(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除',
                style: GoogleFonts.nunito(
                    color: AppColors.emotionAnxiety,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(timelineProvider.notifier).deleteThought(thought.id!);
    }
  }

  void _openDetail(BuildContext context, WidgetRef ref, int thoughtId) {
    // 从 Detail 返回时刷新 Timeline
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) =>
            DetailScreen(thoughtId: thoughtId),
        transitionsBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) => ref.read(timelineProvider.notifier).load());
  }

  // ── 空状态 ────────────────────────────────────────────────────────────────

  Widget _buildEmpty(bool isFiltered) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HandwrittenText(
            isFiltered ? '这个情绪下还没有想法' : '还没有任何想法',
            fontSize: 20,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered ? '换个标签试试看' : '回到首页，记录你的第一个奇怪想法吧',
            style: GoogleFonts.nunito(
                fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.accent,
      ),
    );
  }

  // ── 日期分组工具 ──────────────────────────────────────────────────────────

  List<_DateGroup> _groupByDate(List<Thought> thoughts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <String, List<Thought>>{};
    final order = <String>[];

    for (final t in thoughts) {
      final d = DateTime(
          t.createdAt.year, t.createdAt.month, t.createdAt.day);
      String label;
      if (d == today) {
        label = '今天';
      } else if (d == yesterday) {
        label = '昨天';
      } else {
        label = DateFormat('M月d日').format(t.createdAt);
      }
      if (!map.containsKey(label)) {
        map[label] = [];
        order.add(label);
      }
      map[label]!.add(t);
    }

    return order.map((l) => _DateGroup(l, map[l]!)).toList();
  }
}

class _DateGroup {
  final String label;
  final List<Thought> thoughts;
  const _DateGroup(this.label, this.thoughts);
}

// ── 想法卡片 ──────────────────────────────────────────────────────────────

class _ThoughtCard extends StatelessWidget {
  final Thought thought;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ThoughtCard({
    required this.thought,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(thought.createdAt);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: AppDecorations.card(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间 + 分析状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                if (thought.isAnalyzed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '已洞察',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '待分析',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
              ],
            ),
            // 情境摘要（时间段 · 天气 · 城市）
            if (thought.weather != null || thought.locationName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 11, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Text(
                    _contextSummary(thought),
                    style: GoogleFonts.nunito(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),

            // 内容摘要（最多3行）
            Text(
              thought.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),

            // 情绪标签
            if (thought.emotionTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: thought.emotionTags
                    .take(4) // 最多显示4个
                    .map((tag) => _buildTag(tag))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _contextSummary(Thought t) {
    final parts = <String>[];
    if (t.weather != null) parts.add(t.weather!);
    if (t.locationName != null) parts.add(t.locationName!);
    return parts.join(' · ');
  }

  Widget _buildTag(String tag) {
    final colors = {
      '焦虑': AppColors.emotionAnxiety,
      '好奇': AppColors.emotionCurious,
      '悲伤': AppColors.emotionSad,
      '渴望': AppColors.emotionAnxiety,
      '孤独': AppColors.emotionSad,
      '兴奋': AppColors.emotionJoy,
      '恐惧': AppColors.emotionSad,
      '压抑': AppColors.emotionSad,
      '期待': AppColors.emotionCurious,
      '愤怒': AppColors.emotionAnxiety,
      '困惑': AppColors.emotionNeutral,
      '迷失': AppColors.emotionNeutral,
    };
    final color = colors[tag] ?? AppColors.emotionNeutral;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: AppDecorations.emotionTag(color),
      child: Text(
        tag,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ── 筛选标签胶囊 ──────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.cardBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
