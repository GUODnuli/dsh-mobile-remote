// iPhone Duo (iPhone19,4) 与大屏/折叠屏自适应布局支持 + QQ 音乐 / 京东风格右侧胶囊/圆钮 SVG 导航组件：
//
// 实测硬件与 iOS 27.1 UIKit 几何参数（3x 缩放，LC_BUILD_VERSION sdk 27.1）：
// - 外屏竖屏 (FP): 466 × 678 pt，右上角状态块 84 × 170 pt，右侧 84 pt (x: 382..466, y: 170..678) 为系统保留的右侧栏区域。
// - 内屏展开横屏 (UL): 951 × 669 pt，右上角状态块 84 × 120 pt，右侧 84 pt (x: 867..951, y: 120..669) 同样为系统保留的右侧栏区域。
// - 内屏展开竖屏 (UP): 669 × 951 pt，顶部 safeAreaInsets.top = 82 pt（右上 134 × 82 pt 状态岛）。
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

enum DuoPosture {
  /// 普通直板手机（如 390 × 844）
  standardPhone,

  /// iPhone Duo 外屏竖屏（466 × 678，矮宽屏 + 右侧 84pt 扩展区）
  duoOuterPortrait,

  /// iPhone Duo 外屏横屏（678 × 466，紧凑高度）
  duoOuterLandscape,

  /// iPhone Duo 展开内屏竖屏 / iPad mini 竖屏（669 × 951）
  duoInnerPortrait,

  /// iPhone Duo 展开内屏横屏 / iPad mini 横屏（951 × 669，右侧 84pt 同样作为 side 栏）
  duoInnerLandscape,
}

class DuoLayoutMetrics {
  final DuoPosture posture;
  final Size size;
  final EdgeInsets rawPadding;

  /// 右侧 side 栏宽度（iPhone Duo 外屏竖屏与展开横屏均为 84pt）。
  final double rightStripWidth;

  /// 右侧 side 栏顶部需避让的系统状态角高度（外屏竖屏 170pt，展开内屏横屏 120pt）。
  final double rightStripTopReserve;

  /// 右上角状态角尺寸（外屏 84×170，内屏横屏 84×120，内屏竖屏 134×82）。
  final Size topRightCornerBlock;

  const DuoLayoutMetrics({
    required this.posture,
    required this.size,
    required this.rawPadding,
    this.rightStripWidth = 0,
    this.rightStripTopReserve = 0,
    this.topRightCornerBlock = Size.zero,
  });

  /// 是否为 iPhone Duo 外屏（含竖屏与横屏）或矮屏模式（高度 <= 700pt）
  bool get isOuterOrShortScreen =>
      posture == DuoPosture.duoOuterPortrait ||
      posture == DuoPosture.duoOuterLandscape ||
      size.height <= 700;

  /// 是否在外屏启用右侧 84pt 常驻 side 栏
  bool get hasOuterRightDock =>
      posture == DuoPosture.duoOuterPortrait && rightStripWidth > 0;

  /// 是否在当前形态（外屏竖屏 或 展开内屏）拥有右侧 84pt side 栏
  bool get hasRightSideRail =>
      (posture == DuoPosture.duoOuterPortrait ||
          posture == DuoPosture.duoInnerLandscape ||
          posture == DuoPosture.duoInnerPortrait) &&
      rightStripWidth > 0;

  /// 是否为展开内屏（横屏或竖屏）
  bool get isUnfoldedInner =>
      posture == DuoPosture.duoInnerLandscape ||
      posture == DuoPosture.duoInnerPortrait;

  /// 是否为展开内屏横屏（左侧会话栏 + 中间对话区 + 右侧 84pt side 栏）
  bool get isSplitMasterDetail => posture == DuoPosture.duoInnerLandscape;

  /// 是否为展开内屏竖屏（iPad mini Chatbot 式）
  bool get isTabletPortrait => posture == DuoPosture.duoInnerPortrait;

  /// 将 UIKit 因角落状态块而放大的整边 safeAreaInsets.right 归零（由我们的右侧 84pt 显式 side 栏接管），
  /// 确保左侧主内容区与底部输入框宽度严格一致且绝不侵入右侧 side 栏。
  MediaQueryData normalizeMediaQuery(MediaQueryData base) {
    if (hasRightSideRail ||
        (posture == DuoPosture.duoInnerLandscape && base.padding.right >= 60)) {
      return base.copyWith(
        padding: base.padding.copyWith(right: 0),
        viewPadding: base.viewPadding.copyWith(right: 0),
      );
    }
    return base;
  }

