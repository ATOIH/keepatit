// Engine-adjacent test suite — notification copy is product spec (PRD §7.5).
import 'package:flutter_test/flutter_test.dart';
import 'package:keepatit/engine/models.dart';
import 'package:keepatit/notifications/content.dart';

HabitSpec spec(String directive, FreqUnit unit,
        {int? qty, required int start, required int end}) =>
    HabitSpec(
      id: 'h',
      directive: directive,
      unit: unit,
      intervalQty: qty,
      windowStartMin: start,
      windowEndMin: end,
    );

void main() {
  group('body templates — exact strings from the demo', () {
    test('daily: "Time to focus. 90 minutes remaining."', () {
      // Deep Work window ends 15:30; fires 14:00 -> 90 minutes remaining.
      final s = spec('Deep Work', FreqUnit.daily, start: 840, end: 930);
      expect(notificationBody(s, 840), 'Time to focus. 90 minutes remaining.');
    });

    test("interval: '{directive}. {X} remaining in today's window.'", () {
      final s = spec('Drink 250ml water', FreqUnit.hours,
          qty: 2, start: 480, end: 1320);
      expect(notificationBody(s, 1200),
          "Drink 250ml water. 2 hours remaining in today's window.");
    });

    test('interval with fractional hours renders one decimal', () {
      final s = spec('Stretch', FreqUnit.hours, qty: 1, start: 480, end: 1320);
      expect(notificationBody(s, 1170),
          "Stretch. 2.5 hours remaining in today's window.");
    });
  });

  group('formatRemaining', () {
    test('below two hours stays in minutes', () {
      expect(formatRemaining(90), '90 minutes');
      expect(formatRemaining(119), '119 minutes');
      expect(formatRemaining(45), '45 minutes');
    });
    test('whole and fractional hours', () {
      expect(formatRemaining(120), '2 hours');
      expect(formatRemaining(150), '2.5 hours');
      expect(formatRemaining(840), '14 hours');
    });
    test('floors at one minute', () {
      expect(formatRemaining(0), '1 minute');
      expect(formatRemaining(1), '1 minute');
    });
  });

  group('title', () {
    test('prefixes app name and truncates at 30 chars with ellipsis', () {
      final short = spec('Deep Work', FreqUnit.daily, start: 0, end: 60);
      expect(notificationTitle(short), 'Keep At It: Deep Work');

      final long = spec(
          'Complete deep work session on architectural blueprints',
          FreqUnit.daily,
          start: 0,
          end: 60);
      final title = notificationTitle(long);
      expect(title.startsWith('Keep At It: '), isTrue);
      expect(title.length, 'Keep At It: '.length + kTitleDirectiveChars);
      expect(title.endsWith('…'), isTrue);
    });
  });

  group('chips (Appendix B grammar)', () {
    test('frequency chip grammar', () {
      expect(
          frequencyChip(
              spec('x', FreqUnit.minutes, qty: 20, start: 0, end: 60)),
          'Every 20 mins');
      expect(frequencyChip(spec('x', FreqUnit.hours, qty: 1, start: 0, end: 60)),
          'Every 1 hour');
      expect(frequencyChip(spec('x', FreqUnit.hours, qty: 2, start: 0, end: 60)),
          'Every 2 hours');
      expect(frequencyChip(spec('x', FreqUnit.daily, start: 0, end: 60)),
          'Once a day');
    });
    test('window chip zero-pads', () {
      expect(windowChip(spec('x', FreqUnit.daily, start: 480, end: 1320)),
          '08:00 - 22:00');
    });
  });
}
