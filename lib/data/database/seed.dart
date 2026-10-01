import 'package:drift/drift.dart';

import '../../domain/models/account.dart';
import '../../domain/models/focus_item.dart';
import '../../domain/models/goal.dart';
import '../../domain/models/project.dart';
import '../../domain/models/transaction.dart';
import 'app_database.dart';

/// Initial content for a fresh install.
///
/// Runs once, inside `onCreate`. After this the database belongs to the user:
/// nothing here is ever re-inserted, and deleting a seeded row keeps it
/// deleted across restarts.
///
/// The numbers are internally consistent because the account balances are not
/// written by hand. They are recomputed from the ledger rows below, so the net
/// worth the app shows is the sum of the transactions a user can actually open
/// and read.
Future<void> seedDatabase(AppDatabase db) async {
  await db.transaction(() async {
    final now = DateTime.now();
    // Everything below is anchored to the install date, not to a fixed
    // calendar, so "this month" and the 30 day trend always have real data
    // behind them whenever the app is first opened.
    final thisMonth = DateTime(now.year, now.month);
    final created = thisMonth.subtract(const Duration(days: 400));

    // ---------------------------------------------------------------- settings
    await db.batch((b) {
      b.insertAll(db.settings, [
        SettingsCompanion.insert(
          key: 'operatorName',
          value: 'Raka',
          updatedAt: now,
        ),
        SettingsCompanion.insert(
          key: 'defaultCurrency',
          value: 'IDR',
          updatedAt: now,
        ),
      ]);
    });

    // ---------------------------------------------------------------- accounts
    const cashId = 'acc-cash-liquidity';
    const equitiesId = 'acc-global-equities';
    const bitcoinId = 'acc-bitcoin';
    const goldId = 'acc-physical-gold';
    const cardId = 'acc-credit-card';

    await db.batch((b) {
      b.insertAll(db.accounts, [
        AccountsCompanion.insert(
          id: cashId,
          name: 'Cash & Liquidity',
          type: AccountType.bank.name,
          currency: const Value('IDR'),
          notes: const Value('Tabungan utama, reksa dana, dan kas harian'),
          createdAt: created,
          updatedAt: created,
          sortOrder: const Value(0),
        ),
        AccountsCompanion.insert(
          id: equitiesId,
          name: 'Global Equities',
          type: AccountType.stocks.name,
          currency: const Value('IDR'),
          notes: const Value('VOO, QQQ, SPTID'),
          createdAt: created,
          updatedAt: created,
          sortOrder: const Value(1),
        ),
        AccountsCompanion.insert(
          id: bitcoinId,
          name: 'Bitcoin',
          type: AccountType.bitcoin.name,
          currency: const Value('IDR'),
          notes: const Value('0,1420 BTC, cold wallet'),
          createdAt: created,
          updatedAt: created,
          sortOrder: const Value(2),
        ),
        AccountsCompanion.insert(
          id: goldId,
          name: 'Physical Gold',
          type: AccountType.gold.name,
          currency: const Value('IDR'),
          notes: const Value('Emas fisik 62 g'),
          createdAt: created,
          updatedAt: created,
          sortOrder: const Value(3),
        ),
        AccountsCompanion.insert(
          id: cardId,
          name: 'Kartu Kredit',
          type: AccountType.creditCard.name,
          currency: const Value('IDR'),
          notes: const Value('Saldo adalah utang, jatuh tempo 12 Okt'),
          isLiability: const Value(true),
          createdAt: created,
          updatedAt: created,
          sortOrder: const Value(4),
        ),
      ]);
    });

    // ------------------------------------------------------------- ledger
    // Amounts are integers in rupiah. An account starts with an opening entry
    // so that every later balance is explainable from the ledger.
    var txIndex = 0;
    String txId() => 'tx-${(++txIndex).toString().padLeft(3, '0')}';

    Future<void> addTransaction({
      required String accountId,
      required int amount,
      required TransactionType type,
      required String title,
      required String category,
      required DateTime date,
      String? targetAccountId,
      String? notes,
    }) async {
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: txId(),
          accountId: accountId,
          amount: amount,
          type: type.name,
          title: title,
          category: Value(category),
          targetAccountId: Value(targetAccountId),
          date: date,
          notes: Value(notes),
          createdAt: date,
          updatedAt: date,
        ),
      );
    }

    // Opening entries. These are dated well before the ledger window below, so
    // the current balances are the result of a savings history rather than a
    // number typed into a column.
    await addTransaction(
      accountId: cashId,
      amount: 2578000,
      type: TransactionType.income,
      title: 'Saldo awal rekening',
      category: 'Saldo awal',
      date: created,
    );
    await addTransaction(
      accountId: equitiesId,
      amount: 3620000,
      type: TransactionType.income,
      title: 'Saldo awal reksa dan saham',
      category: 'Saldo awal',
      date: created,
    );
    await addTransaction(
      accountId: bitcoinId,
      amount: 630000,
      type: TransactionType.income,
      title: 'Saldo awal BTC',
      category: 'Saldo awal',
      date: created,
    );
    await addTransaction(
      accountId: goldId,
      amount: 1500000,
      type: TransactionType.income,
      title: 'Saldo awal emas',
      category: 'Saldo awal',
      date: created,
    );

    // One month of a real household ledger. Income is Rp 13 juta, spending is
    // Rp 12,24 juta, and the Rp 400 ribu left over is invested rather than
    // piling up as cash. Those three rules are what make the closing balances
    // land on a believable net worth instead of a month of salary multiplied
    // by six.
    const salary = 13000000;
    const monthly = <(int day, int amount, String title, String category)>[
      (5, 3500000, 'Sewa apartemen', 'Housing'),
      (8, 3600000, 'Belanja dan makan', 'Groceries'),
      (12, 900000, 'Transport dan bensin', 'Transport'),
      (15, 940000, 'Tagihan dan langganan', 'Utilities'),
      (20, 2300000, 'Cicilan aset', 'Loan'),
      (22, 1000000, 'Asuransi kesehatan', 'Health'),
    ];

    // Six months of history so the cashflow chart and the year figures have
    // real bars behind them, newest last.
    for (var monthOffset = 5; monthOffset >= 0; monthOffset--) {
      final month = DateTime(thisMonth.year, thisMonth.month - monthOffset);
      final isCurrent = monthOffset == 0;

      if (!isCurrent) {
        await addTransaction(
          accountId: cashId,
          amount: salary,
          type: TransactionType.income,
          title: 'Gaji bulanan',
          category: 'Gaji',
          date: DateTime(month.year, month.month, 25),
        );
      }
      for (final (day, amount, title, category) in monthly) {
        await addTransaction(
          accountId: cashId,
          amount: amount,
          type: TransactionType.expense,
          title: title,
          category: category,
          date: DateTime(month.year, month.month, day),
        );
      }
      await addTransaction(
        accountId: cashId,
        amount: 400000,
        type: TransactionType.transfer,
        title: 'Bitcoin DCA',
        category: 'Investasi',
        date: DateTime(month.year, month.month, 27),
        targetAccountId: bitcoinId,
      );
    }

    // Current month only: the salary lands at the start of the month, the
    // dividend mid month, and the card bill is the expense that explains the
    // liability balance sitting on the credit card account.
    await addTransaction(
      accountId: cashId,
      amount: salary,
      type: TransactionType.income,
      title: 'Gaji bulanan',
      category: 'Gaji',
      date: thisMonth,
    );
    await addTransaction(
      accountId: cashId,
      amount: 412000,
      type: TransactionType.income,
      title: 'Dividen SPTID',
      category: 'Dividen',
      date: thisMonth.add(const Duration(days: 4)),
    );
    await addTransaction(
      accountId: cardId,
      amount: 850000,
      type: TransactionType.expense,
      title: 'Belanja kartu kredit',
      category: 'Groceries',
      // Two months ago, so the debt has been sitting on the statement for a
      // while instead of appearing the moment the app is installed.
      date: DateTime(thisMonth.year, thisMonth.month - 1, 12),
      notes: 'Jatuh tempo 12 bulan berikutnya',
    );

    await db.refreshAccountBalances();

    // ------------------------------------------------------------------ goals
    await _seedGoals(db, now, thisMonth);
    await _seedProjects(db, now, thisMonth);
    await _seedFocus(db, now);
  });
}

