import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../data/database/app_database.dart';
import '../../core/shell_tab_provider.dart';
import '../../features/actions/action_item_provider.dart';
import '../../features/actions/action_list_screen.dart';
import '../../features/detail/detail_screen.dart';
import '../../services/cognitive_pattern_service.dart';
import 'mirror_provider.dart';

class MirrorScreen extends ConsumerStatefulWidget {
  const MirrorScreen({super.key});

  @override
  ConsumerState<MirrorScreen> createState() => _MirrorScreenState();
}

class _MirrorScreenState extends ConsumerState<MirrorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _patternsScrollController = ScrollController();
  final Map<String, GlobalKey> _patternKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _patternsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mirrorProvider);

    // 监听高频模式跳转请求：切到「思维惯性」子 tab 并滚动定位
    ref.listen<String?>(mirrorHighlightPatternProvider, (_, patternName) {
      if (patternName == null || !mounted) return;
      _tabController.animateTo(1);
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        final key = _patternKeys[patternName];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
        }
        ref.read(mirrorHighlightPatternProvider.notifier).state = null;
      });
    });

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
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCurrentsTab(state),
                      _buildPatternsTab(state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final actionState = ref.watch(actionItemProvider);
    final pendingCount = actionState.pending.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mirror',
                  style: GoogleFonts.caveat(
                    fontSize: 32,
                    color: AppColors.accentDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '水面之下的你',
                  style: GoogleFonts.nunitoSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 行动清单入口
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ActionListScreen()),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.spa_outlined,
                      size: 14, color: AppColors.accentDeep),
                  const SizedBox(width: 5),
                  Text(
                    '想试试的事',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentDeep,
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$pendingCount',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TabBar(
        controller: _tabController,
        labelStyle: GoogleFonts.nunitoSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.nunitoSans(fontSize: 13),
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textHint,
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.divider,
        tabs: const [
          Tab(text: '暗流'),
          Tab(text: '思维惯性'),
        ],
      ),
    );
  }

  Widget _buildCurrentsTab(MirrorState state) {
    return switch (state.phase) {
      MirrorPhase.loading => const Center(
          child: CircularProgressIndicator(color: AppColors.accent)),
      MirrorPhase.empty => _EmptyState(),
      MirrorPhase.observing =>
        _ObservingState(totalThoughts: state.totalThoughts),
      MirrorPhase.ready => _CurrentsList(state: state),
    };
  }

  Widget _buildPatternsTab(MirrorState state) {
    final stats = state.cognitivePatternStats;
    if (stats.isEmpty) {
      return _PatternEmptyState();
    }
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.cardBg,
      onRefresh: () => ref.read(mirrorProvider.notifier).reload(),
      child: ListView(
        controller: _patternsScrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _buildPatternSummary(stats),
          const SizedBox(height: 20),
          ...stats.map((s) {
            final key = _patternKeys.putIfAbsent(s.name, () => GlobalKey());
            return _PatternCard(key: key, stat: s);
          }),
          const SizedBox(height: 16),
          _buildPatternFootnote(),
        ],
      ),
    );
  }

  Widget _buildPatternSummary(List<CognitivePatternStat> stats) {
    final highFreqCount = stats.where((s) => s.isHighFrequency).length;
    return Row(
      children: [
        _StatChip(value: '${stats.length}', label: '种思维惯性被识别'),
        if (highFreqCount > 0) ...[
          const SizedBox(width: 12),
          _StatChip(value: '$highFreqCount', label: '种已成高频模式'),
        ],
      ],
    );
  }

  Widget _buildPatternFootnote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        '思维惯性不是你的"问题"，而是大脑熟悉的路径。识别它，是改变的第一步。',
        style: GoogleFonts.nunitoSans(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }
}

