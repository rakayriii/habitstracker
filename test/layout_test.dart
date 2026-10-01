import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/app/app.dart';
import 'package:habitstracker/app/router.dart';
import 'package:habitstracker/data/database/data_providers.dart';

import 'support/test_harness.dart';

/// Target device: Samsung SM-A035F, Android 13, 360 x 800 dp.
///
/// This walks every workspace and every detail screen at that size, scrolling
/// each one to the end, and fails on any layout error. That is where a
/// RenderFlex overflow shows up.
void main() {
  setUp(() => router.go('/'));

  final offenders = <String>[];

  Future<void> walk(WidgetTester tester, TestHarness harness, double scale) async {
    // Capture the offending widget for the failure message, and hand the error
    // on to the default handler so it still fails the test.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      offenders.add(details.toString());
      previous?.call(details);
    };
    final overrides = [
      databaseProvider.overrideWithValue(harness.database),
      clockProvider.overrideWithValue(() => TestHarness.fixedNow),
    ];
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const MyOSApp()),
    );
    if (scale != 1) {
      // Applied inside the tree so the same layout code is measured, only with
      // larger glyphs.
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const MyOSApp(),
          ),
        ),
      );
    }
    await settle(tester);

    final routes = <String>[
      '/',
      '/finance',
      '/finance/accounts',
      '/goals',
      '/goals/goal-emergency-fund',
      '/goals/goal-emergency-fund/edit',
      '/projects',
      '/projects/prj-myos',
      '/projects/prj-myos/task/new',
    ];

    for (final route in routes) {
      router.go(route);
      await settle(tester);
      for (var i = 0; i < 4; i++) {
        await scrollBy(tester, -320);
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'layout error on $route: ${offenders.join(' | ')}',
      );
    }
  }

  testWidgets('every screen has no layout error on a 360x800 device',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final harness = await TestHarness.create();
    try {
      await walk(tester, harness, 1);
    } finally {
      await shutdownApp(tester, harness);
    }
  });

  testWidgets('no screen overflows when the system text scale is large',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final harness = await TestHarness.create();
    try {
      await walk(tester, harness, 1.3);
    } finally {
      await shutdownApp(tester, harness);
    }
  });
}