// Engine test suite — schedule selection (PRD §8.2).
import 'package:flutter_test/flutter_test.dart';
import 'package:keepatit/engine/models.dart';
import 'package:keepatit/engine/schedule_select.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

/// The PRD Appendix C demo set (46 instances/day).
List<HabitSpec> demoSet() => [
      spec(id: 'water', qty: 2, start: 480, end: 1320),
      spec(id: 'posture', qty: 1, start: 540, end: 1020),
      spec(id: 'review', unit: FreqUnit.daily, start: 480, end: 540),
      spec(
          id: 'screen',
          unit: FreqUnit.minutes,
          qty: 20,
          start: 540,
          end: 1080),
    ];

void main() {
  setUpAll(tzdata.initializeTimeZones);
  late tz.Location kolkata;
  setUp(() => kolkata = tz.getLocation('Asia/Kolkata'));

  // Monday 2026-08-17, 07:00 local — before every window opens.
  tz.TZDateTime monday7am(tz.Location loc) =>
      tz.TZDateTime(loc, 2026, 8, 17, 7, 0);

  group('Android mode', () {
    test('everything within 48h, capped at 128, sorted ascending', () {
      final out = selectSchedule(
        specs: demoSet(),
        loc: kolkata,
        now: monday7am(kolkata),
        iosBudgetMode: false,
      );
      // 46/day * 2 full days = 92 within 48h from 07:00 (both days' windows fit).
      expect(out.length, 92);
      expect(out.length <= kAndroidMaxPending, isTrue);
      for (var i = 1; i < out.length; i++) {
        expect(out[i].at.isBefore(out[i - 1].at), isFalse);
      }
      expect(out.any((t) => t.repeatingDaily), isFalse);
    });

    test('only future instances are selected', () {
      final now = tz.TZDateTime(kolkata, 2026, 8, 17, 12, 1); // midday
      final out = selectSchedule(
        specs: [spec(id: 'water', qty: 2, start: 480, end: 1320)],
        loc: kolkata,
        now: now,
        iosBudgetMode: false,
      );
      expect(out.first.at.isAfter(now), isTrue);
      // 14:00,16:00,18:00,20:00,22:00 today + 8 tomorrow + 08:00,10:00,12:00 day3
      expect(out.first.at.hour, 14);
    });

    test('rest day produces a gap, not a crash', () {
      final gtg = spec(
          id: 'gtg',
          qty: 1,
          start: 480,
          end: 1320,
          restDay: DateTime.tuesday);
      final out = selectSchedule(
        specs: [gtg],
        loc: kolkata,
        now: monday7am(kolkata), // Tue 18th is inside the 48h horizon
        iosBudgetMode: false,
      );
      expect(out.any((t) => t.plan.localDate == '2026-08-18'), isFalse);
      expect(out.any((t) => t.plan.localDate == '2026-08-17'), isTrue);
    });
  });

  group('iOS budget mode', () {
    test('daily habit becomes exactly one repeating slot', () {
      final out = selectSchedule(
        specs: demoSet(),
        loc: kolkata,
        now: monday7am(kolkata),
        iosBudgetMode: true,
      );
      final repeating = out.where((t) => t.repeatingDaily).toList();
      expect(repeating.length, 1);
      expect(repeating.single.plan.habitId, 'review');
      expect(out.length <= kIosSlotBudget, isTrue);
    });

    test('interval slots fill chronologically to the budget', () {
      final out = selectSchedule(
        specs: demoSet(),
        loc: kolkata,
        now: monday7am(kolkata),
        iosBudgetMode: true,
      );
      // 1 repeating + 59 one-shots = full budget of 60.
      expect(out.length, kIosSlotBudget);
      final oneShots = out.where((t) => !t.repeatingDaily).toList();
      for (var i = 1; i < oneShots.length; i++) {
        expect(oneShots[i].at.isBefore(oneShots[i - 1].at), isFalse);
      }
    });

    test('daily habit WITH a rest day is one-shot, never repeating (F-14)', () {
      final out = selectSchedule(
        specs: [
          spec(
              id: 'evening',
              unit: FreqUnit.daily,
              start: 1080,
              end: 1140,
              restDay: DateTime.sunday),
        ],
        loc: kolkata,
        now: monday7am(kolkata),
        iosBudgetMode: true,
      );
      expect(out, isNotEmpty);
      expect(out.any((t) => t.repeatingDaily), isFalse);
    });

    test('coverage horizon exceeds 24h for the demo set (PRD guarantee)', () {
      final now = monday7am(kolkata);
      final out = selectSchedule(
        specs: demoSet(),
        loc: kolkata,
        now: now,
        iosBudgetMode: true,
      );
      final lastOneShot =
          out.lastWhere((t) => !t.repeatingDaily).at;
      expect(lastOneShot.difference(now).inHours >= 24, isTrue);
    });
  });

  group('notification ids', () {
    test('stable, positive, distinct for distinct keys', () {
      final a1 = notificationIdFor('h1|2026-08-17|480');
      final a2 = notificationIdFor('h1|2026-08-17|480');
      final b = notificationIdFor('h1|2026-08-17|600');
      expect(a1, a2);
      expect(a1, isNot(b));
      expect(a1 >= 0, isTrue);
      expect(b >= 0, isTrue);
    });
  });
}
