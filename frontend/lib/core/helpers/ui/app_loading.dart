import 'package:flutter/material.dart';
import 'dart:math';

/// 旅游规划应用全局加载组件
/// 使用Overlay实现，不依赖Navigator栈，支持异步安全调用
class AppLoading {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  /// 显示加载提示
  /// [context] 用于获取OverlayState的BuildContext
  /// [message] 加载提示文字，默认为"正在加载..."
  static void show(BuildContext context, {String message = "Loading..."}) {
    if (_isShowing) return;

    final overlayState = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => _LoadingWidget(
        message: message,
        onDismiss: () {
          // 当组件自身触发销毁时（如页面关闭），同步状态
          _isShowing = false;
          _overlayEntry = null;
        },
      ),
    );

    overlayState.insert(_overlayEntry!);
    _isShowing = true;
  }

  /// 隐藏加载提示
  /// [context] 可选参数，保持与旧代码兼容
  static void hide([BuildContext? context]) {
    if (!_isShowing) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }
}

/// 加载动画组件（带旅行元素）
class _LoadingWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _LoadingWidget({required this.message, required this.onDismiss});

  @override
  State<_LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<_LoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    // 旋转动画：每圈持续1.2秒，无限循环
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // 添加曲线效果，使旋转更自然
    _rotationAnimation = CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    widget.onDismiss(); // 通知外部组件已销毁
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 半透明背景遮罩（阻止用户交互）
          ModalBarrier(
            color: Colors.black.withValues(alpha: 0.4),
            dismissible: false,
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                // 旅行风格渐变背景
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                    const Color(0xFFF5F9FF),
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                // 精致边框（可选）
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 旅行主题动画：旋转的纸飞机 + 装饰小点
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 外圈光晕效果
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF4A90E2).withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            radius: 0.8,
                          ),
                        ),
                      ),
                      // 旋转的纸飞机图标
                      RotationTransition(
                        turns: _rotationAnimation,
                        child: const Icon(
                          Icons.send_rounded,
                          size: 52,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                      // 装饰性小圆点（围绕飞机旋转）
                      ..._buildOrbitDots(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 加载提示文字
                  Text(
                    widget.message,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // 动态点状加载指示器（增强视觉反馈）
                  _buildDotLoader(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 围绕飞机的装饰性轨道小点（增强旅行感）
  List<Widget> _buildOrbitDots() {
    const dotCount = 4;
    const radius = 42.0;
    final dots = <Widget>[];

    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 90.0) * pi / 180; // 初始角度
      final animation = Tween<double>(begin: angle, end: angle + 2 * pi)
          .animate(
            CurvedAnimation(parent: _rotationController, curve: Curves.linear),
          );

      dots.add(
        AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            final currentAngle = animation.value;
            final dx = radius * cos(currentAngle);
            final dy = radius * sin(currentAngle);
            return Positioned(
              left: 44 + dx - 4,
              top: 44 + dy - 4,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return dots;
  }

  /// 点状加载动画（三个跳动的点）
  Widget _buildDotLoader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDot(0),
        const SizedBox(width: 8),
        _buildDot(1),
        const SizedBox(width: 8),
        _buildDot(2),
      ],
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        final value = (_rotationController.value * 3 + index) % 1;
        final opacity = (0.3 + value * 0.7).clamp(0.0, 1.0);
        final scale = 0.8 + value * 0.4;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4A90E2).withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}

// ==================== 使用示例 ====================
/*
class TravelBuddyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('TravelBuddy')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            AppLoading.show(context, message: '正在寻找绝美路线...');
            await Future.delayed(Duration(seconds: 2));
            AppLoading.hide();
          },
          child: Text('模拟加载行程'),
        ),
      ),
    );
  }
}
*/
