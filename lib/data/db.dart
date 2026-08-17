// Local persistence — drift over SQLite. Schema is PRD §9 verbatim.
// All data lives on-device; participates in OS device backup only.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'db.g.dart';

class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get directive => text().withLength(min: 1, max: 80)();
  TextColumn get freqUnit => text()(); // 'minutes' | 'hours' | 'daily'
  IntColumn get intervalQty => integer().nullable()();
  IntColumn get windowStartMin => integer()();
  IntColumn get windowEndMin => integer()();
  IntColumn get restDay => integer().nullable()(); // 1=Mon … 7=Sun (F-14)
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get deactivatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()(); // tombstone (D-10)

  @override
  Set<Column> get primaryKey => {id};
}

class TriggerLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().references(Habits, #id)();
  TextColumn get localDate => text()(); // 'YYYY-MM-DD' as generated (PRD §8.3)
  IntColumn get scheduledHhmm => integer()(); // minutes from local midnight
  DateTimeColumn get firedAt => dateTime().nullable()();
  DateTimeColumn get respondedAt => dateTime().nullable()();
  // scheduled | fired | done | not_done | missed | excused (PRD §8.4)
  TextColumn get state => text()();
  TextColumn get responseSource => text().nullable()(); // 'notification' | 'app'

  @override
  Set<Column> get primaryKey => {id};
}

class AppState extends Table {
  // program_start_date, pause_all, pause_started_at, precision_mode,
  // priming_done, entitlement_pro (PRD §9/§12)
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Habits, TriggerLogs, AppState])
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // Future versions: stepwise migrations, proven by QA #14 before release.
      );
}

/// Production database in the app documents directory.
AppDb openAppDb() {
  return AppDb(LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(
        File(p.join(dir.path, 'keepatit.db')));
  }));
}
