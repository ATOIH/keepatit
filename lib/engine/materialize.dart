// Wall-clock -> real timezone-aware instant (PRD §8.3).
//
// Rules:
//  * All scheduling is local wall-clock.
//  * DST spring-forward: a wall time that does not exist that day => null (instance EXCUSED).
//  * DST fall-back: a wall time that occurs twice materializes ONCE (first occurrence);
//    generation produces one instance per (habit, date, HH:mm) so duplicates cannot arise.
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Returns the real instant for [p] in [loc], or null when the wall-clock
/// time does not exist on that date (DST gap) — the caller marks it excused.
tz.TZDateTime? materialize(tz.Location loc, PlannedInstance p) {
  final hour = p.minuteOfDay ~/ 60;
  final minute = p.minuteOfDay % 60;
  final t = tz.TZDateTime(loc, p.year, p.month, p.day, hour, minute);
  // TZDateTime normalizes nonexistent wall times forward; detect the shift.
  final roundTrip = t.hour * 60 + t.minute;
  final sameDate = t.year == p.year && t.month == p.month && t.day == p.day;
  if (!sameDate || roundTrip != p.minuteOfDay) {
    return null; // DST gap -> excused (PRD §8.4)
  }
  return t;
}

/// Materializes a batch, dropping DST-gap instances and deduplicating on
/// (habit, date, HH:mm) — the fall-back rule. Returns future instants only
/// if [after] is provided.
List<({PlannedInstance plan, tz.TZDateTime at})> materializeAll(
  tz.Location loc,
  Iterable<PlannedInstance> plans, {
  tz.TZDateTime? after,
}) {
  final seen = <String>{};
  final out = <({PlannedInstance plan, tz.TZDateTime at})>[];
  for (final p in plans) {
    if (!seen.add(p.dedupeKey)) continue;
    final at = materialize(loc, p);
    if (at == null) continue;
    if (after != null && !at.isAfter(after)) continue;
    out.add((plan: p, at: at));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