  static DuoLayoutMetrics fromMediaQuery(MediaQueryData mq) {
    final size = mq.size;
    final w = size.width;
    final h = size.height;
    final shortest = size.shortestSide;
    final pad = mq.padding;

    // 1. 展开内屏 / 平板级视口（iPhone Duo 内屏 669 × 951 / 951 × 669，shortestSide >= 560）
    if (shortest >= 560 || w >= 760) {
      if (w >= h) {
        final stripW = pad.right >= 60 ? pad.right : 84.0;
        final topReserve = pad.right >= 60
            ? math.max(120.0, pad.top + 12.0)
            : math.max(pad.top + 12.0, 48.0);
        return DuoLayoutMetrics(
          posture: DuoPosture.duoInnerLandscape,
          size: size,
          rawPadding: pad,
          rightStripWidth: stripW,
          rightStripTopReserve: topReserve,
          topRightCornerBlock: Size(stripW, topReserve),
        );
      } else {
        // 内屏竖屏 (669 × 951)：右上角状态岛约 134 × 82 pt，右侧同样保留 84pt side 栏
        final isDuoInnerP =
            (w >= 640 && w <= 700 && h >= 920 && h <= 980) || pad.top >= 70;
        final topReserve = isDuoInnerP
            ? math.max(96.0, pad.top + 12.0)
            : math.max(pad.top + 12.0, 56.0);
        return DuoLayoutMetrics(
          posture: DuoPosture.duoInnerPortrait,
          size: size,
          rawPadding: pad,
          rightStripWidth: 84.0,
          rightStripTopReserve: topReserve,
          topRightCornerBlock: isDuoInnerP
              ? const Size(134, 82)
              : Size.zero,
        );
      }
    }

    // 2. iPhone Duo 外屏竖屏 (FP: 466 × 678 pt，或带右侧 84pt safeAreaInsets 的竖屏)
    final hasRightCornerInset = pad.right >= 60 && h > w;
    final isDuoCoverAspect =
        h > w && w >= 430 && w <= 520 && h >= 600 && h <= 710;
    if (hasRightCornerInset || isDuoCoverAspect) {
      final stripW = pad.right >= 60 ? pad.right : 84.0;
      final topReserve = pad.right >= 60
          ? math.max(170.0, pad.top + 12.0)
          : math.max(pad.top + 8.0, 48.0);
      return DuoLayoutMetrics(
        posture: DuoPosture.duoOuterPortrait,
        size: size,
        rawPadding: pad,
        rightStripWidth: stripW,
        rightStripTopReserve: topReserve,
        topRightCornerBlock: Size(stripW, topReserve),
      );
    }

    // 3. iPhone Duo 外屏横屏 (FL/FR: 678 × 466 pt)
    if (w > h && w >= 600 && w <= 750 && h <= 500) {
      return DuoLayoutMetrics(
        posture: DuoPosture.duoOuterLandscape,
        size: size,
        rawPadding: pad,
      );
    }

    // 4. 普通直板手机
    return DuoLayoutMetrics(
      posture: DuoPosture.standardPhone,
      size: size,
      rawPadding: pad,
    );
  }
}

/// 顶层自适应作用域：允许子页面感知当前折叠形态与内联切换回调。
class DuoAdaptiveScope extends InheritedWidget {
  final DuoLayoutMetrics metrics;
  final ValueChanged<String>? onSelectSessionInline;

  const DuoAdaptiveScope({
    super.key,
    required this.metrics,
    this.onSelectSessionInline,
    required super.child,
  });

  static DuoAdaptiveScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuoAdaptiveScope>();

  static DuoLayoutMetrics metricsOf(BuildContext context) {
    final scope = maybeOf(context);
    if (scope != null) return scope.metrics;
    return DuoLayoutMetrics.fromMediaQuery(MediaQuery.of(context));
  }

  @override
  bool updateShouldNotify(DuoAdaptiveScope oldWidget) =>
      metrics.posture != oldWidget.metrics.posture ||
      metrics.size != oldWidget.metrics.size ||
      metrics.rawPadding != oldWidget.metrics.rawPadding ||
      onSelectSessionInline != oldWidget.onSelectSessionInline;
}

// ─────────────────────────────────────────────────────────────────────────────
// QQ 音乐 / 京东风格：右侧 Side 栏圆钮 / 椭圆胶囊 + 精细矢量 SVG 风格图标
// ─────────────────────────────────────────────────────────────────────────────

