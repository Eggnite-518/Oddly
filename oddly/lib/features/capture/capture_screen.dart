import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../services/context_service.dart';
import '../detail/detail_screen.dart';
import '../timeline/timeline_screen.dart';
import 'home_stats_provider.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasContent = false;
  bool _isRecording = false;
  late AnimationController _submitAnimController;
  late Animation<double> _submitScaleAnim;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasContent = _controller.text.trim().isNotEmpty;
      if (hasContent != _hasContent) {
        setState(() => _hasContent = hasContent);
      }
    });

    _submitAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _submitScaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _submitAnimController, curve: Curves.easeInOut),
    );

    // 自动弹出键盘
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _submitAnimController.dispose();
    super.dispose();
  }

  void _onSubmit() async {
    if (!_hasContent) return;
    HapticFeedback.lightImpact();

    await _submitAnimController.forward();
    await _submitAnimController.reverse();

    final content = _controller.text.trim();
    _controller.clear();

    // 后台抓取情境（与页面跳转并行，不阻塞）
    final contextFuture = ContextService.instance.capture();

    // 先用最基础信息存库，拿到 id 立刻跳转
    final thoughtId = await AppDatabase.instance.insertThought(
      Thought(content: content, createdAt: DateTime.now()),
    );

    // 情境抓取完成后静默更新数据库
    contextFuture.then((ctx) async {
      await AppDatabase.instance.updateThoughtContext(
        thoughtId,
        latitude: ctx.latitude,
        longitude: ctx.longitude,
        locationName: ctx.city,
        weather: ctx.weather != null
            ? '${ctx.timePeriod} · ${ctx.weather}'
            : ctx.timePeriod,
        temperature: ctx.temperature,
      );
      debugPrint('[Capture] ✅ thought#$thoughtId 情境已写入 DB: ${ctx.summary}');
    }).catchError((e) {
      debugPrint('[Capture] ❌ 情境写入失败: $e');
    });

    if (!mounted) return;
    // 刷新首页统计
    ref.read(homeStatsProvider.notifier).load();

    // 跳转到详情页，触发 AI 追问流程
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => DetailScreen(thoughtId: thoughtId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      if (mounted) ref.read(homeStatsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          // 背景装饰小点
          const Positioned.fill(child: ScatteredDots()),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildStatsCard(),
                Expanded(child: _buildInputArea()),
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final statsAsync = ref.watch(homeStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.totalCount == 0) return const SizedBox.shrink();
        return Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: AppDecorations.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 数字统计行
                Row(
                  children: [
                    _statBadge('本周', '${stats.weekCount} 条'),
                    _statDivider(),
                    _statBadge('总计', '${stats.totalCount} 条'),
                    _statDivider(),
                    _statBadge('连续', '${stats.streakDays} 天'),
                    if (stats.topEmotion != null) ...[
                      _statDivider(),
                      _statBadge('最近情绪', stats.topEmotion!),
                    ],
                    const Spacer(),
                    if (stats.lastRecordAt != null)
                      Text(
                        _formatLastTime(stats.lastRecordAt!),
                        style: GoogleFonts.nunito(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                  ],
                ),
              ],
            ),
          );
      },
    );
  }

  Widget _statBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.accentDeep,
            )),
        Text(label,
            style: GoogleFonts.nunito(
                fontSize: 10, color: AppColors.textHint)),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 1,
      height: 24,
      color: AppColors.divider,
    );
  }

  String _formatLastTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return DateFormat('M月d日').format(dt);
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo / 品牌名
          Row(
            children: [
              HandwrittenText(
                'Oddly',
                fontSize: 26,
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
          // 进入 Timeline 按钮
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, _) =>
                      const TimelineScreen(),
                  transitionsBuilder: (context, animation, _, child) =>
                      SlideTransition(
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timeline_rounded,
                      size: 16, color: AppColors.accentDeep),
                  const SizedBox(width: 6),
                  Text(
                    '回溯',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提示语（手写风）
            AnimatedOpacity(
              opacity: _hasContent ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: HandwrittenText(
                '有什么奇怪的想法？',
                fontSize: 20,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 8),
            // 输入框
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: GoogleFonts.nunito(
                  fontSize: 19,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                  height: 1.7,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 语音输入按钮
          GestureDetector(
            onTapDown: (_) => setState(() => _isRecording = true),
            onTapUp: (_) => setState(() => _isRecording = false),
            onTapCancel: () => setState(() => _isRecording = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _isRecording
                      ? AppColors.accent
                      : AppColors.cardBorder,
                  width: 1.5,
                ),
              ),
              child: Icon(
                _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isRecording ? AppColors.accent : AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),

          // 字数统计
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) => Text(
              value.text.isEmpty ? '' : '${value.text.length} 字',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          ),

          // 提交按钮
          ScaleTransition(
            scale: _submitScaleAnim,
            child: GestureDetector(
              onTap: _hasContent ? _onSubmit : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _hasContent ? AppColors.accent : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: _hasContent
                        ? AppColors.accent
                        : AppColors.cardBorder,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: _hasContent ? Colors.white : AppColors.textHint,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
