import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../data/database/app_database.dart';
import 'mirror_provider.dart';

class MirrorScreen extends ConsumerWidget {
  const MirrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mirrorProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          const Positioned.fill(child: ScatteredDots()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context, state),
                Expanded(
                  child: _buildBody(context, ref, state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, MirrorState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
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
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, MirrorState state) {
    switch (state.phase) {
      case MirrorPhase.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        );
      case MirrorPhase.empty:
        return _EmptyState();
      case MirrorPhase.observing:
        return _ObservingState(totalThoughts: state.totalThoughts);
      case MirrorPhase.ready:
        return _CurrentsList(state: state);
    }
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
          // ── 元信息
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '首次涌现 ${_formatDate(c.firstSeenAt)} · 在 ${c.thoughtIds.length} 条想法中出现',
              style: GoogleFonts.nunitoSans(
                fontSize: 11,
                color: AppColors.textHint,
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
