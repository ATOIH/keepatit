// Stats rules — pure derivations behind the Streaks screen (PRD §7.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:keepatit/data/stats.dart';

void main() {
  group('heatBucket (demo opacity tiers)', () {
    test('no expectation => null (neutral cell, never a failure)', () {
      expect(heatBucket(0, 0), isNull);
    });
    test('tiers: 0 / 0.2 / 0.5 / 1.0', () {
      expect(heatBucket(0, 8), 0.0);
      expect(heatBucket(3, 8), 0.2); // 37.5% -> low
      expect(heatBucket(4, 8), 0.5); // 50% boundary -> mid
      expect(heatBucket(7, 8), 0.5);
      expect(heatBucket(8, 8), 1.0);
    });
  });

  group('programDayOf — 90-day cycle, auto-recycling (OC-1/D-6)', () {
    test('day 1 on the start date', () {
      expect(programDayOf('2026-08-17', '2026-08-17'), 1);
    });
    test('day 48 mid-cycle', () {
      expect(programDayOf('2026-08-17', '2026-10-03'), 48);
    });
    test('day 90 on the last day, then recycles to day 1', () {
      expect(programDayOf('2026-08-17', '2026-11-14'), 90);
      expect(programDayOf('2026-08-17', '2026-11-15'), 1);
    });
  });

  group('consistencyOf', () {
    test('80% from the PRD worked example (32/40)', () {
      final r = consistencyOf([(done: 32, expected: 40)]);
      expect((r! * 100).round(), 80);
    });
    test('null when nothing expected (fresh install)', () {
      expect(consistencyOf([(done: 0, expected: 0)]), isNull);
    });
    test('sums across days and habits', () {
      final r = consistencyOf([
        (done: 3, expected: 4),
        (done: 1, expected: 4),
      ]);
      expect(r, 0.5);
    });
  });

  group('timelineLabel', () {
    test('maps states to demo chips', () {
      expect(timelineLabel('done', isFuture: false), 'DONE');
      expect(timelineLabel('not_done', isFuture: false), 'NOT DONE');
      expect(timelineLabel('missed', isFuture: false), 'MISSED');
      expect(timelineLabel('excused', isFuture: false), 'EXCUSED');
      expect(timelineLabel(null, isFuture: true), 'PENDING');
      expect(timelineLabel(null, isFuture: false), 'PENDING');
    });
  });
}
