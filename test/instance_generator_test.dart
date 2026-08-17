// Engine test suite — instance generation (PRD §8.1, Appendix C).
import 'package:flutter_test/flutter_test.dart';
import 'package:keepatit/engine/instance_generator.dart';
import 'package:keepatit/engine/models.dart';

HabitSpec spec({
  String id = 'h',
  FreqUnit unit = FreqUnit.hours,
  int? qty,
  required int start,
  required int end,
  int? restDay,
}) =>
    HabitSpec(
      id: id,
      directive: 'test',
      unit: unit,
      intervalQty: qty,
      windowStartMin: start,
      windowEndMin: end,
      restDay: restDay,
    );

void main() {
  final monday = DateTime(2026, 8, 17); // Monday
  final sunday = DateTime(2026, 8, 23); // Sunday

  group('interval habits — end-inclusive (PRD Appendix C)', () {
    test('every 2 hours, 08:00–22:00 => 8 instances', () {
      final water = spec(qty: 2, start: 8 * 60, end: 22 * 60);
      final plan = planDay(water, monday);
      expect(plan.map((p) => p.minuteOfDay).toList(),
          [480, 600, 720, 840, 960, 1080, 1200, 1320]);
    });

    test('every 1 hour, 09:00–17:00 => 9 instances', () {
      expect(planDay(spec(qty: 1, start: 540, end: 1020), monday).length, 9);
    });

    test('every 20 mins, 09:00–18:00 => 28 instances', () {
      final screen =
          spec(unit: FreqUnit.minutes, qty: 20, start: 540, end: 1080);
      expect(planDay(screen, monday).length, 28);
    });

    test('demo habit set totals 46/day (PRD Appendix C)', () {
      final total = [
        spec(id: 'water', qty: 2, start: 480, end: 1320),
        spec(id: 'posture', qty: 1, start: 540, end: 1020),
        spec(id: 'review', unit: FreqUnit.daily, start: 480, end: 540),
        spec(id: 'screen', unit: FreqUnit.minutes, qty: 20, start: 540, end: 1080),
      ].fold<int>(0, (s, h) => s + planDay(h, monday).length);
      expect(total, 46);
    });
  });

  group('deadlines (PRD §8.1)', () {
    test('interval deadline = next instance; last = min(end+i, 23:59)', () {
      final water = spec(qty: 2, start: 480, end: 1320);
      final plan = planDay(water, monday);
      expect(plan.first.deadlineMinuteOfDay, 600); // next instance
      expect(plan.last.deadlineMinuteOfDay, 1439); // 1320+120 capped at 23:59
    });

    test('last deadline uses end+interval when it fits the day', () {
      final screen =
          spec(unit: FreqUnit.minutes, qty: 20, start: 540, end: 1080);
      expect(planDay(screen, monday).last.deadlineMinuteOfDay, 1100);
    });

    test('daily habit: fires at window start, deadline = window end (D-4)', () {
      final review = spec(unit: FreqUnit.daily, start: 480, end: 540);
      final plan = planDay(review, monday);
      expect(plan.single.minuteOfDay, 480);
      expect(plan.single.deadlineMinuteOfDay, 540);
    });
  });

  group('rest day — F-14 / Grease the Groove', () {
    final pushups = spec(
        id: 'gtg',
        unit: FreqUnit.hours,
        qty: 1,
        start: 480,
        end: 1320,
        restDay: DateTime.sunday);

    test('no instances on the rest day', () {
      expect(planDay(pushups, sunday), isEmpty);
    });

    test('normal generation on other days', () {
      expect(planDay(pushups, monday).length, 15);
    });

    test('planRange over a week skips exactly the rest day', () {
      final week = planRange([pushups], monday, 7);
      expect(week.length, 15 * 6);
      expect(week.any((p) => p.localDate == '2026-08-23'), isFalse);
    });
  });

  group('determinism & ordering', () {
    test('same inputs produce identical plans', () {
      final s = spec(qty: 2, start: 480, end: 1320);
      final a = planDay(s, monday).map((p) => p.toString()).join();
      final b = planDay(s, monday).map((p) => p.toString()).join();
      expect(a, b);
    });

    test('planRange sorts chronologically then by habit id', () {
      final plans = planRange([
        spec(id: 'b', qty: 2, start: 480, end: 600),
        spec(id: 'a', qty: 2, start: 480, end: 600),
      ], monday, 1);
      expect(plans.map((p) => '${p.minuteOfDay}:${p.habitId}').toList(),
          ['480:a', '480:b', '600:a', '600:b']);
    });

    test('localDate is zero-padded YYYY-MM-DD', () {
      final p = planDay(spec(unit: FreqUnit.daily, start: 480, end: 540),
          DateTime(2026, 1, 5));
      expect(p.single.localDate, '2026-01-05');
    });
  });
}
