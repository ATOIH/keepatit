// Notification content — PRD §7.5 templates, normative and unit-tested.
// Pure Dart: no plugin imports here.
import '../engine/models.dart';

const int kTitleDirectiveChars = 30;

/// 'Keep At It: {directive, truncated 30 chars}'
String notificationTitle(HabitSpec spec) =>
    'Keep At It: ${truncateDirective(spec.directive)}';

/// Body templates (Appendix B, mirrored from PRD §7.5):
///   daily    -> 'Time to focus. {X} remaining.'
///   interval -> '{directive-short}. {X} remaining in today's window.'
/// where {X} = time until the habit's window end at the moment of firing.
String notificationBody(HabitSpec spec, int firedAtMinuteOfDay) {
  final remaining = spec.windowEndMin - firedAtMinuteOfDay;
  final x = formatRemaining(remaining);
  if (spec.unit == FreqUnit.daily) {
    return 'Time to focus. $x remaining.';
  }
  return "${truncateDirective(spec.directive)}. $x remaining in today's window.";
}

String truncateDirective(String directive) {
  final d = directive.trim();
  if (d.length <= kTitleDirectiveChars) return d;
  return '${d.substring(0, kTitleDirectiveChars - 1)}…';
}

/// '90 minutes' below 2 hours; '2 hours' / '2.5 hours' from 2 hours up.
/// Floors at '1 minute'.
String formatRemaining(int minutes) {
  final m = minutes < 1 ? 1 : minutes;
  if (m < 120) return m == 1 ? '1 minute' : '$m minutes';
  if (m % 60 == 0) {
    final h = m ~/ 60;
    return '$h hours';
  }
  final h = m / 60.0;
  final oneDecimal = (h * 10).round() / 10;
  final text = oneDecimal == oneDecimal.roundToDouble()
      ? oneDecimal.toInt().toString()
      : oneDecimal.toStringAsFixed(1);
  return '$text hours';
}

/// Frequency chip grammar (Appendix B): used by UI, kept beside the other copy.
String frequencyChip(HabitSpec spec) => switch (spec.unit) {
      FreqUnit.daily => 'Once a day',
      FreqUnit.minutes => 'Every ${spec.intervalQty} mins',
      FreqUnit.hours => spec.intervalQty == 1
          ? 'Every 1 hour'
          : 'Every ${spec.intervalQty} hours',
    };

/// '08:00 - 22:00' window chip.
String windowChip(HabitSpec spec) =>
    '${formatMinute(spec.windowStartMin)} - ${formatMinute(spec.windowEndMin)}';

String formatMinute(int minuteOfDay) {
  final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
  final m = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
