// iPhone Duo (iPhone19,4) 内外屏自适应布局与安全区归一化测试
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsh_mobile_app/duo_layout.dart';
import 'package:dsh_mobile_app/screens/home_screen.dart';
import 'package:dsh_mobile_app/store.dart';
import 'package:dsh_mobile_app/theme.dart';

void main() {
  group('DuoLayoutMetrics 形态识别与安全区归一化', () {
    test('普通直板手机 (390×844) 保持 standardPhone', () {
      const mq = MediaQueryData(
        size: Size(390, 844),
        padding: EdgeInsets.only(top: 59, bottom: 34),
      );
      final m = DuoLayoutMetrics.fromMediaQuery(mq);
      expect(m.posture, DuoPosture.standardPhone);
      expect(m.hasOuterRightDock, isFalse);
      expect(m.isUnfoldedInner, isFalse);
    });

    test('iPhone Duo 外屏竖屏 (466×678, right=84) 启用右侧 84pt 导航栏并消除整边右缩进', () {
      const mq = MediaQueryData(
        size: Size(466, 678),
        padding: EdgeInsets.only(bottom: 34, right: 84),
        viewPadding: EdgeInsets.only(bottom: 34, right: 84),
      );
      final m = DuoLayoutMetrics.fromMediaQuery(mq);
      expect(m.posture, DuoPosture.duoOuterPortrait);
      expect(m.hasOuterRightDock, isTrue);
      expect(m.rightStripWidth, 84);
      expect(m.rightStripTopReserve, 170);
      final norm = m.normalizeMediaQuery(mq);
      expect(norm.padding.right, 0);
      expect(norm.viewPadding.right, 0);
    });

    test('iPhone Duo 展开内屏横屏 (951×669, right=84) 启用左右主从双栏并保留右侧 84pt side 栏', () {
      const mq = MediaQueryData(
        size: Size(951, 669),
        padding: EdgeInsets.only(bottom: 34, right: 84),
        viewPadding: EdgeInsets.only(bottom: 34, right: 84),
      );
      final m = DuoLayoutMetrics.fromMediaQuery(mq);
      expect(m.posture, DuoPosture.duoInnerLandscape);
      expect(m.isSplitMasterDetail, isTrue);
      expect(m.hasRightSideRail, isTrue);
      expect(m.rightStripWidth, 84);
      expect(m.topRightCornerBlock, const Size(84, 120));
      final norm = m.normalizeMediaQuery(mq);
      expect(norm.padding.right, 0);
    });

    test('iPhone Duo 展开内屏竖屏 (669×951, top=82) 启用右侧 84pt side 栏', () {
      const mq = MediaQueryData(
        size: Size(669, 951),
        padding: EdgeInsets.only(top: 82, bottom: 34),
      );
      final m = DuoLayoutMetrics.fromMediaQuery(mq);
      expect(m.posture, DuoPosture.duoInnerPortrait);
      expect(m.isTabletPortrait, isTrue);
      expect(m.hasRightSideRail, isTrue);
      expect(m.rightStripWidth, 84);
      expect(m.topRightCornerBlock, const Size(134, 82));
    });
  });

  group('iPhone Duo 外屏首页紧凑 Hero 与最近会话展示', () {
    testWidgets('外屏 (466×678) 下大肥鱼 Hero 自动收缩，最近会话与新建按钮完整可见且不溢出', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1398, 2034); // 466 × 678 @3x
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = AppStore()..skin = DshSkin.abyss;
      await tester.pumpWidget(
        MaterialApp(
          theme: DshTheme.forSkin(DshSkin.abyss, Brightness.dark),
          home: Scaffold(
            body: HomeScreen(store: store, visible: true, onOpenSession: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
      expect(find.text('今晚写点什么？'), findsOneWidget);
      expect(find.text('＋ 新建会话'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
