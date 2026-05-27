import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppDecorations {
  AppDecorations._();

  // 手绘风卡片边框装饰
  static BoxDecoration card({Color? bg, double radius = 16}) => BoxDecoration(
        color: bg ?? AppColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      );

  // 洞察卡片专用装饰
  static BoxDecoration insightCard() => BoxDecoration(
        color: AppColors.insightCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.insightCardBorder, width: 1.2),
      );

  // 情绪标签装饰
  static BoxDecoration emotionTag(Color tagColor) => BoxDecoration(
        color: tagColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tagColor.withValues(alpha: 0.4), width: 1),
      );

  // 手绘风输入区背景（轻微纸张质感，用叠加微噪点模拟）
  static BoxDecoration inputArea() => const BoxDecoration(
        color: AppColors.pageBg,
      );
}

// 散落装饰点 — 首屏背景用的手绘风点缀
class ScatteredDots extends StatelessWidget {
  const ScatteredDots({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotsPainter(),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.accentLight.withValues(alpha: 0.35);

    // 固定位置的装饰小点，模拟手账散点
    final dots = [
      Offset(size.width * 0.08, size.height * 0.12),
      Offset(size.width * 0.93, size.height * 0.08),
      Offset(size.width * 0.15, size.height * 0.82),
      Offset(size.width * 0.88, size.height * 0.75),
      Offset(size.width * 0.5, size.height * 0.04),
      Offset(size.width * 0.72, size.height * 0.95),
    ];

    final sizes = [4.0, 3.0, 5.0, 3.5, 4.0, 3.0];

    for (var i = 0; i < dots.length; i++) {
      canvas.drawCircle(dots[i], sizes[i], paint);
    }

    // 几条短曲线
    final linePaint = Paint()
      ..color = AppColors.accentLight.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path1 = Path()
      ..moveTo(size.width * 0.05, size.height * 0.45)
      ..cubicTo(
        size.width * 0.06, size.height * 0.43,
        size.width * 0.08, size.height * 0.47,
        size.width * 0.09, size.height * 0.45,
      );
    canvas.drawPath(path1, linePaint);

    final path2 = Path()
      ..moveTo(size.width * 0.91, size.height * 0.38)
      ..cubicTo(
        size.width * 0.92, size.height * 0.36,
        size.width * 0.94, size.height * 0.40,
        size.width * 0.95, size.height * 0.38,
      );
    canvas.drawPath(path2, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