Future<void> _seedGoals(
  AppDatabase db,
  DateTime now,
  DateTime thisMonth,
) async {
  Future<void> insertGoal({
    required String id,
    required String title,
    required String description,
    required GoalCategory category,
    required int target,
    required int current,
    required GoalPriority priority,
    required GoalStatus status,
    DateTime? deadline,
    List<(String, int)> milestones = const [],
    DateTime? completedAt,
  }) async {
    await db.into(db.goals).insert(
      GoalsCompanion.insert(
        id: id,
        title: title,
        description: Value(description),
        category: category.name,
        status: status.name,
        targetValue: target,
        currentValue: Value(current),
        priority: priority.name,
        deadline: Value(deadline),
        createdAt: now,
        updatedAt: now,
      ),
    );
    var order = 0;
    for (final (label, value) in milestones) {
      // A milestone is completed when the goal value has passed it, so the
      // milestone list can never disagree with the progress bar.
      final reached = current >= value;
      await db.into(db.goalMilestones).insert(
        GoalMilestonesCompanion.insert(
          id: '$id-ms-$order',
          goalId: id,
          title: label,
          targetValue: value,
          sortOrder: Value(order),
          completedAt: Value(reached ? now : null),
          createdAt: now,
          updatedAt: now,
        ),
      );
      order++;
    }
    if (completedAt != null) {
      await (db.update(db.goals)..where((g) => g.id.equals(id))).write(
        GoalsCompanion(
          status: Value(status.name),
          updatedAt: Value(completedAt),
        ),
      );
    }
  }

  await insertGoal(
    id: 'goal-emergency-fund',
    title: 'Dana darurat 12 bulan',
    description: 'Enam bulan pengeluaran pokok sebagai bantalan.',
    category: GoalCategory.finance,
    target: 24000000,
    current: 8400000,
    priority: GoalPriority.high,
    status: GoalStatus.active,
    deadline: DateTime(thisMonth.year, thisMonth.month + 3, 0),
    milestones: const [
      ('Dana darurat 1 bulan', 5612800),
      ('Dana darurat 3 bulan', 16838400),
      ('Dana darurat 6 bulan', 33676800),
      ('Dana darurat 12 bulan', 67353600),
    ],
  );
  await insertGoal(
    id: 'goal-property',
    title: 'Investasi properti Rp 1 M',
    description: 'Kouncil tiap kuartal, evaluasi carry dan lokasi.',
    category: GoalCategory.finance,
    target: 1000000000,
    current: 385000000,
    priority: GoalPriority.medium,
    status: GoalStatus.active,
    deadline: DateTime(thisMonth.year + 3, thisMonth.month, 0),
    milestones: const [
      ('Kouncil dan lokasi', 150000000),
      ('DP dan legalitas', 300000000),
      ('Renovasi awal', 600000000),
      ('Disewa penuh', 1000000000),
    ],
  );
  await insertGoal(
    id: 'goal-5k-run',
    title: 'Sub-20min 5K Run',
    description: 'Interval 2x400m, long run setiap Sabtu pagi.',
    category: GoalCategory.health,
    target: 20,
    current: 14,
    priority: GoalPriority.high,
    status: GoalStatus.active,
    deadline: DateTime(thisMonth.year, thisMonth.month + 1, 12),
    milestones: const [
      ('5K di bawah 25 menit', 5),
      ('5K di bawah 22 menit', 12),
      ('5K di bawah 20 menit', 20),
    ],
  );
  await insertGoal(
    id: 'goal-read-20',
    title: 'Baca 20 buku',
    description: 'Nonfiction dan teknik, dua buku per bulan.',
    category: GoalCategory.learning,
    target: 20,
    current: 11,
    priority: GoalPriority.medium,
    status: GoalStatus.active,
    deadline: DateTime(thisMonth.year, thisMonth.month + 3, 28),
    milestones: const [
      ('5 buku', 5),
      ('10 buku', 10),
      ('15 buku', 15),
      ('20 buku', 20),
    ],
  );
  await insertGoal(
    id: 'goal-build-10',
    title: 'Build 10 projects',
    description: 'Satu rilis produksi per kuartal.',
    category: GoalCategory.system,
    target: 10,
    current: 4,
    priority: GoalPriority.medium,
    status: GoalStatus.active,
    deadline: DateTime(thisMonth.year + 1, thisMonth.month, 0),
    milestones: const [
      ('2 rilis', 2),
      ('4 rilis', 4),
      ('7 rilis', 7),
      ('10 rilis', 10),
    ],
  );
  await insertGoal(
    id: 'goal-budget-2026',
    title: 'Anggaran bulanan 2026',
    description: 'Tahan pengeluaran di bawah rata-rata 6 bulan.',
    category: GoalCategory.finance,
    target: 12000000,
    current: 12000000,
    priority: GoalPriority.high,
    status: GoalStatus.completed,
    deadline: DateTime(thisMonth.year, thisMonth.month, 0),
    completedAt: thisMonth,
  );
  await insertGoal(
    id: 'goal-cfp',
    title: 'Sertifikasi CFP',
    description: 'Enam modul, ujian akhir dua hari.',
    category: GoalCategory.career,
    target: 6,
    current: 6,
    priority: GoalPriority.medium,
    status: GoalStatus.completed,
    deadline: thisMonth.subtract(const Duration(days: 60)),
    completedAt: thisMonth.subtract(const Duration(days: 60)),
  );
  await insertGoal(
    id: 'goal-homelab',
    title: 'Rak homelab di garasi',
    description: 'Dipindahkan ke arsip sampai ruang belajar siap.',
    category: GoalCategory.system,
    target: 1,
    current: 0,
    priority: GoalPriority.low,
    status: GoalStatus.archived,
    deadline: thisMonth.subtract(const Duration(days: 120)),
  );
}

