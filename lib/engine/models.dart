// Engine models — pure Dart, zero Flutter imports (PRD §8).
// The engine is deterministic: same inputs -> same planned instances.

/// Frequency unit of a habit (PRD §7.2 / DD-1).
enum FreqUnit { minutes, hours, daily }

/// Immutable habit definition as the engine sees it (subset of the DB row).
class HabitSpec {
  final String id;
  final String directive; // <= 80 chars (enforced at UI/db layer)
  final FreqUnit unit;

  /// Interval quantity; null iff [unit] == FreqUnit.daily.
  final int? intervalQty;

  /// Operational window, minutes from local midnight. End is inclusive (PRD §8.1).
  final int windowStartMin;
  final int windowEndMin;

  /// Optional weekly rest day (F-14 / GtG 6-on-1-off).
  /// Uses Dart's DateTime convention: 1 = Monday … 7 = Sunday. Null = none.
  final int? restDay;

  const HabitSpec({
    required this.id,
    required this.directive,
    required this.unit,
    this.intervalQty,
    required this.windowStartMin,
    required this.windowEndMin,
    this.restDay,
  });

  /// Interval in minutes; throws for daily (which has no interval).
  int get intervalMinutes => switch (unit) {
        FreqUnit.minutes => intervalQty!,
        FreqUnit.hours => intervalQty! * 60,
        FreqUnit.daily =>
          throw StateError('daily habits have no interval'),
      };
}

/// A single planned trigger occurrence on a specific local date (PRD §8.1).
/// Wall-clock only — timezone materialization happens in materialize.dart.
class PlannedInstance {
  final String habitId;
  final int year;
  final int month;
  final int day;

  /// Scheduled time, minutes from local midnight.
  final int minuteOfDay;

  /// Response deadline, minutes from local midnight, capped at 23:59 (1439).
  /// Past this with no response => MISSED (PRD §8.4).
  final int deadlineMinuteOfDay;

  const PlannedInstance({
    required this.habitId,
    required this.year,
    required this.month,
    required this.day,
    required this.minuteOfDay,
    required this.deadlineMinuteOfDay,
  });

  /// 'YYYY-MM-DD' key, matches trigger_logs.local_date (PRD §9).
  String get localDate =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Dedupe key for DST fall-back duplicates (PRD §8.3).
  String get dedupeKey => '$habitId|$localDate|$minuteOfDay';

  @override
  String toString() => 'PlannedInstance($habitId $localDate '
      '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:${(minuteOfDay % 60).toString().padLeft(2, '0')} '
      'deadline=$deadlineMinuteOfDay)';
}

/// Terminal minute of a local day.
const int kEndOfDayMinute = 1439; // 23:59
