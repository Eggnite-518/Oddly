import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 控制 MainShell 底部导航切换的 provider。
/// 写入目标 tab index（0=Capture, 1=Timeline, 2=Mirror），
/// MainShell 监听后执行切换，然后将值重置为 -1。
final shellTabProvider = StateProvider<int>((ref) => -1);
