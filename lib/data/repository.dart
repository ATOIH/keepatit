// Repository — the app-level API over the drift database (PRD §9, §8.4).
// State machine rules live here: log rows are written only for terminal states
// (done / not_done / missed / excused) plus app-sourced dones. Terminal rows are
// immutable (P-5 honest data): inserts use insertOrIgnore, first write wins.
import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../engine/instance_generator.dart';
import '../engine/materialize.dart';
import '../engine/models.dart';
import 'db.dart';

// ---------------------------------------------------------------- instance keys

String instanceKey(String habitId, String localDate, int minuteOfDay) =>
    '$habitId|$localDate|$minuteOfDay';

({String habitId, String localDate, int minuteOfDay})? parseInstanceKey(
    String key) {
  final parts = key.split('|');
  if (parts.length != 3) return null;
  final minute = int.tryParse(parts[2]);
  if (minute == null) return null;
  return (habitId: parts[0], localDate: parts[1], minuteOfDay: minute);
}

String localDateOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------- row <-> spec

HabitSpec specFromRow(Habit row) => HabitSpec(
      id: row.id,
      directive: row.directive,
      unit: FreqUnit.values.firstWhere((u) => u.name == row.freqUnit),
      intervalQty: row.intervalQty,
      windowStartMin: row.windowStartMin,
      windowEndMin: row.windowEndMin,
      restDay: row.restDay,
    );

// ---------------------------------------------------------------- habit CRUD

