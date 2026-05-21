import 'package:flutter/material.dart';

/// 快捷提示类型
enum SnackType { success, error, info }

/// 全局 SnackBar 组件（旅行主题风格）
/// 支持成功、错误、信息三种类型，所有界面文字保持原样（英文或中文均可）
class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    SnackType type = SnackType.success,
  }) {
    // 根据类型获取主色与渐变末色
    final (startColor, endColor, icon) = switch (type) {
      SnackType.success => (
        const Color(0xFF2ECC71), // 鲜绿色
        const Color(0xFF27AE60), // 深绿色
        Icons.check_circle_rounded,
      ),
      SnackType.error => (
        const Color(0xFFE74C3C), // 珊瑚红
        const Color(0xFFC0392B), // 深红
        Icons.error_outline_rounded,
      ),
      SnackType.info => (
        const Color(0xFF5D9CEC), // 天空蓝
        const Color(0xFF4A90E2), // 宝石蓝
        Icons.info_outline_rounded,
      ),
    };

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16), // 增加边缘间距，更独立
      padding: EdgeInsets.zero, // 由内部 Container 控制
      content: _StyledSnackContent(
        startColor: startColor,
        endColor: endColor,
        icon: icon,
        message: message,
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}

/// 内部自定义内容组件（支持动画渐变效果）
class _StyledSnackContent extends StatelessWidget {
  final Color startColor;
  final Color endColor;
  final IconData icon;
  final String message;

  const _StyledSnackContent({
    required this.startColor,
    required this.endColor,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // 旅行风格渐变背景
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: startColor.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
        // 精致内边框（增加层次感）
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 图标 + 微光背景
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                // 提示文字
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
