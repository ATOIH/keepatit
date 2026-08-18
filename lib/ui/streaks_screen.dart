// S3 — Streaks ("Neuroplasticity in Progress"), PRD §7.3, design: streak_progress.
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/db.dart';
import '../data/repository.dart';
import '../data/stats.dart';
import '../notifications/content.dart';
import '../theme/tokens.dart';
import 'common.dart';

class StreaksScreen extends StatefulWidget {
  final AppDb db;
  const StreaksScreen({super.key, required this.db});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  String? _expandedHabitId;
  String _programStart = '';

  @override
  void initState() {
    super.initState();
    getAppState(widget.db, 'program_start_date').then((v) {
      if (mounted) setState(() => _programStart = v ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final since = localDateOf(DateTime(now.year, now.month, now.day - 92));

    return StreamBuilder<List<Habit>>(
      stream: watchActiveHabitRows(widget.db),
      builder: (context, habitsSnap) {
        final rows = habitsSnap.data ?? const <Habit>[];
        return StreamBuilder<List<TriggerLog>>(
          stream: watchLogsSince(widget.db, since),
          builder: (context, logsSnap) {
            if (rows.isEmpty) {
              return _empty();
            }
            final data = buildStreaks(
              rows: rows,
              logs: logsSnap.data ?? const <TriggerLog>[],
              programStartDate:
                  _programStart.isEmpty ? localDateOf(now) : _programStart,
              loc: tz.local,
            );
            return _body(data);
          },
        );
      },
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.all(KSpace.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KSpace.lg),
          _header(),
          const SizedBox(height: KSpace.xl),
          const Center(
              child:
                  SectionLabel('Activate a habit to start rebuilding pathways')),
        ],
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEUROPLASTICITY IN PROGRESS',
            style: KType.headlineLgMobile.copyWith(letterSpacing: -0.3)),
        const SizedBox(height: KSpace.sm),
        Text('Tracking consistency to rebuild neural pathways.',
            style: KType.bodySm.copyWith(color: KColors.lowContrast)),
      ],
    );
  }

  Widget _body(StreaksData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          KSpace.marginMobile, KSpace.lg, KSpace.marginMobile, 120),
      children: [
        _header(),
        const SizedBox(height: KSpace.lg),

        // Consistency status card.
        Container(
          padding: const EdgeInsets.all(KSpace.md),
          decoration: ghostCard(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Consistency status'),
                    const SizedBox(height: KSpace.xs),
                    Text(
                      data.consistencyPct == null
                          ? 'Awaiting first triggers'
                          : '${data.consistencyPct}% Completion'
                              '${data.maintained ? ' Maintained' : ''}',
                      style: KType.headlineMd,
                    ),
                  ],
                ),
              ),
              if (data.maintained)
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KColors.pureBlack,
                    border: Border.all(color: KColors.crimson, width: 2),
                  ),
                  child: const Icon(Icons.trending_up,
                      color: KColors.crimson, size: 22),
                ),
            ],
          ),
        ),
        const SizedBox(height: KSpace.md),

        // 90-day program card (OC-1).
        Container(
          padding: const EdgeInsets.all(KSpace.md),
          decoration: ghostCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Flexible(
                      child: SectionLabel('90-day neural rewire goal')),
                  Text('Day ${data.programDay} / $kProgramDays',
                      style: KType.labelMono),
                ],
              ),
              const SizedBox(height: KSpace.sm),
              ThinProgress(data.programDay / kProgramDays),
            ],
          ),
        ),
        const SizedBox(height: KSpace.md),

        // Heatmap card with DD-4 expand.
        Container(
          padding: const EdgeInsets.all(KSpace.md),
          decoration: ghostCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Task completion heatmap (last 7 days)'),
              const SizedBox(height: KSpace.md),
              for (final h in data.heat) ...[
                _heatRow(h),
                if (_expandedHabitId == h.spec.id) ...[
                  const SizedBox(height: KSpace.sm),
                  _grid90(h),
                ],
                const SizedBox(height: KSpace.sm),
              ],
              Text('Tap a habit for its 90-day grid',
                  style:
                      KType.labelMono.copyWith(color: KColors.lowContrast)),
            ],
          ),
        ),
        const SizedBox(height: KSpace.md),

        // Today's Triggers timeline.
        Container(
          padding: const EdgeInsets.all(KSpace.md),
          decoration: ghostCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel("Today's triggers"),
              const SizedBox(height: KSpace.md),
              if (data.timeline.isEmpty)
                Text('No triggers today.',
                    style:
                        KType.bodySm.copyWith(color: KColors.lowContrast)),
              for (final t in data.timeline) _timelineRow(t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heatRow(HabitHeat h) {
    return InkWell(
      onTap: () => setState(() => _expandedHabitId =
          _expandedHabitId == h.spec.id ? null : h.spec.id),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              truncateDirective(h.spec.directive),
              style: KType.labelMono,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Row(
              children: [
                for (final b in h.last7) ...[
                  Expanded(child: _cell(b, height: 24)),
                  const SizedBox(width: KSpace.xs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 13 week-columns × 7 day-rows, oldest week left (DD-4). last91 is
  /// oldest-first; cell (col, row) = index col*7 + row.
  Widget _grid90(HabitHeat h) {
    return Container(
      padding: const EdgeInsets.all(KSpace.sm),
      decoration: BoxDecoration(
        color: KColors.pureBlack,
        border: Border.all(color: KColors.borderSubtle),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        children: [
          for (var row = 0; row < 7; row++) ...[
            Row(
              children: [
                for (var col = 0; col < 13; col++) ...[
                  Expanded(child: _cell(h.last91[col * 7 + row], height: 10)),
                  if (col < 12) const SizedBox(width: 2),
                ],
              ],
            ),
            if (row < 6) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }

  Widget _cell(double? bucket, {required double height}) {
    final Color color = switch (bucket) {
      null => Colors.transparent,
      0.0 => KColors.pureBlack,
      1.0 => KColors.crimson,
      _ => KColors.crimson.withValues(alpha: bucket),
    };
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: KColors.borderSubtle, width: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _timelineRow(TimelineEntry t) {
    final missedish = t.label == 'MISSED' || t.label == 'NOT DONE';
    final done = t.label == 'DONE';
    final chipColor = done
        ? KColors.crimson
        : missedish
            ? KColors.error
            : KColors.lowContrast;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${formatMinute(t.minuteOfDay)}${t.isFuture ? ' (Upcoming)' : ''}',
            style: KType.labelMono.copyWith(
                fontSize: 10,
                color: t.isFuture ? KColors.crimson : KColors.lowContrast),
          ),
          const SizedBox(height: KSpace.xs),
          Container(
            padding: const EdgeInsets.all(KSpace.sm),
            decoration: BoxDecoration(
              color: KColors.pureBlack,
              border: Border.all(color: KColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    truncateDirective(t.spec.directive),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.label == 'MISSED'
                        ? KType.bodySm.copyWith(
                            color: KColors.lowContrast,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: KColors.lowContrast)
                        : KType.bodySm,
                  ),
                ),
                const SizedBox(width: KSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KSpace.sm, vertical: KSpace.xs),
                  decoration: BoxDecoration(
                    color: KColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(t.label,
                      style: KType.labelMono.copyWith(color: chipColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
