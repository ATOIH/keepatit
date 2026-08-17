// Instance generation — PRD §8.1. Pure functions of (habit, date).
//
// Rules (normative):
//  * Interval habits: times = start, start+i, start+2i, … <= end  (END-INCLUSIVE:
//    "every 2 hours, 08:00–22:00" => 08,10,12,14,16,18,20,22 = 8/day).
//  * Daily habits: one instance at window start; the window is the deadline.
//  * Response deadline per interval instance = min(next instance, windowEnd + interval, 23:59).
//  * Rest day (F-14): no instances generated on the habit's rest weekday.
import 'models.dart';

/// Plans all instances for [spec] on the local calendar date [date].
/// Returns instances in ascending time order. Empty on the rest day.
List<PlannedInstance> planDay(HabitSpec spec, DateTime date) {
  if (spec.restDay != null && date.weekday == spec.restDay) {
    return const [];
  }

  if (spec.unit == FreqUnit.daily) {
    return [
      PlannedInstance(
        habitId: spec.id,
        year: date.year,
        month: date.month,
        day: date.day,
        minuteOfDay: spec.windowStartMin,
        deadlineMinuteOfDay: spec.windowEndMin,
      ),
    ];
  }

  final i = spec.intervalMinutes;
  final times = <int>[];
  for (var t = spec.windowStartMin; t <= spec.windowEndMin; t += i) {
    times.add(t);
  }

  return [
    for (var k = 0; k < times.length; k++)
      PlannedInstance(
        habitId: spec.id,
        year: date.year,
        month: date.month,
        day: date.day,
        minuteOfDay: times[k],
        deadlineMinuteOfDay: k + 1 < times.length
            ? times[k + 1]
            : _min(spec.windowEndMin + i, kEndOfDayMinute),
      ),
  ];
}

/// Plans instances for [days] consecutive dates starting at [from] (date part only),
/// across all [specs], sorted chronologically then by habit id for determinism.
List<PlannedInstance> planRange(
    List<HabitSpec> specs, DateTime from, int days) {
  final out = <PlannedInstance>[];
  for (var d = 0; d < days; d++) {
    final date = DateTime(from.year, from.month, from.day + d);
    for (final spec in specs) {
      out.addAll(planDay(spec, date));
    }
  }
  out.sort((a, b) {
    final byDate = a.localDate.compareTo(b.localDate);
    if (byDate != 0) return byDate;
    final byTime = a.minuteOfDay.compareTo(b.minuteOfDay);
    if (byTime != 0) return byTime;
    return a.habitId.compareTo(b.habitId);
  });
  return out;
}

/// Instances per day for [spec] on a non-rest day (used by the budget validator).
int instancesPerActiveDay(HabitSpec spec) {
  if (spec.unit == FreqUnit.daily) return 1;
  return ((spec.windowEndMin - spec.windowStartMin) ~/ spec.intervalMinutes) + 1;
}

int _min(int a, int b) => a < b ? a : b;