Future<void> _seedProjects(
  AppDatabase db,
  DateTime now,
  DateTime thisMonth,
) async {
  Future<void> insertProject({
    required String id,
    required String name,
    required String description,
    required ProjectStatus status,
    required String category,
    required TaskPriority priority,
    required List<String> tags,
    required String? nextAction,
    DateTime? deadline,
    required List<(String, TaskPriority, bool)> tasks,
  }) async {
    await db.into(db.projects).insert(
      ProjectsCompanion.insert(
        id: id,
        name: name,
        description: Value(description),
        status: status.name,
        category: Value(category),
        priority: priority.name,
        deadline: Value(deadline),
        nextAction: Value(nextAction),
        createdAt: now,
        updatedAt: now,
      ),
    );
    for (var i = 0; i < tags.length; i++) {
      await db.into(db.projectTags).insert(
        ProjectTagsCompanion.insert(
          id: '$id-tag-$i',
          projectId: id,
          label: tags[i],
          sortOrder: Value(i),
        ),
      );
    }
    for (var i = 0; i < tasks.length; i++) {
      final (title, priority, done) = tasks[i];
      await db.into(db.projectTasks).insert(
        ProjectTasksCompanion.insert(
          id: '$id-task-$i',
          projectId: id,
          title: title,
          priority: priority.name,
          sortOrder: Value(i),
          completedAt: Value(done ? now : null),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  await insertProject(
    id: 'prj-myos',
    name: 'MyOS',
    description: 'Personal operating system untuk keuangan, target, dan proyek.',
    status: ProjectStatus.inDevelopment,
    category: 'System',
    priority: TaskPriority.high,
    tags: const ['Flutter', 'Riverpod', 'SQLite'],
    nextAction: 'Hubungkan ringkasan Home ke data real',
    deadline: thisMonth.add(const Duration(days: 60)),
    tasks: const [
      ('Rancang schema lokal', TaskPriority.high, true),
      ('Bangun design system token', TaskPriority.medium, true),
      ('Rebuild empat workspace', TaskPriority.high, true),
      ('Simpan data secara lokal', TaskPriority.high, true),
      ('Form transaksi dan akun', TaskPriority.high, false),
      ('Detail goal dan milestone', TaskPriority.medium, false),
      ('Detail proyek dan task', TaskPriority.medium, false),
      ('Uji overflow di 360dp', TaskPriority.low, false),
    ],
  );
  await insertProject(
    id: 'prj-nexus-core',
    name: 'Nexus Core',
    description: 'Gateway services internal dengan queue dan tracing.',
    status: ProjectStatus.inDevelopment,
    category: 'Infra',
    priority: TaskPriority.high,
    tags: const ['Go', 'NATS', 'Kubernetes'],
    nextAction: 'Cutover runbook dan uji rollback',
    deadline: thisMonth.add(const Duration(days: 30)),
    tasks: const [
      ('Rancang kontrak service', TaskPriority.medium, true),
      ('Implement queue adapter', TaskPriority.high, true),
      ('Tracing OpenTelemetry', TaskPriority.medium, true),
      ('Uji beban gateway', TaskPriority.high, true),
      ('Cutover runbook', TaskPriority.high, false),
      ('Uji rollback', TaskPriority.high, false),
    ],
  );
  await insertProject(
    id: 'prj-mediavault',
    name: 'MediaVault',
    description: 'Koleksi media pribadi dengan retensi dan tagging.',
    status: ProjectStatus.inDevelopment,
    category: 'Storage',
    priority: TaskPriority.medium,
    tags: const ['Node', 'Postgres', 'S3'],
    nextAction: 'Aturan lifecycle object storage',
    tasks: const [
      ('Skema tabel', TaskPriority.medium, true),
      ('Ingest dari disk lokal', TaskPriority.medium, true),
      ('Deduplikasi hash', TaskPriority.low, true),
      ('Thumbnail worker', TaskPriority.medium, false),
      ('Aturan lifecycle', TaskPriority.medium, false),
      ('Pencarian full text', TaskPriority.low, false),
      ('Ekspor metadata', TaskPriority.low, false),
    ],
  );
  await insertProject(
    id: 'prj-seva',
    name: 'Seva',
    description: 'Landing produk untuk Kittelab, tertunda sejak Q2.',
    status: ProjectStatus.onHold,
    category: 'Product',
    priority: TaskPriority.low,
    tags: const ['Next.js', 'Supabase'],
    nextAction: 'Menunggu arah brand dari Kittelab',
    tasks: const [
      ('Brief produk', TaskPriority.low, true),
      ('Wireframe landing', TaskPriority.low, false),
      ('Form lead', TaskPriority.low, false),
    ],
  );
  await insertProject(
    id: 'prj-portfolio',
    name: 'Portfolio v2',
    description: 'Portofolio statis yang dibangun ulang dengan Astro.',
    status: ProjectStatus.shipped,
    category: 'Web',
    priority: TaskPriority.medium,
    tags: const ['Astro', 'Tailwind'],
    nextAction: null,
    tasks: const [
      ('Struktur konten', TaskPriority.medium, true),
      ('Migrasi halaman', TaskPriority.medium, true),
      ('Audit aksesibilitas', TaskPriority.low, true),
      ('Deploy', TaskPriority.medium, true),
    ],
  );
}

Future<void> _seedFocus(AppDatabase db, DateTime now) async {
  final today = DateTime(now.year, now.month, now.day);
  var index = 0;
  Future<void> add(
    String title,
    FocusPriority priority, {
    bool done = false,
    String? notes,
  }) async {
    index++;
    await db.into(db.focusItems).insert(
      FocusItemsCompanion.insert(
        id: 'focus-$index',
        title: title,
        priority: priority.name,
        date: today,
        notes: Value(notes),
        completedAt: Value(done ? today : null),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  await add(
    'Tutup tagihan bulanan dan cek kartu kredit',
    FocusPriority.p1,
    done: true,
  );
  await add('Lengkapi modul Finance di MyOS', FocusPriority.p1);
  await add('Review runbook cutover Nexus Core', FocusPriority.p2);
  await add('Jadwalkan DCA Bitcoin bulan ini', FocusPriority.p2);
  await add('Long run 5K, target di bawah 20 menit', FocusPriority.p3);
}
