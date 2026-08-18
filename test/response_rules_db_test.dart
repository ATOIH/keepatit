// D-11 response rules against a real (in-memory) database.
//
// NOTE for the CI hands: if this file fails with a LIBRARY LOAD error for
// sqlite3 on the runner (not an assertion failure), the approved mechanical
// fix is installing the system library in the workflow before `flutter test`:
//   sudo apt-get update && sudo apt-get install -y libsqlite3-dev
// Assertion failures, by contrast, are engine semantics — report, don't fix.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepatit/data/db.dart';
import 'package:keepatit/data/repository.dart';

void main() {
  late AppDb db;

  setUp(() {
    db = AppDb(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedHabit() => db.into(db.habits).insert(HabitsCompanion.insert(
        id: 'h1',
        directive: 'test habit',
        freqUnit: 'hours',
        intervalQty: const Value(1),
        windowStartMin: 480,
        windowEndMin: 1320,
        createdAt: DateTime(2026, 8, 17, 7, 0),
      ));

  Future<String?> stateOf(String id) async {
    final row = await (db.select(db.triggerLogs)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.state;
  }

  const key = 'h1|2026-08-18|600';

  test('first write wins for plain inserts (P-5 immutability)', () async {
    await seedHabit();
    await recordResponseByKey(db, key, 'done', 'app');
    await recordResponseByKey(db, key, 'not_done', 'app');
    expect(await stateOf(key), 'done');
  });

  test('D-11: notification response overwrites an auto-missed row', () async {
    await seedHabit();
    await db.into(db.triggerLogs).insert(TriggerLogsCompanion.insert(
          id: key,
          habitId: 'h1',
          localDate: '2026-08-18',
          scheduledHhmm: 600,
          state: 'missed',
        ));
    await recordResponseByKey(db, key, 'done', 'notification');
    expect(await stateOf(key), 'done');
  });

  test('D-11 boundary: app-sourced response does NOT overwrite missed',
      () async {
    await seedHabit();
    await db.into(db.triggerLogs).insert(TriggerLogsCompanion.insert(
          id: key,
          habitId: 'h1',
          localDate: '2026-08-18',
          scheduledHhmm: 600,
          state: 'missed',
        ));
    await recordResponseByKey(db, key, 'done', 'app');
    expect(await stateOf(key), 'missed');
  });

  test('D-11 boundary: a genuine done is never overwritten', () async {
    await seedHabit();
    await recordResponseByKey(db, key, 'done', 'notification');
    await recordResponseByKey(db, key, 'not_done', 'notification');
    expect(await stateOf(key), 'done');
  });

  test('D-11 boundary: excused stays excused (pause/DST semantics)', () async {
    await seedHabit();
    await db.into(db.triggerLogs).insert(TriggerLogsCompanion.insert(
          id: key,
          habitId: 'h1',
          localDate: '2026-08-18',
          scheduledHhmm: 600,
          state: 'excused',
        ));
    await recordResponseByKey(db, key, 'done', 'notification');
    expect(await stateOf(key), 'excused');
  });
}
