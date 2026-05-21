import 'package:flutter/material.dart';

/// 旅游规划应用全局对话框组件
class AppDialog {
  /// 显示错误对话框
  static void showError(BuildContext context, String message) {
    _showDialog(context, type: DialogType.error, message: message);
  }

  /// 显示成功对话框
  static void showSuccess(BuildContext context, String message) {
    _showDialog(context, type: DialogType.success, message: message);
  }

  /// 显示警告对话框
  static void showWarning(BuildContext context, String message) {
    _showDialog(context, type: DialogType.warning, message: message);
  }

  /// 显示信息对话框
  static void showInfo(BuildContext context, String message) {
    _showDialog(context, type: DialogType.info, message: message);
  }

  /// 内部统一显示方法
  static void _showDialog(
    BuildContext context, {
    required DialogType type,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true, // 允许点击背景关闭
      builder: (context) => _TravelDialog(type: type, message: message),
    );
  }
}

/// 对话框类型枚举
enum DialogType { error, success, warning, info }

/// 旅行主题对话框组件（所有用户可见文字均为英文）
class _TravelDialog extends StatelessWidget {
  final DialogType type;
  final String message;

  const _TravelDialog({required this.type, required this.message});

  /// 获取类型对应的图标和颜色
  (IconData, Color) get _typeData {
    switch (type) {
      case DialogType.error:
        return (Icons.error_outline_rounded, const Color(0xFFE74C3C));
      case DialogType.success:
        return (Icons.check_circle_outline_rounded, const Color(0xFF27AE60));
      case DialogType.warning:
        return (Icons.warning_amber_rounded, const Color(0xFFF39C12));
      case DialogType.info:
        return (Icons.info_outline_rounded, const Color(0xFF4A90E2));
    }
  }

  /// 获取标题（英文）
  String get _title {
    switch (type) {
      case DialogType.error:
        return 'Error';
      case DialogType.success:
        return 'Success';
      case DialogType.warning:
        return 'Warning';
      case DialogType.info:
        return 'Travel Tip';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (iconData, color) = _typeData;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: isTablet ? 420 : screenWidth * 0.85,
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          // 旅行风格纸张渐变
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFFDFBF7),
              const Color(0xFFF9F5EF),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部装饰条（山峰线条）
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                children: [
                  // 动态图标 + 柔和光晕
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.1),
                        ),
                      ),
                      Icon(iconData, size: 52, color: color),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 标题（英文）
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 内容消息（传入的英文）
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // 操作按钮（英文 "OK"）
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: color.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