// ── 空态：0 条已分析想法 ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WaterRipple(opacity: 0.25),
            const SizedBox(height: 28),
            Text(
              '水面还很平静',
              style: GoogleFonts.maShanZheng(
                fontSize: 22,
                color: AppColors.accentDeep,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '记录你的第一个奇怪想法，\nOddly 开始悄悄观察水面之下。',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 观察期：有数据但暗流强度不足 ──────────────────────────────────────────────

class _ObservingState extends StatelessWidget {
  final int totalThoughts;
  const _ObservingState({required this.totalThoughts});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WaterRipple(opacity: 0.5),
            const SizedBox(height: 28),
            Text(
              'Oddly 正在观察……',
              style: GoogleFonts.maShanZheng(
                fontSize: 22,
                color: AppColors.accentDeep,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '已积累 $totalThoughts 条想法。\n暗流还在酝酿，再多记几条，\n水面之下的轮廓就会浮现。',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 24),
            // 进度指示
            _ProgressDots(current: totalThoughts, target: 5),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int current;
  final int target;
  const _ProgressDots({required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(target, (i) {
        final filled = i < current;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: filled ? 10 : 8,
            height: filled ? 10 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.accent : AppColors.accentLight,
            ),
          ),
        );
      }),
    );
  }
}

// ── 暗流列表 ─────────────────────────────────────────────────────────────────

