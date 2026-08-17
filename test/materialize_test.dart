// Engine test suite — timezone materialization & DST rules (PRD §8.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:keepatit/engine/materialize.dart';
import 'package:keepatit/engine/models.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

PlannedInstance at(int y, int m, int d, int minute) => PlannedInstance(
      habitId: 'h',
      year: y,
      month: m,
      day: d,
      minuteOfDay: minute,
      deadlineMinuteOfDay: kEndOfDayMinute,
    );

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('DST spring-forward (Europe/London, 29 Mar 2026: 01:00 -> 02:00)', () {
    test('nonexistent wall time 01:30 => null (excused, PRD §8.4)', () {
      final london = tz.getLocation('Europe/London');
      expect(materialize(london, at(2026, 3, 29, 90)), isNull);
    });

    test('03:30 the same day materializes normally', () {
      final london = tz.getLocation('Europe/London');
      final t = materialize(london, at(2026, 3, 29, 210));
      expect(t, isNotNull);
      expect(t!.hour, 3);
      expect(t.minute, 30);
    });

    test('materializeAll drops the gap instance, keeps the rest', () {
      final london = tz.getLocation('Europe/London');
      final out = materializeAll(
          london, [at(2026, 3, 29, 90), at(2026, 3, 29, 210)]);
      expect(out.length, 1);
      expect(out.single.plan.minuteOfDay, 210);
    });
  });

  group('DST fall-back (Europe/London, 25 Oct 2026: 02:00 -> 01:00)', () {
    test('ambiguous wall time 01:30 materializes exactly once', () {
      final london = tz.getLocation('Europe/London');
      final out = materializeAll(london, [at(2026, 10, 25, 90)]);
      expect(out.length, 1);
      expect(out.single.at.hour, 1);
      expect(out.single.at.minute, 30);
    });

    test('duplicate planned instances dedupe on (habit, date, HH:mm)', () {
      final london = tz.getLocation('Europe/London');
      final out = materializeAll(
          london, [at(2026, 10, 25, 90), at(2026, 10, 25, 90)]);
      expect(out.length, 1);
    });
  });

  group('no-DST zone sanity (Asia/Kolkata — the owner timezone)', () {
    test('every minute of a normal day materializes to itself', () {
      final kolkata = tz.getLocation('Asia/Kolkata');
      for (final minute in [0, 90, 480, 719, 1320, kEndOfDayMinute]) {
        final t = materialize(kolkata, at(2026, 8, 17, minute));
        expect(t, isNotNull);
        expect(t!.hour * 60 + t.minute, minute);
      }
    });
  });

  group('ordering and future filtering', () {
    test('materializeAll sorts ascending and honors after=', () {
      final kolkata = tz.getLocation('Asia/Kolkata');
      final cutoff = tz.TZDateTime(kolkata, 2026, 8, 17, 12, 0);
      final out = materializeAll(
        kolkata,
        [at(2026, 8, 17, 600), at(2026, 8, 17, 1320), at(2026, 8, 17, 780)],
        after: cutoff,
      );
      expect(out.map((e) => e.plan.minuteOfDay).toList(), [780, 1320]);
    });
  });
}
