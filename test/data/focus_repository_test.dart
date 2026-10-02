import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/data/database/data_providers.dart';
import 'package:habitstracker/data/repositories/focus_repository.dart';
import 'package:habitstracker/domain/errors.dart';
import 'package:habitstracker/domain/models/focus_item.dart';
import 'package:habitstracker/features/focus/providers/focus_providers.dart';

import '../support/test_harness.dart';

void main() {
  late TestHarness harness;

  setUp(() async => harness = await TestHarness.create());
  tearDown(() => harness.dispose());

  FocusRepository repository() =>
      harness.container.read(focusRepositoryProvider);
  FocusActions actions() => harness.container.read(focusActionsProvider);

  test('the seed puts five items on today, one already done', () async {
    final items = await repository()
        .watchForDate(harness.container.read(todayProvider))
        .first;

    expect(items, hasLength(5));
    expect(items.where((item) => item.isCompleted), hasLength(1));
  });

  test('create, edit, complete and delete', () async {
    final created = await actions().create(
      title: 'Susun anggaran kuartal depan',
      priority: FocusPriority.p1,
    );
    expect(created.title, 'Susun anggaran kuartal depan');

    await actions().update(
      id: created.id,
      title: 'Susun anggaran dan tinjau',
      priority: FocusPriority.p2,
    );
    final stored = await repository().findById(created.id);
    expect(stored!.title, 'Susun anggaran dan tinjau');
    expect(stored.priority, FocusPriority.p2);
    expect(stored.isCompleted, isFalse);

    await actions().setCompleted(created.id, true);
    expect((await repository().findById(created.id))!.isCompleted, isTrue);

    await actions().delete(created.id);
    expect(await repository().findById(created.id), isNull);
  });

  test('an empty title is rejected', () async {
    await expectLater(
      actions().create(title: '   ', priority: FocusPriority.p2),
      throwsA(isA<ValidationException>()),
    );
  });

  test('a missing item reports not found', () async {
    await expectLater(
      repository().delete('focus-nope'),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('today only ever reads one day', () async {
    final today = harness.container.read(todayProvider);
    final yesterday = DateTime(2026, 1, 1).subtract(const Duration(days: 1));
    final longAgo = DateTime(2026, 1, 1);

    await actions().create(
      title: 'Hari lama',
      priority: FocusPriority.p3,
      date: yesterday,
    );

    final todayItems = await repository().watchForDate(today).first;
    expect(
      todayItems.any((item) => item.title == 'Hari lama'),
      isFalse,
    );

    final overdue = await repository().watchOverdue(today).first;
    expect(overdue.map((item) => item.title), contains('Hari lama'));

    // Completing the backlog item takes it out of the overdue list.
    final item = overdue.firstWhere((i) => i.title == 'Hari lama');
    await actions().setCompleted(item.id, true);
    final stillOverdue = await repository().watchOverdue(today).first;
    expect(stillOverdue.any((i) => i.id == item.id), isFalse);

    expect(await repository().watchForDate(longAgo).first, isEmpty);
  });

  test('the counters follow the checkbox', () async {
    final container = harness.container;
    container.listen(focusCountsProvider, (_, _) {}, fireImmediately: true);
    container.listen(nextFocusProvider, (_, _) {}, fireImmediately: true);

    // The counters derive from the stream, so it has to deliver a value first.
    await container.read(todayFocusProvider.future);

    final before = container.read(focusCountsProvider);
    expect(before.total, 5);
    expect(before.done, 1);

    // The seeded P1 that is still open leads the "next up" line.
    final next = container.read(nextFocusProvider);
    expect(next?.title, 'Lengkapi modul Finance di Nexa');

    final open = (await repository()
            .watchForDate(container.read(todayProvider))
            .first)
        .where((item) => !item.isCompleted)
        .first;
    await actions().setCompleted(open.id, true);

    await waitUntil(
      () => container.read(focusCountsProvider).done == before.done + 1,
    );
    expect(container.read(focusCountsProvider).done, 2);
  });
}