Future<List<Habit>> activeHabitRows(AppDb db) =>
    (db.select(db.habits)
          ..where((t) => t.active.equals(true) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

Stream<List<Habit>> watchActiveHabitRows(AppDb db) =>
    (db.select(db.habits)
          ..where((t) => t.active.equals(true) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();

Future<void> insertHabit(AppDb db, HabitSpec spec) =>
    db.into(db.habits).insert(HabitsCompanion.insert(
          id: spec.id,
          directive: spec.directive.trim(),
          freqUnit: spec.unit.name,
          intervalQty: Value(spec.intervalQty),
          windowStartMin: spec.windowStartMin,
          windowEndMin: spec.windowEndMin,
          restDay: Value(spec.restDay),
          createdAt: DateTime.now(),
        ));

Future<void> updateHabit(AppDb db, HabitSpec spec) =>
    (db.update(db.habits)..where((t) => t.id.equals(spec.id)))
        .write(HabitsCompanion(
      directive: Value(spec.directive.trim()),
      freqUnit: Value(spec.unit.name),
      intervalQty: Value(spec.intervalQty),
      windowStartMin: Value(spec.windowStartMin),
      windowEndMin: Value(spec.windowEndMin),
      restDay: Value(spec.restDay),
    ));

Future<void> deactivateHabit(AppDb db, String id) =>
    (db.update(db.habits)..where((t) => t.id.equals(id)))
        .write(HabitsCompanion(
      active: const Value(false),
      deactivatedAt: Value(DateTime.now()),
    ));

/// Tombstone (D-10): history rows stay for stats integrity.
Future<void> tombstoneHabit(AppDb db, String id) =>
    (db.update(db.habits)..where((t) => t.id.equals(id)))
        .write(HabitsCompanion(
      active: const Value(false),
      deletedAt: Value(DateTime.now()),
    ));

// ---------------------------------------------------------------- app state

Future<String?> getAppState(AppDb db, String key) async {
  final row = await (db.select(db.appState)
        ..where((t) => t.key.equals(key)))
      .getSingleOrNull();
  return row?.value;
}

Future<void> setAppState(AppDb db, String key, String value) => db
    .into(db.appState)
    .insertOnConflictUpdate(AppStateCompanion.insert(key: key, value: value));

Future<bool> isPaused(AppDb db) async =>
    await getAppState(db, 'pause_all') == '1';
Future<bool> primingDone(AppDb db) async =>
    await getAppState(db, 'priming_done') == '1';

Future<void> ensureProgramStart(AppDb db) async {
  if (await getAppState(db, 'program_start_date') == null) {
    await setAppState(db, 'program_start_date', localDateOf(DateTime.now()));
  }
}

// ---------------------------------------------------------------- responses

/// Records a user response. First terminal write for an instance wins (P-5).
///
/// Payloads from iOS daily-REPEATING triggers are prefixed 'R|' by the
/// notifier: their embedded date is the trigger's anchor occurrence, not the
/// day the notification actually fired, so the response is remapped to today.
/// One-shot payloads (all Android, iOS interval/rest-day habits) carry the
/// correct date and are never remapped.
Future<void> recordResponseByKey(
  AppDb db,
  String payload,
  String state, // 'done' | 'not_done'
  String source, // 'notification' | 'app'
) async {
  final repeating = payload.startsWith('R|');
  final key = repeating ? payload.substring(2) : payload;
  final parsed = parseInstanceKey(key);
  if (parsed == null) return;
  var localDate = parsed.localDate;
  if (repeating) {
    final today = localDateOf(DateTime.now());
    if (localDate != today) localDate = today;
  }
  final id = instanceKey(parsed.habitId, localDate, parsed.minuteOfDay);
  await db.into(db.triggerLogs).insert(
        TriggerLogsCompanion.insert(
          id: id,
          habitId: parsed.habitId,
          localDate: localDate,
          scheduledHhmm: parsed.minuteOfDay,
          state: state,
          respondedAt: Value(DateTime.now()),
          responseSource: Value(source),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  // D-11 (owner correction, 18 Aug): a response delivered from a NOTIFICATION
  // is ground truth and outranks the system's 'missed' inference — if the
  // notification was still visible, acting on it counts, even past the
  // deadline. Only auto-'missed' is overwritten; done / not_done / excused
  // stay immutable (P-5), and app-sourced responses stay deadline-bound.
  if (source == 'notification') {
    await (db.update(db.triggerLogs)
          ..where((t) => t.id.equals(id) & t.state.equals('missed')))
        .write(TriggerLogsCompanion(
      state: Value(state),
      respondedAt: Value(DateTime.now()),
      responseSource: const Value('notification'),
    ));
  }
}

Future<List<TriggerLog>> logsOn(AppDb db, String localDate) =>
    (db.select(db.triggerLogs)..where((t) => t.localDate.equals(localDate)))
        .get();

Stream<List<TriggerLog>> watchLogsOn(AppDb db, String localDate) =>
    (db.select(db.triggerLogs)..where((t) => t.localDate.equals(localDate)))
        .watch();

/// Logs with localDate >= [sinceDate] ('YYYY-MM-DD' sorts lexicographically).
Stream<List<TriggerLog>> watchLogsSince(AppDb db, String sinceDate) =>
    (db.select(db.triggerLogs)
          ..where((t) => t.localDate.isBiggerOrEqualValue(sinceDate)))
        .watch();

Future<Habit?> habitRowById(AppDb db, String id) =>
    (db.select(db.habits)..where((t) => t.id.equals(id))).getSingleOrNull();

// ---------------------------------------------------------------- reconcile

/// True when the instance predates the habit's creation moment on its creation
/// day — those instances never existed for the user and must not count as
/// expected or missed (a habit created at 18:37 owes nothing for 08:00–18:00).
bool precedesCreation(DateTime createdAt, PlannedInstance plan) {
  if (plan.localDate != localDateOf(createdAt)) return false;
  return plan.minuteOfDay < createdAt.hour * 60 + createdAt.minute;
}

/// Applies the missed/excused rules for instances whose deadline has passed
/// with no response (PRD §8.4). Looks back 2 days. Idempotent: insertOrIgnore
/// against existing terminal rows.
///
/// While Pause All is active, unanswered instances become `excused` rather
/// than `missed` (coarse v0.2 semantics; refined with the Streaks block).
Future<void> reconcile(AppDb db, tz.Location loc) async {
  final rows = await activeHabitRows(db);
  final paused = await isPaused(db);
  final now = tz.TZDateTime.now(loc);
  final lateState = paused ? 'excused' : 'missed';

  for (var dayOffset = -1; dayOffset <= 0; dayOffset++) {
    final date = DateTime(now.year, now.month, now.day + dayOffset);
    final dateStr = localDateOf(date);
    final existing = (await logsOn(db, dateStr)).map((l) => l.id).toSet();

    for (final row in rows) {
      final spec = specFromRow(row);
      for (final plan in planDay(spec, date)) {
        if (precedesCreation(row.createdAt, plan)) continue;
        final key = instanceKey(spec.id, plan.localDate, plan.minuteOfDay);
        if (existing.contains(key)) continue;

        // DST gap: the instance never materializes -> excused.
        final at = materialize(loc, plan);
        if (at == null) {
          await _insertTerminal(db, spec.id, plan, 'excused');
          continue;
        }

        final deadline = tz.TZDateTime(loc, plan.year, plan.month, plan.day,
            plan.deadlineMinuteOfDay ~/ 60, plan.deadlineMinuteOfDay % 60);
        if (now.isAfter(deadline)) {
          await _insertTerminal(db, spec.id, plan, lateState);
        }
      }
    }
  }
}

Future<void> _insertTerminal(
        AppDb db, String habitId, PlannedInstance plan, String state) =>
    db.into(db.triggerLogs).insert(
          TriggerLogsCompanion.insert(
            id: instanceKey(habitId, plan.localDate, plan.minuteOfDay),
            habitId: habitId,
            localDate: plan.localDate,
            scheduledHhmm: plan.minuteOfDay,
            state: state,
          ),
          mode: InsertMode.insertOrIgnore,
        );

// ---------------------------------------------------------------- today view

class TodayHabitView {
  final Habit row;
  final HabitSpec spec;
  final int doneToday;
  final int expectedSoFar;

  /// Instance currently awaiting a response (fired, before deadline, unlogged).
  final PlannedInstance? openInstance;

  /// Next instance later today, if any (for the "Next at HH:MM" hint).
  final PlannedInstance? nextToday;

  const TodayHabitView({
    required this.row,
    required this.spec,
    required this.doneToday,
    required this.expectedSoFar,
    required this.openInstance,
    required this.nextToday,
  });
}

TodayHabitView buildTodayView(
    Habit row, List<TriggerLog> todayLogs, tz.Location loc) {
  final spec = specFromRow(row);
  final now = tz.TZDateTime.now(loc);
  final nowMin = now.hour * 60 + now.minute;
  final plans = planDay(spec, DateTime(now.year, now.month, now.day));
  final logsById = {
    for (final l in todayLogs.where((l) => l.habitId == spec.id)) l.id: l
  };

  var done = 0;
  var expectedSoFar = 0;
  PlannedInstance? open;
  PlannedInstance? next;

  for (final p in plans) {
    if (precedesCreation(row.createdAt, p)) continue;
    final key = instanceKey(spec.id, p.localDate, p.minuteOfDay);
    final log = logsById[key];
    if (log?.state == 'done') done++;
    if (p.minuteOfDay <= nowMin) {
      if (log?.state != 'excused') expectedSoFar++;
      if (log == null && nowMin < p.deadlineMinuteOfDay) open = p;
    } else {
      next ??= p;
    }
  }

  return TodayHabitView(
    row: row,
    spec: spec,
    doneToday: done,
    expectedSoFar: expectedSoFar,
    openInstance: open,
    nextToday: next,
  );
}
