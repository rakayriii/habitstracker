import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitstracker/app/app.dart';
import 'package:habitstracker/app/router.dart';
import 'package:habitstracker/data/database/data_providers.dart';

import 'support/test_harness.dart';

/// Widget level coverage over the real database.
///
/// The harness runs the same seed the app runs on a fresh install, so every
/// assertion below is about rows that were written to SQLite and read back
/// through the repositories. There is no fixture injected into a widget here.
///
/// Data assertions that need to await a provider future live in `test/data/`,
/// because a widget test body runs in a fake async zone where a stream future
/// never completes. The checks here are on rendered output.
Future<void> withHarness(
  WidgetTester tester,
  Future<void> Function(TestHarness harness) body,
) async {
  final harness = await TestHarness.create();
  try {
    // The router is a top level instance, so each test starts from a known
    // workspace instead of wherever the previous one navigated to.
    router.go('/');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(harness.database),
          clockProvider.overrideWithValue(() => TestHarness.fixedNow),
        ],
        child: const MyOSApp(),
      ),
    );
    await settle(tester);
    await body(harness);
  } finally {
    await shutdownApp(tester, harness);
  }
}

void main() {
  testWidgets('home renders the aggregation layer', (tester) async {
    await withHarness(tester, (harness) async {
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('NET WORTH'), findsOneWidget);
      expect(find.text("Today's focus"), findsOneWidget);
      expect(find.text('Active goals'), findsOneWidget);
      expect(find.text('Active projects'), findsOneWidget);

      // Seeded rows are on screen, which means the screen read the database.
      expect(find.text('Sub-20min 5K Run'), findsOneWidget);
      expect(find.text('MyOS'), findsWidgets);

      // The focus list is below the fold on a 360x800 phone, so it is brought
      // into view before it is checked.
      await scrollBy(tester, -400, times: 2);
      expect(
        find.text('Tutup tagihan bulanan dan cek kartu kredit'),
        findsOneWidget,
      );
    });
  });

  testWidgets('bottom navigation reaches all four workspaces', (tester) async {
    await withHarness(tester, (harness) async {
      for (final (label, expectation) in [
        ('Finance', 'Posisi keuangan'),
        ('Goals', 'Target'),
        ('Projects', 'Proyek'),
        ('Home', 'Home'),
      ]) {
        await tester.tap(find.text(label).last);
        await settle(tester);
        expect(find.text(expectation), findsWidgets, reason: 'after $label');
      }
    });
  });

  testWidgets('finance renders computed sections and seeded accounts',
      (tester) async {
    await withHarness(tester, (harness) async {
      await tester.tap(find.text('Finance').last);
      await settle(tester);

      expect(find.text('Alokasi aset'), findsOneWidget);
      expect(find.text('Arus kas'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Cash & Liquidity'), findsWidgets);
      expect(find.text('Bitcoin'), findsWidgets);
    });
  });

  testWidgets('the period rail switches the reported period', (tester) async {
    await withHarness(tester, (harness) async {
      await tester.tap(find.text('Finance').last);
      await settle(tester);
      expect(find.text('Periode bulan ini'), findsOneWidget);

      await tester.tap(find.text('TAHUN INI'));
      await settle(tester);
      expect(find.text('Periode tahun ini'), findsOneWidget);

      await tester.tap(find.text('BULAN LALU'));
      await settle(tester);
      expect(find.text('Periode bulan lalu'), findsOneWidget);
    });
  });

  testWidgets('goal status filter narrows the list and can empty it',
      (tester) async {
    await withHarness(tester, (harness) async {
      await tester.tap(find.text('Goals').last);
      await settle(tester);
      expect(find.text('Dana darurat 12 bulan'), findsOneWidget);

      await tester.tap(find.text('ARCHIVED 1'));
      await settle(tester);
      expect(find.text('Rak homelab di garasi'), findsOneWidget);
      expect(find.text('Dana darurat 12 bulan'), findsNothing);

      // System holds two goals and neither is completed, so Completed on that
      // category reaches the empty panel.
      await tester.tap(find.text('SEMUA'));
      await settle(tester);

      // The two filter dimensions are independent, and together they can leave
      // nothing behind: no goal is both Health and Completed.
      await tester.drag(find.byType(Scrollable).last, const Offset(-240, 0));
      await settle(tester);
      await tester.tap(find.text('HEALTH 1'));
      await settle(tester);
      expect(find.text('Sub-20min 5K Run'), findsOneWidget);

      await tester.drag(find.byType(Scrollable).last, const Offset(240, 0));
      await settle(tester);
      await tester.tap(find.text('COMPLETED 2'));
      await settle(tester);
      expect(find.text('TIDAK ADA TARGET COCOK'), findsOneWidget);
    });
  });

  testWidgets('project status filter shows only that status', (tester) async {
    await withHarness(tester, (harness) async {
      await tester.tap(find.text('Projects').last);
      await settle(tester);
      expect(find.text('MyOS'), findsWidgets);

      await tester.tap(find.text('ON HOLD 1'));
      await settle(tester);
      expect(find.text('Seva'), findsWidgets);
      expect(find.text('MyOS'), findsNothing);
    });
  });

  testWidgets('a goal detail route opens and comes back', (tester) async {
    await withHarness(tester, (harness) async {
      await tester.tap(find.text('Goals').last);
      await settle(tester);

      await tester.tap(find.text('Dana darurat 12 bulan'));
      await settle(tester);

      expect(find.text('Sisa nilai'), findsOneWidget);
      expect(find.text('Butuh per hari'), findsOneWidget);

      await scrollBy(tester, -400, times: 3);
      // Form section titles render uppercase, like every other micro label.
      expect(find.text('MILESTONE'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Kembali'));
      await settle(tester);
      expect(find.text('Daftar target'), findsOneWidget);
    });
  });

  testWidgets('a project detail route lists tasks and their progress',
      (tester) async {
    await withHarness(tester, (harness) async {
      await tester.tap(find.text('Projects').last);
      await settle(tester);

      await tester.tap(find.text('MyOS').first);
      await settle(tester);

      expect(find.text('Task terbuka'), findsOneWidget);
      expect(find.text('Task selesai'), findsOneWidget);
      // MyOS is seeded with eight tasks, four of them done.
      // The line sits under the meter in the header and again on the Projects
      // list behind it, so more than one match is expected here.
      expect(find.text('4/8 task selesai'), findsWidgets);
      expect(find.text('50%'), findsWidgets);
    });
  });

  testWidgets('a transaction detail route opens from the ledger',
      (tester) async {
    await withHarness(tester, (harness) async {
      await tester.tap(find.text('Finance').last);
      await settle(tester);

      // The ledger sits well below the fold on this screen, and a row that is
      // not built cannot be tapped.
      final row = find.text('Gaji bulanan');
      expect(await scrollUntilFound(tester, row), isTrue);
      await tapFirstVisible(tester, row);

      expect(find.text('Hapus transaksi'), findsOneWidget);
      await scrollBy(tester, -300);
      expect(find.text('Dicatat'), findsOneWidget);
    });
  });

  testWidgets('an unknown id shows the not found state', (tester) async {
    await withHarness(tester, (harness) async {
      router.go('/goals/does-not-exist');
      await settle(tester);
      expect(find.text('TIDAK DITEMUKAN'), findsOneWidget);
    });
  });

  testWidgets('the transaction form validates before it writes',
      (tester) async {
    await withHarness(tester, (harness) async {
      router.go('/finance/transaction/new');
      await settle(tester);

      await tester.tap(find.text('Catat transaksi'));
      await settle(tester);

      expect(find.text('Nominal harus lebih besar dari nol'), findsOneWidget);
      expect(find.text('Judul transaksi wajib diisi'), findsOneWidget);
    });
  });

  testWidgets('an account form refuses an empty name', (tester) async {
    await withHarness(tester, (harness) async {
      router.go('/finance/account/new');
      await settle(tester);

      await tester.tap(find.text('Simpan akun'));
      await settle(tester);

      expect(find.text('Nama akun wajib diisi'), findsOneWidget);
    });
  });
}