enum DuoSvgIconKind {
  home,
  sessions,
  settings,
  bell,
  plus,
  arrowLeft,
  arrowDown,
  moreHorizontal,
  sidebar,
}

/// 精细 1.7px 线宽矢量图标（对齐 QQ 音乐 / 京东 / iOS 27 右侧胶囊栏线性 SVG 风格）。
class DuoSvgIcon extends StatelessWidget {
  final DuoSvgIconKind kind;
  final double size;
  final Color color;
  final bool active;

  const DuoSvgIcon({
    super.key,
    required this.kind,
    this.size = 18,
    required this.color,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _DuoSvgIconPainter(
        kind: kind,
        color: color,
        active: active,
      ),
    );
  }
}

class _DuoSvgIconPainter extends CustomPainter {
  final DuoSvgIconKind kind;
  final Color color;
  final bool active;

  const _DuoSvgIconPainter({
    required this.kind,
    required this.color,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 2.0 : 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color.withValues(alpha: active ? 0.18 : 0.0)
      ..style = PaintingStyle.fill;

    switch (kind) {
      case DuoSvgIconKind.home:
        final path = Path()
          ..moveTo(w * 0.14, h * 0.45)
          ..lineTo(w * 0.50, h * 0.14)
          ..lineTo(w * 0.86, h * 0.45)
          ..lineTo(w * 0.86, h * 0.84)
          ..quadraticBezierTo(w * 0.86, h * 0.88, w * 0.80, h * 0.88)
          ..lineTo(w * 0.20, h * 0.88)
          ..quadraticBezierTo(w * 0.14, h * 0.88, w * 0.14, h * 0.84)
          ..close();
        if (active) canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        // 门弧
        final door = Path()
          ..moveTo(w * 0.40, h * 0.88)
          ..lineTo(w * 0.40, h * 0.62)
          ..quadraticBezierTo(w * 0.50, h * 0.54, w * 0.60, h * 0.62)
          ..lineTo(w * 0.60, h * 0.88);
        canvas.drawPath(door, stroke);
        break;

      case DuoSvgIconKind.sessions:
        final bubble = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.72, h * 0.54),
          Radius.circular(w * 0.18),
        );
        if (active) canvas.drawRRect(bubble, fill);
        canvas.drawRRect(bubble, stroke);
        // 底部对话小尖角
        final tail = Path()
          ..moveTo(w * 0.32, h * 0.72)
          ..lineTo(w * 0.24, h * 0.86)
          ..lineTo(w * 0.46, h * 0.72);
        canvas.drawPath(tail, stroke);
        // 内部两行短线
        canvas.drawLine(
          Offset(w * 0.30, h * 0.38),
          Offset(w * 0.70, h * 0.38),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.30, h * 0.52),
          Offset(w * 0.56, h * 0.52),
          stroke,
        );
        break;

      case DuoSvgIconKind.settings:
        // 双轨调节滑杆（现代 App 常用 SVG 设置图标，比锯齿齿轮在小尺寸下更清晰）
        canvas.drawLine(
          Offset(w * 0.16, h * 0.33),
          Offset(w * 0.84, h * 0.33),
          stroke,
        );
        canvas.drawLine(
          Offset(w * 0.16, h * 0.67),
          Offset(w * 0.84, h * 0.67),
          stroke,
        );
        final c1 = Offset(w * 0.38, h * 0.33);
        final c2 = Offset(w * 0.64, h * 0.67);
        final clearPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(c1, w * 0.12, fill);
        canvas.drawCircle(c1, w * 0.12, stroke);
        canvas.drawCircle(c2, w * 0.12, fill);
        canvas.drawCircle(c2, w * 0.12, stroke);
        if (active) {
          canvas.drawCircle(c1, w * 0.05, clearPaint);
          canvas.drawCircle(c2, w * 0.05, clearPaint);
        }
        break;

