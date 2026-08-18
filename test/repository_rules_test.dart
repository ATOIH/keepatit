// Data-rule tests — instance keys and creation-day gating (pure logic).
import 'package:flutter_test/flutter_test.dart';
import 'package:keepatit/data/repository.dart';
import 'package:keepatit/engine/models.dart';

PlannedInstance plan(int y, int m, int d, int minute) => PlannedInstance(
      habitId: 'h1',
      year: y,
      month: m,
      day: d,
      minuteOfDay: minute,
      deadlineMinuteOfDay: kEndOfDayMinute,
    );

void main() {
  group('instance keys', () {
    test('roundtrip', () {
      final key = instanceKey('h1', '2026-08-17', 480);
      expect(key, 'h1|2026-08-17|480');
      final parsed = parseInstanceKey(key)!;
      expect(parsed.habitId, 'h1');
      expect(parsed.localDate, '2026-08-17');
      expect(parsed.minuteOfDay, 480);
    });

    test('malformed keys parse to null, never throw', () {
      expect(parseInstanceKey('garbage'), isNull);
      expect(parseInstanceKey('a|b'), isNull);
      expect(parseInstanceKey('a|b|notanumber'), isNull);
    });

    test('localDateOf zero-pads', () {
      expect(localDateOf(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('creation-day gating (a habit created at 18:37 owes nothing earlier)',
      () {
    final createdAt = DateTime(2026, 8, 17, 18, 37);

    test('same-day instances before creation are excluded', () {
      expect(precedesCreation(createdAt, plan(2026, 8, 17, 8 * 60)), isTrue);
      expect(precedesCreation(createdAt, plan(2026, 8, 17, 18 * 60)), isTrue);
    });

    test('same-day instances at/after creation count', () {
      expect(
          precedesCreation(createdAt, plan(2026, 8, 17, 18 * 60 + 37)), isFalse);
      expect(precedesCreation(createdAt, plan(2026, 8, 17, 19 * 60)), isFalse);
    });

    test('later days always count', () {
      expect(precedesCreation(createdAt, plan(2026, 8, 18, 8 * 60)), isFalse);
    });
  });
}
