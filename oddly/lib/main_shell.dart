import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/theme/app_colors.dart';
import 'features/capture/capture_screen.dart';
import 'features/mirror/mirror_provider.dart';
import 'features/mirror/mirror_screen.dart';
import 'features/timeline/timeline_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    CaptureScreen(),
    TimelineScreen(),
    MirrorScreen(),
  ];

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
    // Mirror 页每次切过去时刷新一次数据
    if (index == 2) {
      ref.read(mirrorProvider.notifier).reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _OddlyNavBar(
        currentIndex: _currentIndex,
        onTap: switchToTab,
      ),
    );
  }
}

// ── 手绘风底部导航栏 ─────────────────────────────────────────────────────────

class _OddlyNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _OddlyNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: _CatchIcon(),
            label: 'Catch',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: _TimelineIcon(),
            label: 'Timeline',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: _MirrorIcon(),
            label: 'Mirror',
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: icon,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.caveat(
                fontSize: 13,
                color: isActive ? AppColors.accent : AppColors.textHint,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 手绘感图标（CustomPainter） ────────────────────────────────────────────────

class _CatchIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _CatchPainter(),
    );
  }
}

class _CatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // 闪电/捕捉形状：一个简单的笔触
    final path = Path()
      ..moveTo(size.width * 0.55, size.height * 0.1)
      ..lineTo(size.width * 0.3, size.height * 0.48)
      ..lineTo(size.width * 0.52, size.height * 0.48)
      ..lineTo(size.width * 0.45, size.height * 0.9);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CatchPainter old) => false;
}

class _TimelineIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _TimelinePainter(),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // 竖线
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.12),
      Offset(size.width * 0.35, size.height * 0.88),
      paint,
    );

    // 三条横线（时间轴条目）
    for (final y in [0.25, 0.5, 0.75]) {
      canvas.drawLine(
        Offset(size.width * 0.35, size.height * y),
        Offset(size.width * 0.78, size.height * y),
        paint,
      );
      // 小圆点
      canvas.drawCircle(
        Offset(size.width * 0.35, size.height * y),
        2.5,
        Paint()..color = AppColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => false;
}

class _MirrorIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _MirrorPainter(),
    );
  }
}

class _MirrorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);

    // 三个同心涟漪圆
    for (final r in [3.5, 6.5, 10.0]) {
      canvas.drawCircle(center, r, paint);
    }

    // 中心实心点
    canvas.drawCircle(
      center,
      2,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_MirrorPainter old) => false;
}
