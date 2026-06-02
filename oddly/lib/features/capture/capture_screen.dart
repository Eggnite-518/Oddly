import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../services/ali_asr_service.dart';
import '../../services/context_service.dart';
import '../actions/action_item_provider.dart';
import '../actions/action_list_screen.dart';
import '../detail/detail_screen.dart';
import '../timeline/timeline_provider.dart';
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
  final AudioRecorder _recorder = AudioRecorder();
  bool _hasContent = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
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

  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _submitAnimController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── 语音录入 ───────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能使用语音输入')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    setState(() => _isRecording = true);
    HapticFeedback.lightImpact();
  }

  Future<void> _stopRecordingAndTranscribe() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });
    HapticFeedback.lightImpact();

    if (path == null) {
      setState(() => _isTranscribing = false);
      return;
    }

    final text = await AliASRService.instance.transcribe(path);
    if (!mounted) return;
    setState(() => _isTranscribing = false);

    if (text != null && text.isNotEmpty) {
      final current = _controller.text;
      final needSpace = current.isNotEmpty && !current.endsWith('\n');
      _controller.text = current + (needSpace ? '\n' : '') + text;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未能识别语音，请重试')),
      );
    }
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
    // 刷新首页统计 + 时间线
    ref.read(homeStatsProvider.notifier).load();
    ref.read(timelineProvider.notifier).load();

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
      if (mounted) {
        ref.read(homeStatsProvider.notifier).load();
        ref.read(timelineProvider.notifier).load();
      }
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                _buildStatsCard(),
                _buildActionCard(),
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

  Widget _buildActionCard() {
    final actionState = ref.watch(actionItemProvider);
    final featured = actionState.featured;
    if (featured == null) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _ActionCardWidget(
        key: ValueKey(featured.id),
        item: featured,
        onComplete: () =>
            ref.read(actionItemProvider.notifier).complete(featured.id!),
        onSkip: () =>
            ref.read(actionItemProvider.notifier).skip(featured.id!),
        onTapContent: () => Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                DetailScreen(thoughtId: featured.thoughtId),
            transitionsBuilder: (_, animation, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        onTapList: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ActionListScreen()),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Oddly',
            style: GoogleFonts.caveat(
              fontSize: 32,
              color: AppColors.accentDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '随时记下此刻的想法',
            style: GoogleFonts.nunitoSans(
              fontSize: 13,
              color: AppColors.textSecondary,
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
                  '此刻在想什么？',
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
          // 语音输入按钮：按住录音，松手识别
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecordingAndTranscribe(),
            onLongPressCancel: () async {
              await _recorder.stop();
              setState(() { _isRecording = false; _isTranscribing = false; });
            },
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
              child: _isTranscribing
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    )
                  : Icon(
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

// ── 首页行动卡片 ──────────────────────────────────────────────────────────────

class _ActionCardWidget extends StatelessWidget {
  final ActionItem item;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onTapContent;
  final VoidCallback onTapList;

  const _ActionCardWidget({
    super.key,
    required this.item,
    required this.onComplete,
    required this.onSkip,
    required this.onTapContent,
    required this.onTapList,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧点
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          // 文字（点击 → 来源洞察卡片）
          Expanded(
            child: GestureDetector(
              onTap: onTapContent,
              child: Text(
                item.content,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // 清单入口
          GestureDetector(
            onTap: onTapList,
            child: Icon(Icons.format_list_bulleted_rounded,
                size: 16, color: AppColors.textHint),
          ),
          const SizedBox(width: 8),
          // 跳过
          GestureDetector(
            onTap: onSkip,
            child: Icon(Icons.close_rounded,
                size: 18, color: AppColors.textHint),
          ),
          const SizedBox(width: 8),
          // 完成
          GestureDetector(
            onTap: onComplete,
            child: Icon(Icons.check_circle_outline_rounded,
                size: 20, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