      case DuoSvgIconKind.bell:
        final bell = Path()
          ..moveTo(w * 0.24, h * 0.68)
          ..lineTo(w * 0.24, h * 0.44)
          ..arcToPoint(
            Offset(w * 0.76, h * 0.44),
            radius: Radius.circular(w * 0.26),
          )
          ..lineTo(w * 0.76, h * 0.68)
          ..lineTo(w * 0.84, h * 0.74)
          ..lineTo(w * 0.16, h * 0.74)
          ..close();
        if (active) canvas.drawPath(bell, fill);
        canvas.drawPath(bell, stroke);
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.78),
            width: w * 0.20,
            height: h * 0.16,
          ),
          0,
          math.pi,
          false,
          stroke,
        );
        break;

      case DuoSvgIconKind.plus:
        canvas.drawLine(
          Offset(w * 0.50, h * 0.22),
          Offset(w * 0.50, h * 0.78),
          stroke..strokeWidth = 2.0,
        );
        canvas.drawLine(
          Offset(w * 0.22, h * 0.50),
          Offset(w * 0.78, h * 0.50),
          stroke..strokeWidth = 2.0,
        );
        break;

      case DuoSvgIconKind.arrowLeft:
        canvas.drawLine(
          Offset(w * 0.78, h * 0.50),
          Offset(w * 0.24, h * 0.50),
          stroke,
        );
        final head = Path()
          ..moveTo(w * 0.48, h * 0.24)
          ..lineTo(w * 0.22, h * 0.50)
          ..lineTo(w * 0.48, h * 0.76);
        canvas.drawPath(head, stroke);
        break;

      case DuoSvgIconKind.arrowDown:
        canvas.drawLine(
          Offset(w * 0.50, h * 0.18),
          Offset(w * 0.50, h * 0.68),
          stroke,
        );
        final head = Path()
          ..moveTo(w * 0.26, h * 0.46)
          ..lineTo(w * 0.50, h * 0.70)
          ..lineTo(w * 0.74, h * 0.46);
        canvas.drawPath(head, stroke);
        // 底部短横线（直达底部语义）
        canvas.drawLine(
          Offset(w * 0.26, h * 0.84),
          Offset(w * 0.74, h * 0.84),
          stroke,
        );
        break;

      case DuoSvgIconKind.moreHorizontal:
        final dotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        final r = w * 0.085;
        canvas.drawCircle(Offset(w * 0.24, h * 0.50), r, dotPaint);
        canvas.drawCircle(Offset(w * 0.50, h * 0.50), r, dotPaint);
        canvas.drawCircle(Offset(w * 0.76, h * 0.50), r, dotPaint);
        break;

      case DuoSvgIconKind.sidebar:
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.14, h * 0.18, w * 0.72, h * 0.64),
          Radius.circular(w * 0.14),
        );
        canvas.drawRRect(rect, stroke);
        canvas.drawLine(
          Offset(w * 0.38, h * 0.18),
          Offset(w * 0.38, h * 0.82),
          stroke,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DuoSvgIconPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.active != active;
}

/// 椭圆形胶囊托盘（QQ 音乐 / 京东右侧胶囊容器）。
class DuoPillPlatter extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double width;

  const DuoPillPlatter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    this.width = 52,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = DshColors.surface(context);
    final line = DshColors.line(context);
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: surface.withValues(alpha: isDark ? 0.90 : 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: line, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 胶囊托盘内的单个椭圆形/圆形 Tab 按钮（带 SVG 图标与精简文字）。
class DuoNavPillButton extends StatelessWidget {
  final DuoSvgIconKind icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DuoNavPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = DshColors.brand(context);
    final brandSoft = DshColors.brandSoft(context);
    final ink2 = DshColors.ink2(context);
    final fg = selected ? brand : ink2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? brandSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DuoSvgIcon(
                kind: icon,
                size: 18,
                color: fg,
                active: selected,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 独立圆形悬浮按钮（用于通知、＋新建、返回、跳到底部、对话更多操作）。
class DuoCircleButton extends StatelessWidget {
  final DuoSvgIconKind icon;
  final String? tooltip;
  final VoidCallback onTap;
  final bool primary;
  final int badgeCount;
  final double size;

  const DuoCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.primary = false,
    this.badgeCount = 0,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brand = DshColors.brand(context);
    final onBrand = DshColors.onBrand(context);
    final surface = DshColors.surface(context);
    final line = DshColors.line(context);
    final ink = DshColors.ink(context);

    Widget btn = Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primary
                ? brand
                : surface.withValues(alpha: isDark ? 0.92 : 0.96),
            border: primary ? null : Border.all(color: line, width: 0.9),
            boxShadow: [
              BoxShadow(
                color: primary
                    ? brand.withValues(alpha: 0.32)
                    : Colors.black.withValues(alpha: isDark ? 0.26 : 0.07),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: DuoSvgIcon(
              kind: icon,
              size: size * 0.42,
              color: primary ? onBrand : ink,
              active: primary,
            ),
          ),
        ),
      ),
    );

    if (badgeCount > 0) {
      btn = Stack(
        clipBehavior: Clip.none,
        children: [
          btn,
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: DshColors.danger(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: surface, width: 1.5),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
