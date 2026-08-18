// Schedule selection — decides exactly which future instances get OS slots.
// Pure engine logic (PRD §8.2). Zero Flutter imports; fully unit-tested.
//
// Android: schedule every instance in the next [kAndroidHorizonHours], capped at
//   [kAndroidMaxPending] (AOSP allows 500 alarms/app; we stay far under).
// iOS: daily habits become ONE repeating slot each (UNCalendarNotificationTrigger
//   repeats forever ≈ free); interval habits fill individual slots chronologically
//   until [kIosSlotBudget] (OS cap is 64 pending; we budget 60).
import 'package:timezone/timezone.dart' as tz;

import 'instance_generator.dart';
import 'materialize.dart';
import 'models.dart';

const int kIosSlotBudget = 60;
const int kAndroidMaxPending = 128;
const int kAndroidHorizonHours = 48;
const int kPlanDaysAhead = 3; // covers a 48h horizon from any time of day

/// One thing to hand to the notification plugin.
class ScheduleTarget {
  final PlannedInstance plan;
  final tz.TZDateTime at;

  /// iOS only: schedule as a daily-repeating trigger (matchDateTimeComponents.time)
  /// instead of a one-shot — consumes one permanent slot.
  final bool repeatingDaily;

  const ScheduleTarget(
      {required this.plan, required this.at, this.repeatingDaily = false});
}

/// Selects the concrete schedule for [specs] as of [now] in [loc].
/// [iosBudgetMode] = true applies the iOS 60-slot strategy; false = Android.
/// Deterministic: same inputs -> same output order.
List<ScheduleTarget> selectSchedule({
  required List<HabitSpec> specs,
  required tz.Location loc,
  required tz.TZDateTime now,
  required bool iosBudgetMode,
}) {
  final startDate = DateTime(now.year, now.month, now.day);

  // A repeating iOS trigger fires unconditionally every day, so it can only be
  // used for daily habits WITHOUT a rest day (F-14) — otherwise it would fire
  // on the rest day. Daily habits with a rest day are scheduled as one-shots.
  final dailyRepeating = specs
      .where((s) => s.unit == FreqUnit.daily && s.restDay == null)
      .toList();
  final oneShotSpecs = specs
      .where((s) => s.unit != FreqUnit.daily || s.restDay != null)
      .toList();

  if (iosBudgetMode) {
    final out = <ScheduleTarget>[];

    // Rest-day-free daily habits: one repeating slot anchored at the NEXT occurrence.
    for (final s in dailyRepeating) {
      final plans = planRange([s], startDate, 2);
      final mat = materializeAll(loc, plans, after: now);
      if (mat.isNotEmpty) {
        out.add(ScheduleTarget(
            plan: mat.first.plan, at: mat.first.at, repeatingDaily: true));
      }
    }

    // Everything else: chronological one-shot fill up to the remaining budget.
    final budget = kIosSlotBudget - out.length;
    final plans = planRange(oneShotSpecs, startDate, kPlanDaysAhead);
    final mat = materializeAll(loc, plans, after: now);
    out.addAll(mat
        .take(budget < 0 ? 0 : budget)
        .map((e) => ScheduleTarget(plan: e.plan, at: e.at)));
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  // Android: everything inside the horizon, capped.
  final horizonEnd = now.add(const Duration(hours: kAndroidHorizonHours));
  final plans = planRange(specs, startDate, kPlanDaysAhead);
  final mat = materializeAll(loc, plans, after: now);
  return mat
      .where((e) => !e.at.isAfter(horizonEnd))
      .take(kAndroidMaxPending)
      .map((e) => ScheduleTarget(plan: e.plan, at: e.at))
      .toList();
}

/// Stable 31-bit notification id for an instance (or a habit's repeating slot).
/// FNV-1a over the key; masked positive for platform int requirements.
int notificationIdFor(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
