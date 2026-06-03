import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 控制 MainShell 底部导航切换的 provider。
/// 写入目标 tab index（0=Capture, 1=Timeline, 2=Mirror），
/// MainShell 监听后执行切换，然后将值重置为 -1。
final shellTabProvider = StateProvider<int>((ref) => -1);

/// 写入思维惯性模式名称后，Mirror 页会自动切到「思维惯性」子 tab 并滚动定位到对应卡片。
/// Mirror 页处理完后自动重置为 null。
final mirrorHighlightPatternProvider = StateProvider<String?>((ref) => null);
