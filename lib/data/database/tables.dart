import 'package:drift/drift.dart';

/// Schema version. Bump this and add a step in [AppDatabase.migration] for
/// every shipped schema change; never delete a step, because that is what
/// makes an upgrade destructive.
const int kSchemaVersion = 1;

/// Key/value application settings. Small by design: the values this app owns
/// are the operator name used in the header and the default currency for new
/// accounts.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Accounts and assets. `balance` is a cache of the transaction ledger, never
/// an independent source of truth: it is recomputed after every ledger change.
@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// AccountType.name
  TextColumn get type => text()();
  IntColumn get balance => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  TextColumn get notes => text().nullable()();

  /// True when the balance is money owed rather than money held.
  BoolColumn get isLiability => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The ledger. Every movement of money is a row here, including the opening
/// balance of an account, so a balance can always be explained.
@DataClassName('TransactionRow')
class Transactions extends Table {
  TextColumn get id => text()();

  /// Always positive. Direction lives in [type].
  IntColumn get amount => integer()();

  /// TransactionType.name
  TextColumn get type => text()();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get title => text().withLength(min: 1, max: 120)();

  /// Source account, or the only account for income and expense.
  @ReferenceName('sourceTransactions')
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();

  /// Destination account, transfer only. The named references keep drift from
  /// generating two identically named relation helpers on Accounts.
  @ReferenceName('destinationTransactions')
  TextColumn get targetAccountId => text()
      .nullable()
      .references(Accounts, #id, onDelete: KeyAction.restrict)();

  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().nullable()();

  /// GoalCategory.name
  TextColumn get category => text()();

  /// GoalStatus.name
  TextColumn get status => text()();
  IntColumn get targetValue => integer()();
  IntColumn get currentValue => integer().withDefault(const Constant(0))();

  /// GoalPriority.name
  TextColumn get priority => text()();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Milestones are thresholds on the goal value, kept separate so the goal
/// value itself stays a single number.
@DataClassName('GoalMilestoneRow')
class GoalMilestones extends Table {
  TextColumn get id => text()();
  TextColumn get goalId =>
      text().references(Goals, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  IntColumn get targetValue => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get description => text().nullable()();

  /// ProjectStatus.name
  TextColumn get status => text()();
  TextColumn get category => text().withDefault(const Constant('OTHER'))();

  /// TaskPriority.name, reused so the two modules speak one language.
  TextColumn get priority => text()();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get nextAction => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Stack and tags, normalised so a tag is searchable and editable on its own.
@DataClassName('ProjectTagRow')
class ProjectTags extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().withLength(min: 1, max: 40)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Project progress is derived from this table, never stored as a percentage.
@DataClassName('ProjectTaskRow')
class ProjectTasks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().nullable()();

  /// TaskPriority.name
  TextColumn get priority => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FocusItemRow')
class FocusItems extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 120)();

  /// FocusPriority.name
  TextColumn get priority => text()();

  /// Midnight of the day this item belongs to, so the daily query is an index
  /// hit rather than a range scan.
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
