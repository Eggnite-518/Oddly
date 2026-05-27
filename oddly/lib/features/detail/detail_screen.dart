import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import 'thought_detail_provider.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final int thoughtId;
  const DetailScreen({super.key, required this.thoughtId});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen>
    with TickerProviderStateMixin {
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocus = FocusNode();
  bool _editingTags = false;
  late AnimationController _insightAnimController;
  late Animation<double> _insightFadeAnim;
  late Animation<Offset> _insightSlideAnim;

  @override
  void initState() {
    super.initState();
    _insightAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _insightFadeAnim = CurvedAnimation(
      parent: _insightAnimController,
      curve: Curves.easeOut,
    );
    _insightSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _insightAnimController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocus.dispose();
    _insightAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(thoughtDetailProvider(widget.thoughtId));

    // 当切换到展示洞察时触发入场动画
    ref.listen(thoughtDetailProvider(widget.thoughtId), (prev, next) {
      if (prev?.phase != DetailPhase.showingInsight &&
          next.phase == DetailPhase.showingInsight) {
        _insightAnimController.forward(from: 0);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Stack(
        children: [
          const Positioned.fill(child: ScatteredDots()),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: _buildBody(state),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          HandwrittenText('这个想法', fontSize: 20, color: AppColors.accentDeep),
          const Spacer(),
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: HandwrittenText('删除这条想法？',
            fontSize: 18, color: AppColors.textPrimary),
        content: Text(
          '这条想法和它的洞察、对话都会被永久删除。',
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

    if (ok == true && context.mounted) {
      await AppDatabase.instance.deleteThought(widget.thoughtId);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _buildBody(DetailState state) {
    return switch (state.phase) {
      DetailPhase.loading => _buildLoading('正在连接意识流…'),
      DetailPhase.error => _buildError(state.errorMessage ?? '出错了'),
      _ => _buildContent(state),
    };
  }

  Widget _buildContent(DetailState state) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // 原始想法卡片
        if (state.thought != null) _buildThoughtCard(state.thought!),

        // 情绪标签（有标签时才显示）
        if (state.thought != null && state.thought!.emotionTags.isNotEmpty)
          _buildEmotionTagsSection(state.thought!.emotionTags),

        const SizedBox(height: 20),

        // 对话历史 — 只显示已回答或已跳过的轮次，排除当前等待回答的问题
        () {
          final doneConvs = state.conversations
              .where((c) => c.answer != null || c.wasSkipped)
              .toList();
          if (doneConvs.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              ...doneConvs.map(_buildConversationBubble),
              const SizedBox(height: 8),
            ],
          );
        }(),

        // 当前状态区域
        switch (state.phase) {
          DetailPhase.askingQuestion =>
            _buildQuestionArea(state.currentQuestion ?? ''),
          DetailPhase.submittingAnswer =>
            _buildLoading('正在思考下一个问题…'),
          DetailPhase.generatingInsight =>
            _buildLoading('正在生成你的专属洞察…'),
          DetailPhase.showingInsight when state.insightCard != null =>
            _buildInsightCard(state.insightCard!, state.thought?.emotionTags ?? [], state.thought),
          DetailPhase.error =>
            _buildError(state.errorMessage ?? '出错了'),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  // ── 原始想法卡片 ──────────────────────────────────────────────────────────

  Widget _buildThoughtCard(Thought thought) {
    final formatter = DateFormat('MM月dd日 HH:mm');
    return Container(
      decoration: AppDecorations.card(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                formatter.format(thought.createdAt),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (thought.weather != null || thought.locationName != null) ...[
                const SizedBox(width: 10),
                Container(width: 1, height: 10, color: AppColors.divider),
                const SizedBox(width: 10),
                Icon(Icons.location_on_outlined,
                    size: 11, color: AppColors.textHint),
                const SizedBox(width: 3),
                Text(
                  [
                    if (thought.weather != null) thought.weather!,
                    if (thought.locationName != null) thought.locationName!,
                  ].join(' · '),
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            thought.content,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  // ── 对话气泡 ──────────────────────────────────────────────────────────────

  Widget _buildConversationBubble(AiConversation conv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI 问题
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: HandwrittenText('O',
                    fontSize: 14, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(14),
                decoration: AppDecorations.card(bg: AppColors.cardBg),
                child: Text(
                  conv.question,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 用户回答 / 跳过标注
        if (conv.answer != null || conv.wasSkipped)
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: conv.wasSkipped
                ? Text(
                    '（跳过了这个问题）',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          width: 1),
                    ),
                    child: Text(
                      conv.answer!,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── AI 追问输入区 ─────────────────────────────────────────────────────────

  Widget _buildQuestionArea(String question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI 当前问题
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: HandwrittenText('O',
                    fontSize: 14, color: AppColors.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(14),
                decoration: AppDecorations.card(bg: AppColors.cardBg),
                child: Text(
                  question,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 回答输入框
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _answerController,
                  focusNode: _answerFocus,
                  maxLines: null,
                  minLines: 3,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: '想到了什么就写什么…',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 15,
                      color: AppColors.textHint,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 跳过按钮
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _answerController.clear();
                          ref
                              .read(thoughtDetailProvider(widget.thoughtId)
                                  .notifier)
                              .skipQuestion();
                        },
                        child: Text(
                          '跳过',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: AppColors.textHint,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.textHint,
                          ),
                        ),
                      ),
                      // 提交按钮
                      GestureDetector(
                        onTap: () {
                          final text = _answerController.text.trim();
                          if (text.isEmpty) return;
                          HapticFeedback.lightImpact();
                          _answerController.clear();
                          _answerFocus.unfocus();
                          ref
                              .read(thoughtDetailProvider(widget.thoughtId)
                                  .notifier)
                              .submitAnswer(text);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '发送',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 洞察卡片 ──────────────────────────────────────────────────────────────

  Widget _buildInsightCard(InsightCard card, List<String> emotionTags, Thought? thought) {
    return FadeTransition(
      opacity: _insightFadeAnim,
      child: SlideTransition(
        position: _insightSlideAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 洞察卡片标题
            Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                HandwrittenText('潜意识在说…',
                    fontSize: 18, color: AppColors.accentDeep),
                const Spacer(),
                if (thought?.weather != null || thought?.locationName != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(
                        [
                          if (thought?.weather != null) thought!.weather!,
                          if (thought?.locationName != null) thought!.locationName!,
                        ].join(' · '),
                        style: GoogleFonts.nunito(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              decoration: AppDecorations.insightCard(),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 深层解读
                  Text(
                    card.interpretation,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 心理学视角
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Text(
                              card.psychologyTheory,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          card.psychologyExplanation,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 行动指南
                  Row(
                    children: [
                      Icon(Icons.spa_outlined,
                          size: 14, color: AppColors.accentDeep),
                      const SizedBox(width: 6),
                      Text(
                        '可以试试',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...card.actionGuide.map((action) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                action,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            // 免责声明
            const SizedBox(height: 16),
            Text(
              '以上只是一种探索视角，不是诊断或建议，你才是自己最好的解读者。',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppColors.textHint,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionTagsSection(List<String> emotionTags) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签列表
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...emotionTags.map((tag) => _editingTags
                    ? _buildEditableEmotionTag(tag)
                    : _buildEmotionTag(tag)),
                if (_editingTags) _buildAddTagButton(),
              ],
            ),
          ),
          // 编辑按钮（右侧）
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _editingTags = !_editingTags),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _editingTags
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _editingTags ? AppColors.accent : AppColors.cardBorder,
                  width: 1,
                ),
              ),
              child: Text(
                _editingTags ? '完成' : '编辑',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: _editingTags ? AppColors.accent : AppColors.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionTag(String tag) {
    final color = _tagColors[tag] ?? AppColors.emotionNeutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: AppDecorations.emotionTag(color),
      child: Text(
        tag,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  static const _tagColors = {
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
    '温柔': AppColors.emotionJoy,
    '疲惫': AppColors.emotionNeutral,
    '释然': AppColors.emotionJoy,
    '叛逆': AppColors.emotionAnxiety,
    '怀念': AppColors.emotionSad,
  };

  Widget _buildEditableEmotionTag(String tag) {
    final color = _tagColors[tag] ?? AppColors.emotionNeutral;
    return GestureDetector(
      onTap: () => _confirmRemoveTag(tag),
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
        decoration: AppDecorations.emotionTag(color),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.close_rounded, size: 13, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTagButton() {
    return GestureDetector(
      onTap: _showAddTagDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 1.2,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: AppColors.textHint),
            const SizedBox(width: 3),
            Text(
              '添加',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveTag(String tag) {
    HapticFeedback.lightImpact();
    ref
        .read(thoughtDetailProvider(widget.thoughtId).notifier)
        .removeTag(tag);
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    // 预设常用标签（过滤掉已有的）
    final currentTags =
        ref.read(thoughtDetailProvider(widget.thoughtId)).thought?.emotionTags ?? [];
    final suggestions = _tagColors.keys
        .where((t) => !currentTags.contains(t))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HandwrittenText('添加情绪标签', fontSize: 18, color: AppColors.accentDeep),
            const SizedBox(height: 16),
            // 常用标签快选
            if (suggestions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((tag) {
                  final color = _tagColors[tag] ?? AppColors.emotionNeutral;
                  return GestureDetector(
                    onTap: () {
                      ref
                          .read(thoughtDetailProvider(widget.thoughtId).notifier)
                          .addTag(tag);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: AppDecorations.emotionTag(color),
                      child: Text(tag,
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: color)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 16),
            ],
            // 自定义输入
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 10,
                    decoration: InputDecoration(
                      hintText: '自定义标签…',
                      hintStyle: GoogleFonts.nunito(
                          fontSize: 14, color: AppColors.textHint),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.cardBorder, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.accent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    style: GoogleFonts.nunito(
                        fontSize: 14, color: AppColors.textPrimary),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        ref
                            .read(thoughtDetailProvider(widget.thoughtId)
                                .notifier)
                            .addTag(val.trim());
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    final val = controller.text.trim();
                    if (val.isNotEmpty) {
                      ref
                          .read(thoughtDetailProvider(widget.thoughtId).notifier)
                          .addTag(val);
                      Navigator.pop(ctx);
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading / Error ───────────────────────────────────────────────────────

  Widget _buildLoading(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 14),
          HandwrittenText(message, fontSize: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.accent, size: 32),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => ref
                .read(thoughtDetailProvider(widget.thoughtId).notifier)
                .retryInsight(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('重试',
                  style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
