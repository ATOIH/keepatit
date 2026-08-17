// Engine test suite — trigger budget & field validation (PRD §7.2).
import 'package:flutter_test/flutter_test.dart';
import 'package:keepatit/engine/budget.dart';
import 'package:keepatit/engine/models.dart';

HabitSpec spec({
  String id = 'h',
  String directive = 'test',
  FreqUnit unit = FreqUnit.hours,
  int? qty,
  required int start,
  required int end,
}) =>
    HabitSpec(
      id: id,
      directive: directive,
      unit: unit,
      intervalQty: qty,
      windowStartMin: start,
      windowEndMin: end,
    );

/// The PRD Appendix C demo set: 46 instances/day.
List<HabitSpec> demoSet() => [
      spec(id: 'water', qty: 2, start: 480, end: 1320), // 8
      spec(id: 'posture', qty: 1, start: 540, end: 1020), // 9
      spec(id: 'review', unit: FreqUnit.daily, start: 480, end: 540), // 1
      spec(
          id: 'screen',
          unit: FreqUnit.minutes,
          qty: 20,
          start: 540,
          end: 1080), // 28
    ];

void main() {
  group('daily trigger budget (guards the iOS 64-notification cap)', () {
    test('demo set + 14/day candidate = exactly 60 => allowed', () {
      // hourly 09:00–22:00 => 14 instances
      final r = validateHabit(
          demoSet(), spec(id: 'new', qty: 1, start: 540, end: 1320));
      expect(r.ok, isTrue);
      expect(r.totalPerDay, 60);
    });

    test('61st instance is rejected with the exact PRD copy', () {
      // hourly 09:00–23:00 => 15 instances => 61 total
      final r = validateHabit(
          demoSet(), spec(id: 'new', qty: 1, start: 540, end: 1380));
      expect(r.ok, isFalse);
      expect(r.totalPerDay, 61);
      expect(r.message, kBudgetExceededMessage);
    });
  });

  group('field validation', () {
    test('interval below 20 minutes rejected', () {
      final r = validateHabit(const [],
          spec(unit: FreqUnit.minutes, qty: 19, start: 540, end: 1080));
      expect(r.ok, isFalse);
      expect(r.message, contains('Minimum interval'));
    });

    test('interval above 12 hours rejected', () {
      final r = validateHabit(
          const [], spec(unit: FreqUnit.hours, qty: 13, start: 0, end: 1320));
      expect(r.ok, isFalse);
      expect(r.message, contains('12 hours'));
    });

    test('window must end after it starts', () {
      final r =
          validateHabit(const [], spec(qty: 1, start: 1020, end: 540));
      expect(r.ok, isFalse);
      expect(r.message, contains('end after it starts'));
    });

    test('empty directive rejected', () {
      final r = validateHabit(
          const [], spec(directive: '   ', qty: 1, start: 540, end: 1020));
      expect(r.ok, isFalse);
    });

    test('directive over 80 chars rejected', () {
      final r = validateHabit(const [],
          spec(directive: 'x' * 81, qty: 1, start: 540, end: 1020));
      expect(r.ok, isFalse);
    });

    test('9th active habit rejected (cap 8)', () {
      final eight = List.generate(
          8, (i) => spec(id: 'h$i', unit: FreqUnit.daily, start: 480, end: 540));
      final r = validateHabit(
          eight, spec(id: 'ninth', unit: FreqUnit.daily, start: 600, end: 660));
      expect(r.ok, isFalse);
      expect(r.message, contains('8 active habits'));
    });

    test('a valid daily habit passes with total 1', () {
      final r = validateHabit(
          const [], spec(unit: FreqUnit.daily, start: 480, end: 540));
      expect(r.ok, isTrue);
      expect(r.totalPerDay, 1);
    });
  });
}
