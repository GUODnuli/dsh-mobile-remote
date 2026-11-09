// iPhone Duo (iPhone19,4) 与大屏/折叠屏自适应布局支持：
//
// 实测硬件与 iOS 27.1 UIKit 几何参数（3x 缩放）：
// - 外屏竖屏 (FP): 466 × 678 pt，右上角状态块 84 × 170 pt，UIKit 将右边缘整体设为 safeAreaInsets.right = 84 pt，
//   从而在右侧 x: 382..466, y: 170..678 形成一条 84 × 508 pt 的右侧扩展带（Right Strip）。
// - 外屏横屏 (FL/FR): 678 × 466 pt，右下或左上角状态块 84 × 82/84 pt。
// - 内屏展开横屏 (UL): 951 × 669 pt (Regular width)，右上角状态块 84 × 120 pt，UIKit 同样将右边缘设为 right = 84 pt；
//   若直接用默认 SafeArea 会导致内屏右侧出现 84pt 未铺满空白带。
// - 内屏展开竖屏 (UP): 669 × 951 pt，顶部 safeAreaInsets.top = 82 pt（右上 134 × 82 pt 状态岛）。
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum DuoPosture {
  /// 普通直板手机（如 390 × 844）
  standardPhone,

  /// iPhone Duo 外屏竖屏（如 466 × 678，矮宽屏 + 右侧 84pt 扩展区）
  duoOuterPortrait,

  /// iPhone Duo 外屏横屏（如 678 × 466，紧凑高度）
  duoOuterLandscape,

  /// iPhone Duo 展开内屏竖屏 / iPad mini 竖屏（如 669 × 951）
  duoInnerPortrait,

  /// iPhone Duo 展开内屏横屏 / iPad mini 横屏（如 951 × 669）
  duoInnerLandscape,
}

class DuoLayoutMetrics {
  final DuoPosture posture;
  final Size size;
  final EdgeInsets rawPadding;

  /// 右侧扩展导航栏宽度（仅外屏竖屏启用 QQ 音乐式右侧导航栏时 > 0，标准为 84pt）。
  final double rightStripWidth;

  /// 右侧扩展导航栏顶部需避让的状态角高度（外屏竖屏右上角 84 × 170 pt）。
  final double rightStripTopReserve;

  /// 内屏展开时右上角状态角尺寸（横屏 84 × 120 pt，竖屏 134 × 82 pt），仅供顶部 AppBar 右侧按钮避让，
  /// 不再把整条右边缘裁掉，从而让展开内屏 100% 铺满整个屏幕。
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

  /// 是否启用外屏右侧常驻导航区（QQ 音乐式外屏右侧栏）
  bool get hasOuterRightDock =>
      posture == DuoPosture.duoOuterPortrait && rightStripWidth > 0;

  /// 是否为展开内屏（横屏或竖屏）
  bool get isUnfoldedInner =>
      posture == DuoPosture.duoInnerLandscape ||
      posture == DuoPosture.duoInnerPortrait;

  /// 是否为展开内屏横屏（iPad mini 式左右主从双栏：左会话栏 + 右对话页）
  bool get isSplitMasterDetail => posture == DuoPosture.duoInnerLandscape;

  /// 是否为展开内屏竖屏（iPad mini Chatbot 式：左侧紧凑导航轨 + 可折叠会话抽屉 + 居中对话区）
  bool get isTabletPortrait => posture == DuoPosture.duoInnerPortrait;

  /// 将 UIKit 因角落状态块而放大的整边 safeAreaInsets 还原为真实边缘安全区，
  /// 避免展开内屏或外屏右侧出现整条黑边/白边。
  MediaQueryData normalizeMediaQuery(MediaQueryData base) {
    if (posture == DuoPosture.duoInnerLandscape && base.padding.right >= 60) {
      return base.copyWith(
        padding: base.padding.copyWith(right: 0),
        viewPadding: base.viewPadding.copyWith(right: 0),
      );
    }
    if (posture == DuoPosture.duoOuterPortrait && rightStripWidth > 0) {
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
        final cornerW = pad.right >= 60 ? pad.right : 0.0;
        return DuoLayoutMetrics(
          posture: DuoPosture.duoInnerLandscape,
          size: size,
          rawPadding: pad,
          topRightCornerBlock: cornerW > 0 ? Size(cornerW, 120) : Size.zero,
        );
      } else {
        // 内屏竖屏 (669 × 951)：右上角状态岛约 134 × 82 pt
        final isDuoInnerP =
            (w >= 640 && w <= 700 && h >= 920 && h <= 980) || pad.top >= 70;
        return DuoLayoutMetrics(
          posture: DuoPosture.duoInnerPortrait,
          size: size,
          rawPadding: pad,
          topRightCornerBlock: isDuoInnerP
              ? const Size(134, 82)
              : Size.zero,
        );
      }
    }

    // 2. iPhone Duo 外屏竖屏 (FP: 466 × 678 pt，或带右侧 84pt safeAreaInsets 的竖屏，
    //    以及 430..520 × 620..710 的矮宽外屏比例)
    final hasRightCornerInset = pad.right >= 60 && h > w;
    final isDuoCoverAspect =
        h > w && w >= 430 && w <= 520 && h >= 600 && h <= 710;
    if (hasRightCornerInset || isDuoCoverAspect) {
      final stripW = pad.right >= 60 ? pad.right : 76.0;
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

/// 顶层自适应作用域：允许子页面（HomeScreen / SessionsScreen / ChatScreen）感知当前是否处于
/// 双栏内嵌对话模式（避免在已并排显示 ChatScreen 时再重复 push 全屏路由）。
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
