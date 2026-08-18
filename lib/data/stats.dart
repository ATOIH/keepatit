// Streak & consistency derivations (PRD §7.3). Everything here is computed on
// read — never stored. The pure functions at the top are unit-tested; the
// thin builders below glue them to rows/logs already loaded from drift.
import 'package:timezone/timezone.dart' as tz;

import '../engine/instance_generator.dart';
import '../engine/models.dart';
import 'db.dart';
import 'repository.dart';

/// PRD constants.
const int kProgramDays = 90; // OC-1: 90-DAY NEURAL REWIRE GOAL
const double kMaintainThreshold = 0.80;

// ---------------------------------------------------------------- pure rules

/// Heatmap bucket from a day's completion ratio (demo opacity tiers):
/// null = no expectation that day (pre-existence / rest day / all excused);
/// 0.0 = expected but nothing done; 0.2 / 0.5 / 1.0 = crimson intensities.
double? heatBucket(int done, int expected) {
  if (expected <= 0) return null;
  final r = done / expected;
  if (r >= 1) return 1.0;
  if (r >= 0.5) return 0.5;
  if (r > 0) return 0.2;
  return 0.0;
}

/// Day counter for the global program: 'Day {n} / 90', auto-recycling (D-6).
/// [startDate]/[today] are 'YYYY-MM-DD' local-date strings.
int programDayOf(String startDate, String today) {
  final s = DateTime.parse(startDate);
  final t = DateTime.parse(today);
  final diff = t.difference(s).inDays;
  if (diff <= 0) return 1;
  return (diff % kProgramDays) + 1;
}

/// Consistency = Σdone / Σexpected over (done, expected) day-pairs.
/// Returns null when nothing was expected at all (fresh install).
double? consistencyOf(Iterable<({int done, int expected})> pairs) {
  var d = 0, e = 0;
  for (final p in pairs) {
    d += p.done;
    e += p.expected;
  }
  if (e == 0) return null;
  return d / e;
}

/// Timeline chip label for an instance state (PRD §7.3 / demo copy).
String timelineLabel(String? logState, {required bool isFuture}) {
  if (logState == 'done') return 'DONE';
  if (logState == 'not_done') return 'NOT DONE';
  if (logState == 'missed') return 'MISSED';
  if (logState == 'excused') return 'EXCUSED';
  return isFuture ? 'PENDING' : 'PENDING'; // open (awaiting) renders as pending
}

// ---------------------------------------------------------------- day stats

/// (done, expected) for one habit on one date, honoring creation-day gating
/// and excused exclusions. For [today], expectation counts only instances
/// whose time has already arrived ("today-so-far", PRD §7.3).
({int done, int expected}) dayPair({
  required Habit row,
  required HabitSpec spec,
  required DateTime date,
  required Map<String, TriggerLog> logsById,
  int? nowMinuteForToday,
}) {
  var done = 0, expected = 0;
  for (final p in planDay(spec, date)) {
    if (precedesCreation(row.createdAt, p)) continue;
    if (nowMinuteForToday != null && p.minuteOfDay > nowMinuteForToday) {
      continue;
    }
    final log = logsById[instanceKey(spec.id, p.localDate, p.minuteOfDay)];
    if (log?.state == 'excused') continue;
    expected++;
    if (log?.state == 'done') done++;
  }
  return (done: done, expected: expected);
}

// ---------------------------------------------------------------- aggregates

class HabitHeat {
  final Habit row;
  final HabitSpec spec;

  /// Trailing 7 days, oldest first: heatBucket per day.
  final List<double?> last7;

  /// Trailing [kProgramDays]+1 days (91 = 13 weeks × 7), oldest first.
  final List<double?> last91;

  const HabitHeat(
      {required this.row,
      required this.spec,
      required this.last7,
      required this.last91});
}

class TimelineEntry {
  final HabitSpec spec;
  final int minuteOfDay;
  final String label; // DONE / NOT DONE / MISSED / EXCUSED / PENDING
  final bool isFuture;
  const TimelineEntry(
      {required this.spec,
      required this.minuteOfDay,
      required this.label,
      required this.isFuture});
}

class StreaksData {
  final int? consistencyPct; // null = nothing expected yet
  final bool maintained; // >= 80%
  final int programDay;
  final List<HabitHeat> heat;
  final List<TimelineEntry> timeline;
  const StreaksData(
      {required this.consistencyPct,
      required this.maintained,
      required this.programDay,
      required this.heat,
      required this.timeline});
}

StreaksData buildStreaks({
  required List<Habit> rows,
  required List<TriggerLog> logs, // trailing window, any order
  required String programStartDate,
  required tz.Location loc,
}) {
  final now = tz.TZDateTime.now(loc);
  final nowMin = now.hour * 60 + now.minute;
  final todayDate = DateTime(now.year, now.month, now.day);
  final logsById = {for (final l in logs) l.id: l};

  // Consistency: trailing 7 full days + today-so-far (PRD §7.3).
  final pairs = <({int done, int expected})>[];
  for (final row in rows) {
    final spec = specFromRow(row);
    for (var off = -7; off <= 0; off++) {
      final date =
          DateTime(todayDate.year, todayDate.month, todayDate.day + off);
      pairs.add(dayPair(
        row: row,
        spec: spec,
        date: date,
        logsById: logsById,
        nowMinuteForToday: off == 0 ? nowMin : null,
      ));
    }
  }
  final ratio = consistencyOf(pairs);
  final pct = ratio == null ? null : (ratio * 100).round();

  // Heatmaps.
  List<double?> series(Habit row, HabitSpec spec, int days) => [
        for (var off = -(days - 1); off <= 0; off++)
          () {
            final date = DateTime(
                todayDate.year, todayDate.month, todayDate.day + off);
            final p = dayPair(
              row: row,
              spec: spec,
              date: date,
              logsById: logsById,
              nowMinuteForToday: off == 0 ? nowMin : null,
            );
            return heatBucket(p.done, p.expected);
          }(),
      ];

  final heat = [
    for (final row in rows)
      HabitHeat(
        row: row,
        spec: specFromRow(row),
        last7: series(row, specFromRow(row), 7),
        last91: series(row, specFromRow(row), 91),
      ),
  ];

  // Today's Triggers timeline, chronological across habits.
  final timeline = <TimelineEntry>[];
  for (final row in rows) {
    final spec = specFromRow(row);
    for (final p in planDay(spec, todayDate)) {
      if (precedesCreation(row.createdAt, p)) continue;
      final log = logsById[instanceKey(spec.id, p.localDate, p.minuteOfDay)];
      final isFuture = p.minuteOfDay > nowMin;
      timeline.add(TimelineEntry(
        spec: spec,
        minuteOfDay: p.minuteOfDay,
        label: timelineLabel(log?.state, isFuture: isFuture),
        isFuture: isFuture,
      ));
    }
  }
  timeline.sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));

  return StreaksData(
    consistencyPct: pct,
    maintained: ratio != null && ratio >= kMaintainThreshold,
    programDay: programDayOf(programStartDate, localDateOf(todayDate)),
    heat: heat,
    timeline: timeline,
  );
}
