// Trigger budget validation — PRD §7.2 / §8.2.
// iOS caps pending local notifications at 64; the engine budgets 60/day across
// all active habits, guaranteeing >= ~24h of unattended coverage.
import 'instance_generator.dart';
import 'models.dart';

const int kDailyTriggerBudget = 60;
const int kMinIntervalMinutes = 20;
const int kMaxIntervalMinutes = 12 * 60;
const int kMaxActiveHabits = 8;
const int kDirectiveMaxChars = 80;

/// Exact user-facing copy (PRD §7.2) — do not reword casually.
const String kBudgetExceededMessage =
    'This schedule exceeds the daily trigger budget (60 across all habits). '
    'Widen the interval or shorten the window.';

class ValidationResult {
  final bool ok;
  final String? message;
  final int totalPerDay; // across existing actives + candidate (worst day)
  const ValidationResult._(this.ok, this.message, this.totalPerDay);

  static ValidationResult pass(int total) =>
      ValidationResult._(true, null, total);
  static ValidationResult fail(String msg, int total) =>
      ValidationResult._(false, msg, total);
}

/// Validates [candidate] against field rules and the global daily budget,
/// given the currently active [existing] habits. Order of checks is stable
/// so error messages are deterministic.
ValidationResult validateHabit(
    List<HabitSpec> existing, HabitSpec candidate) {
  final existingTotal = existing.fold<int>(
      0, (sum, s) => sum + instancesPerActiveDay(s));

  // 1. Directive present and bounded.
  final directive = candidate.directive.trim();
  if (directive.isEmpty) {
    return ValidationResult.fail(
        'Give the habit a directive.', existingTotal);
  }
  if (directive.length > kDirectiveMaxChars) {
    return ValidationResult.fail(
        'Keep the directive under $kDirectiveMaxChars characters.',
        existingTotal);
  }

  // 2. Window sanity: same-day, end after start (PRD §7.2; overnight windows are P2).
  if (candidate.windowStartMin < 0 ||
      candidate.windowEndMin > kEndOfDayMinute ||
      candidate.windowEndMin <= candidate.windowStartMin) {
    return ValidationResult.fail(
        'The window must end after it starts (same day).', existingTotal);
  }

  // 3. Interval bounds (interval habits only).
  if (candidate.unit != FreqUnit.daily) {
    final qty = candidate.intervalQty;
    if (qty == null || qty <= 0) {
      return ValidationResult.fail('Set an interval.', existingTotal);
    }
    final minutes = candidate.intervalMinutes;
    if (minutes < kMinIntervalMinutes) {
      return ValidationResult.fail(
          'Minimum interval is $kMinIntervalMinutes minutes.', existingTotal);
    }
    if (minutes > kMaxIntervalMinutes) {
      return ValidationResult.fail(
          'Maximum interval is 12 hours.', existingTotal);
    }
  }

  // 4. Active-habit cap.
  if (existing.length >= kMaxActiveHabits) {
    return ValidationResult.fail(
        'Keep At It supports up to $kMaxActiveHabits active habits.',
        existingTotal);
  }

  // 5. Global daily trigger budget (the iOS 64-cap guarantee).
  final total = existingTotal + instancesPerActiveDay(candidate);
  if (total > kDailyTriggerBudget) {
    return ValidationResult.fail(kBudgetExceededMessage, total);
  }

  return ValidationResult.pass(total);
}
