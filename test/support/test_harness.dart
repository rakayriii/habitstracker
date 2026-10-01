import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/data/database/app_database.dart';
import 'package:habitstracker/data/database/data_providers.dart';

/// In-memory database wired into the provider graph, plus a pinned clock so
/// period, pace and ageing assertions are deterministic.
class TestHarness {
  TestHarness._(this.container, this.database);

  final ProviderContainer container;
  final AppDatabase database;

  /// Today's date at 08:00.
  ///
  /// The clock has to agree with the seed, which stamps its rows with the real
  /// install date, otherwise "today's focus" would query a day the seed never
  /// wrote to. Pinning the time of day keeps period and pace assertions stable
  /// while the date still matches the rows.
  static final fixedNow = DateTime.now().copyWith(hour: 8);

  /// A second container over the same database, for tests that need one view of
  /// the data while a widget test holds another.
  ProviderContainer buildContainer() => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      clockProvider.overrideWithValue(() => fixedNow),
    ],
  );

  static Future<TestHarness> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => fixedNow),
      ],
    );
    // The first query opens the file, which is what creates the schema and
    // runs the seed. The seed lives in onCreate, so this happens exactly once.
    //
    // No settle delay here on purpose: a widget test calls this from inside
    // its fake async zone, where a timer never fires until the tester pumps.
    // Widget tests drain the seed notifications through [settle] instead.
    await database.select(database.accounts).get();
    return TestHarness._(container, database);
  }

  /// Closes the container and the database. Safe to call twice.
  Future<void> dispose() async {
    container.dispose();
    await database.close();
  }
}

/// Tears the app down in the order a widget test needs.
///
/// Unmounting the tree first disposes the ProviderScope, which cancels the drift
/// query streams. Drift releases its stream cache from a zero duration timer,
/// and a widget test fails if a timer is still pending when the body returns, so
/// the test clock is advanced in small steps afterwards. Only then is the
/// database closed, which is what releases the SQLite file.
Future<void> shutdownApp(WidgetTester tester, TestHarness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await harness.dispose();
}

/// Lets the local database streams deliver their first value, then rebuilds.
///
/// Bounded on purpose: `pumpAndSettle` waits for the scheduler to go quiet and
/// will sit there for its full timeout if anything keeps scheduling frames. A
/// fixed number of pumps is enough for a navigation or a stream update and
/// cannot hang.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}
/// Drags the main list on the current screen, settling after each step. The hub
/// screens are `ListView`s that build lazily, so a section further down the
/// page has to be scrolled into view before it exists in the tree at all.
Future<void> scrollBy(
  WidgetTester tester,
  double dy, {
  int times = 1,
}) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < times; i++) {
    await tester.drag(list, Offset(0, dy));
    await settle(tester);
  }
}

/// Scrolls the current list until [finder] matches something, then stops.
///
/// The hub screens are `ListView`s, so anything below the fold is not built at
/// all until it is scrolled close to the viewport.
Future<bool> scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  double step = -320,
  int maxScrolls = 14,
}) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < maxScrolls; i++) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.drag(list, Offset(0, step));
    await settle(tester);
  }
  return finder.evaluate().isNotEmpty;
}

/// Scrolls until a candidate of [finder] is on screen, then taps it.
///
/// A lazy list can hold widgets that are built but scrolled out of the
/// viewport, and tapping one of those hits whatever is painted at its
/// coordinates instead. So the search is on visibility, not on existence.
Future<void> tapFirstVisible(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 16,
}) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final list = find.byType(Scrollable).first;
  // The bottom navigation sits over the last stretch of the viewport, so a
  // candidate below this line would be tapped on the navigation instead.
  const bottomInset = 72.0;

  for (var attempt = 0; attempt < maxScrolls; attempt++) {
    final count = finder.evaluate().length;
    for (var i = 0; i < count; i++) {
      final center = tester.getCenter(finder.at(i), warnIfMissed: false);
      if (center.dy > 40 &&
          center.dy < size.height - bottomInset &&
          center.dx > 0 &&
          center.dx < size.width) {
        await tester.tapAt(center);
        await settle(tester);
        return;
      }
    }
    await tester.drag(list, const Offset(0, -300));
    await settle(tester);
  }
  throw TestFailure('No on screen candidate found for $finder');
}

/// Waits for a condition that a database stream update will satisfy.
///
/// Drift re-emits on the next event loop turn after a write, so a derived
/// provider is briefly one value behind the write that caused it.
Future<void> waitUntil(
  bool Function() condition, {
  Duration step = const Duration(milliseconds: 10),
  int maxAttempts = 60,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (condition()) return;
    await Future<void>.delayed(step);
  }
  if (!condition()) throw TestFailure('Condition never became true');
}

/// Resolves the first value of a stream provider.
///
/// Reading `provider.future` on a provider that nothing is listening to never
/// completes, because the subscription is torn down before the stream delivers.
/// Every widget in the app listens, so this only matters in tests.
///
/// The listener is deliberately left open: a stream provider that loses its
/// last listener stops reacting to database changes, and several tests read the
/// value once and then assert that it follows a write. Disposing the container
/// at the end of the test releases it.
Future<T> firstValue<T>(
  ProviderContainer container,
  StreamProvider<T> provider,
) async {
  container.listen<AsyncValue<T>>(provider, (_, _) {}, fireImmediately: true);
  return container.read(provider.future);
}

/// Lets the database streams finish the notifications they already queued.
///
/// Drift tells listeners about each table separately, so a provider derived
/// from two of them emits more than once per write. Tests that read a derived
/// value right after a write wait here rather than guessing a delay.
Future<void> settleStreams([
  Duration duration = const Duration(milliseconds: 60),
]) {
  return Future<void>.delayed(duration);
}