class _CurrentsList extends ConsumerWidget {
  final MirrorState state;
  const _CurrentsList({required this.state});

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = state.currents
        .where((c) => c.strength >= 2 && c.confirmed != false)
        .toList();
    final weak = state.currents
        .where((c) => c.strength < 2 || c.confirmed == false)
        .toList();

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.cardBg,
      onRefresh: () => ref.read(mirrorProvider.notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _buildSummaryRow(visible.length, state.totalThoughts),
          const SizedBox(height: 16),
          _buildSectionLabel('涌现中的暗流'),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '还没有强度足够的暗流，继续记录吧。',
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
              ),
            )
          else
            ...visible.map((c) => _CurrentCard(current: c)),
          if (weak.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionLabel('初现的涟漪'),
            const SizedBox(height: 4),
            Text(
              '只出现过 1 次，暂不注入到 AI 分析中',
              style: GoogleFonts.nunitoSans(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 10),
            ...weak.map((c) => _CurrentCard(current: c, isWeak: true)),
          ],
          const SizedBox(height: 16),
          _buildFootnote(),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(int activeCount, int thoughtCount) {
    return Row(
      children: [
        _StatChip(value: '$activeCount', label: '股暗流涌现中'),
        const SizedBox(width: 12),
        _StatChip(value: '$thoughtCount', label: '条想法已分析'),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.caveat(
        fontSize: 18,
        color: AppColors.accentDeep,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildFootnote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        '强度 ≥ 2 的暗流会悄悄注入到你下一次的 AI 分析中，让 Oddly 越来越懂你。',
        style: GoogleFonts.nunitoSans(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.caveat(
              fontSize: 22,
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunitoSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 单张暗流卡片 ──────────────────────────────────────────────────────────────

class _CurrentCard extends ConsumerStatefulWidget {
  final PersonaCurrent current;
  final bool isWeak;
  const _CurrentCard({
    required this.current,
    this.isWeak = false,
  });

  @override
  ConsumerState<_CurrentCard> createState() => _CurrentCardState();
}

class _CurrentCardState extends ConsumerState<_CurrentCard> {
  bool _renaming = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.current.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.current;
    final notifier = ref.read(mirrorProvider.notifier);
    final isWeak = widget.isWeak;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isWeak ? AppColors.cardBg.withAlpha(180) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWeak ? AppColors.cardBorder : AppColors.accentLight,
          width: isWeak ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 卡片头部
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _renaming
                      ? _buildRenameField(notifier, c.id)
                      : GestureDetector(
                          onLongPress: () => setState(() => _renaming = true),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: GoogleFonts.maShanZheng(
                                  fontSize: 17,
                                  color: AppColors.accentDeep,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '长按名称可重命名',
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 10,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                _StrengthBadge(strength: c.strength),
              ],
            ),
          ),
          // ── 描述
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              c.description,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          // ── 理论标签 + 情绪标签
          if (c.linkedTheories.isNotEmpty || c.linkedEmotions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...c.linkedTheories.map((t) => _Tag(
                        label: t,
                        color: AppColors.accent.withAlpha(30),
                        textColor: AppColors.accentDeep,
                      )),
                  ...c.linkedEmotions.take(3).map((e) => _Tag(
                        label: e,
                        color: AppColors.accentLight.withAlpha(50),
                        textColor: AppColors.textSecondary,
                      )),
                ],
              ),
            ),
          // ── 元信息 + 查看关联想法入口
          GestureDetector(
            onTap: c.thoughtIds.isEmpty
                ? null
                : () => _showLinkedThoughts(context, c),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    '首次涌现 ${_formatDate(c.firstSeenAt)} · 在 ${c.thoughtIds.length} 条想法中出现',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                  if (c.thoughtIds.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 13, color: AppColors.textHint),
                  ],
                ],
              ),
            ),
          ),
          // ── 确认区域
          if (c.confirmed == null && !isWeak) ...[
            Divider(color: AppColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '这股暗流说中你了吗？',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ConfirmButton(
                        label: '确认，这是我',
                        isPrimary: true,
                        onTap: () => notifier.confirmCurrent(c.id, true),
                      ),
                      const SizedBox(width: 10),
                      _ConfirmButton(
                        label: '不太像',
                        isPrimary: false,
                        onTap: () => notifier.confirmCurrent(c.id, false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (c.confirmed == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '你已确认这是你',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showLinkedThoughts(BuildContext context, PersonaCurrent current) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(ctx).pop(),
        child: _LinkedThoughtsSheet(
          name: current.name,
          thoughtIds: current.thoughtIds,
        ),
      ),
    );
  }

  Widget _buildRenameField(MirrorNotifier notifier, String id) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            autofocus: true,
            style: GoogleFonts.maShanZheng(
              fontSize: 17,
              color: AppColors.accentDeep,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
            onSubmitted: (v) async {
              if (v.trim().isNotEmpty) {
                await notifier.renameCurrent(id, v.trim());
              }
              setState(() => _renaming = false);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check, size: 18, color: AppColors.accent),
          onPressed: () async {
            final v = _nameController.text.trim();
            if (v.isNotEmpty) {
              await notifier.renameCurrent(id, v);
            }
            setState(() => _renaming = false);
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}月${dt.day}日';
  }
}

// ── 强度徽章 ─────────────────────────────────────────────────────────────────

class _StrengthBadge extends StatelessWidget {
  final int strength;
  const _StrengthBadge({required this.strength});

  static const labels = ['细流', '浅流', '中流', '强流', '深流'];

  @override
  Widget build(BuildContext context) {
    final clamped = strength.clamp(1, 5);
    final label = labels[clamped - 1];
    final opacity = 0.3 + (clamped - 1) * 0.175;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => Container(
              margin: const EdgeInsets.only(right: 2),
              width: 4,
              height: 4 + i * 2.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i < clamped
                    ? AppColors.accent.withAlpha((opacity * 255).round())
                    : AppColors.accentLight.withAlpha(60),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── 标签 ─────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Tag({required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunitoSans(
          fontSize: 11,
          color: textColor,
        ),
      ),
    );
  }
}

// ── 确认按钮 ─────────────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;
  const _ConfirmButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? AppColors.accent : AppColors.accentLight,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunitoSans(
            fontSize: 12,
            color: isPrimary ? Colors.white : AppColors.textSecondary,
            fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── 思维惯性空态 ──────────────────────────────────────────────────────────────

class _PatternEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_outlined,
                size: 48, color: AppColors.accentLight),
            const SizedBox(height: 24),
            Text(
              '还没有思维惯性被识别',
              style: GoogleFonts.maShanZheng(
                fontSize: 20,
                color: AppColors.accentDeep,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '记录更多想法并生成洞察后，\nOddly 会悄悄帮你发现思维中的惯性路径。',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 思维惯性卡片 ──────────────────────────────────────────────────────────────

class _PatternCard extends StatelessWidget {
  final CognitivePatternStat stat;
  const _PatternCard({super.key, required this.stat});

  void _showLinkedThoughts(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(ctx).pop(),
        child: _LinkedThoughtsSheet(
          name: stat.name,
          thoughtIds: stat.thoughtIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHighFreq = stat.isHighFrequency;
    final desc = kCognitivePatternDescriptions[stat.name] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighFreq ? AppColors.accentDeep.withAlpha(60) : AppColors.cardBorder,
          width: isHighFreq ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isHighFreq) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accentDeep,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            stat.name,
                            style: GoogleFonts.maShanZheng(
                              fontSize: 17,
                              color: isHighFreq
                                  ? AppColors.accentDeep
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (isHighFreq)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '高频模式',
                            style: GoogleFonts.nunitoSans(
                              fontSize: 10,
                              color: AppColors.accentDeep,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighFreq
                        ? AppColors.accentDeep.withAlpha(20)
                        : AppColors.accentLight.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '× ${stat.thoughtIds.length}',
                    style: GoogleFonts.caveat(
                      fontSize: 16,
                      color: isHighFreq
                          ? AppColors.accentDeep
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(
                desc,
                style: GoogleFonts.nunitoSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          GestureDetector(
            onTap: stat.thoughtIds.isEmpty
                ? null
                : () => _showLinkedThoughts(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Text(
                    '首次出现 ${_fmt(stat.firstSeenAt)} · 在 ${stat.thoughtIds.length} 条想法中',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                  if (stat.thoughtIds.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        size: 13, color: AppColors.textHint),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.month}月${dt.day}日';
}

// ── 关联想法底部弹出 ──────────────────────────────────────────────────────────

class _LinkedThoughtsSheet extends StatefulWidget {
  final String name;
  final List<int> thoughtIds;
  const _LinkedThoughtsSheet({required this.name, required this.thoughtIds});

  @override
  State<_LinkedThoughtsSheet> createState() => _LinkedThoughtsSheetState();
}

class _LinkedThoughtsSheetState extends State<_LinkedThoughtsSheet> {
  List<Thought>? _thoughts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final thoughts =
        await AppDatabase.instance.getThoughtsByIds(widget.thoughtIds);
    if (mounted) setState(() => _thoughts = thoughts);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => GestureDetector(
        onTap: () {},
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.pageBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  widget.name,
                  style: GoogleFonts.maShanZheng(
                    fontSize: 20,
                    color: AppColors.accentDeep,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  '${widget.thoughtIds.length} 条相关想法',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 12, color: AppColors.textHint),
                ),
              ),
              Divider(color: AppColors.divider, height: 1),
              Expanded(
                child: _thoughts == null
                    ? const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accent))
                    : _thoughts!.isEmpty
                        ? Center(
                            child: Text(
                              '找不到相关想法',
                              style: GoogleFonts.nunitoSans(
                                  fontSize: 14, color: AppColors.textHint),
                            ),
                          )
                        : ListView.separated(
                            controller: controller,
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 40),
                            itemCount: _thoughts!.length,
                            separatorBuilder: (context, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) =>
                                _LinkedThoughtTile(thought: _thoughts![i]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedThoughtTile extends StatelessWidget {
  final Thought thought;
  const _LinkedThoughtTile({required this.thought});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('M月d日 HH:mm');
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // 关闭底部弹出
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondary) =>
                DetailScreen(thoughtId: thought.id!),
            transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Container(
        decoration: AppDecorations.card(),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  fmt.format(thought.createdAt),
                  style: GoogleFonts.nunitoSans(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
                const Spacer(),
                if (thought.isAnalyzed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '已洞察',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 10,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              thought.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
            if (thought.emotionTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: thought.emotionTags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 水波涟漪装饰 ──────────────────────────────────────────────────────────────

class _WaterRipple extends StatelessWidget {
  final double opacity;
  const _WaterRipple({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _RipplePainter(opacity: opacity)),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double opacity;
  const _RipplePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.accentLight.withAlpha((opacity * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, i * 14.0, paint);
    }

    // 中心点
    canvas.drawCircle(
      center,
      5,
      Paint()..color = AppColors.accent.withAlpha((opacity * 200).round()),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.opacity != opacity;
}
