// S2 — Setup Habit Protocol, PRD §7.2 (+DD-1 stepper/Daily, +DD-5 rest day).
// Design: setup_task. Transactional full-screen; also serves edit mode.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/db.dart';
import '../data/repository.dart';
import '../engine/budget.dart';
import '../engine/models.dart';
import '../notifications/content.dart';
import '../notifications/notifier.dart';
import '../notifications/sync.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'priming_sheet.dart';

class SetupScreen extends StatefulWidget {
  final AppDb db;
  final Habit? edit;
  const SetupScreen({super.key, required this.db, this.edit});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late final TextEditingController _directive;
  FreqUnit _unit = FreqUnit.hours;
  int _qty = 1;
  int _startMin = 9 * 60;
  int _endMin = 17 * 60;
  int? _restDay;
  String? _error;
  bool _busy = false;

  bool get isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _directive = TextEditingController(text: e?.directive ?? '');
    if (e != null) {
      _unit = FreqUnit.values.firstWhere((u) => u.name == e.freqUnit);
      _qty = e.intervalQty ?? 1;
      _startMin = e.windowStartMin;
      _endMin = e.windowEndMin;
      _restDay = e.restDay;
    }
  }

  @override
  void dispose() {
    _directive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: KColors.pureBlack,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: KColors.lowContrast),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('KEEP AT IT',
            style: KType.headlineMd.copyWith(letterSpacing: -0.4)),
        shape: const Border(
            bottom: BorderSide(color: KColors.borderSubtle, width: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            KSpace.marginMobile, KSpace.lg, KSpace.marginMobile, 120),
        children: [
          Text(isEdit ? 'Edit Habit Protocol' : 'Setup Habit Protocol',
              style: KType.headlineLgMobile),
          const SizedBox(height: KSpace.sm),
          Text('Define the parameters of your new focus ritual.',
              style: KType.bodySm.copyWith(color: KColors.lowContrast)),
          const SizedBox(height: KSpace.lg),

          const SectionLabel('Directive (10-15 words)'),
          const SizedBox(height: KSpace.sm),
          TextField(
            controller: _directive,
            maxLength: kDirectiveMaxChars,
            maxLines: 3,
            minLines: 2,
            style: KType.bodyLg,
            decoration: _inputDecoration(
                'E.g., Complete deep work session on architectural blueprints without interruptions…'),
          ),
          const SizedBox(height: KSpace.lg),

          const SectionLabel('Frequency cycle'),
          const SizedBox(height: KSpace.sm),
          Row(children: [
            _unitOption(FreqUnit.minutes, Icons.timer, 'Minutes'),
            const SizedBox(width: KSpace.md),
            _unitOption(FreqUnit.hours, Icons.hourglass_empty, 'Hours'),
            const SizedBox(width: KSpace.md),
            _unitOption(FreqUnit.daily, Icons.today, 'Daily'),
          ]),
          if (_unit != FreqUnit.daily) ...[
            const SizedBox(height: KSpace.md),
            _stepper(),
          ],
          const SizedBox(height: KSpace.lg),

          const SectionLabel('Operational window'),
          const SizedBox(height: KSpace.sm),
          Row(children: [
            Expanded(child: _timeField('START T-MINUS', _startMin,
                (m) => setState(() => _startMin = m))),
            const SizedBox(width: KSpace.md),
            Expanded(child: _timeField('END T-ZERO', _endMin,
                (m) => setState(() => _endMin = m))),
          ]),
          const SizedBox(height: KSpace.lg),

          const SectionLabel('Rest day'),
          const SizedBox(height: KSpace.sm),
          _restDayRow(),
          const SizedBox(height: KSpace.xl),

          if (_error != null) ...[
            Text(_error!, style: KType.bodySm.copyWith(color: KColors.crimson)),
            const SizedBox(height: KSpace.md),
          ],
          CrimsonButton(
            label: isEdit ? 'SAVE CHANGES' : 'ACTIVATE HABIT',
            icon: Icons.power_settings_new,
            onPressed: _busy ? null : _save,
          ),
          if (isEdit) ...[
            const SizedBox(height: KSpace.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: KColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(vertical: KSpace.md),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadius)),
                ),
                onPressed: _busy ? null : _deactivate,
                child: Text('DEACTIVATE',
                    style: KType.bodySm.copyWith(color: KColors.onSurface)),
              ),
            ),
            const SizedBox(height: KSpace.sm),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _delete,
                child: Text('DELETE HABIT',
                    style: KType.bodySm.copyWith(color: KColors.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: KType.bodyLg.copyWith(color: KColors.lowContrast),
        filled: true,
        fillColor: KColors.pureBlack,
        counterStyle: KType.labelMono.copyWith(color: KColors.lowContrast),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: KColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadius),
          borderSide: const BorderSide(color: KColors.crimson),
        ),
      );

  Widget _unitOption(FreqUnit unit, IconData icon, String label) {
    final selected = _unit == unit;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _unit = unit;
          if (unit == FreqUnit.minutes && _qty < kMinIntervalMinutes) {
            _qty = kMinIntervalMinutes;
          }
          if (unit == FreqUnit.hours && _qty > 12) _qty = 1;
        }),
        borderRadius: BorderRadius.circular(kRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: KSpace.md),
          decoration: BoxDecoration(
            color: selected ? KColors.surfaceHover : KColors.surface,
            border: Border.all(
                color: selected ? KColors.crimson : KColors.borderSubtle),
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Column(children: [
            Icon(icon,
                size: 18,
                color: selected ? KColors.crimson : KColors.lowContrast),
            const SizedBox(height: KSpace.xs),
            Text(label, style: KType.labelMono),
          ]),
        ),
      ),
    );
  }

  Widget _stepper() {
    final isMinutes = _unit == FreqUnit.minutes;
    final minQty = isMinutes ? kMinIntervalMinutes : 1;
    final maxQty = isMinutes ? 59 : 12;
    final step = isMinutes ? 5 : 1;
    final label = isMinutes ? 'EVERY $_qty MINUTES' : 'EVERY $_qty HOUR(S)';

    return Container(
      padding: const EdgeInsets.all(KSpace.sm),
      decoration: ghostCard(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _qty - step >= minQty
                ? () => setState(() => _qty = max(minQty, _qty - step))
                : null,
            icon: const Icon(Icons.remove),
            color: KColors.onSurface,
          ),
          Text(label, style: KType.labelMono),
          IconButton(
            onPressed: _qty + step <= maxQty
                ? () => setState(() => _qty = min(maxQty, _qty + step))
                : null,
            icon: const Icon(Icons.add),
            color: KColors.onSurface,
          ),
        ],
      ),
    );
  }

  Widget _timeField(String label, int minuteOfDay, ValueChanged<int> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KType.labelCaps),
        const SizedBox(height: KSpace.xs),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                  hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60),
            );
            if (picked != null) onPick(picked.hour * 60 + picked.minute);
          },
          borderRadius: BorderRadius.circular(kRadius),
          child: Container(
            padding: const EdgeInsets.all(KSpace.sm),
            decoration: BoxDecoration(
              color: KColors.pureBlack,
              border: Border.all(color: KColors.borderSubtle),
              borderRadius: BorderRadius.circular(kRadius),
            ),
            child: Text(formatMinute(minuteOfDay), style: KType.bodyLg),
          ),
        ),
      ],
    );
  }

  Widget _restDayRow() {
    const labels = ['NONE', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Wrap(
      spacing: KSpace.sm,
      runSpacing: KSpace.sm,
      children: [
        for (var i = 0; i < labels.length; i++)
          InkWell(
            onTap: () => setState(() => _restDay = i == 0 ? null : i),
            borderRadius: BorderRadius.circular(kRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.md, vertical: KSpace.sm),
              decoration: BoxDecoration(
                color: (_restDay == null && i == 0) || _restDay == i
                    ? KColors.surfaceHover
                    : KColors.surface,
                border: Border.all(
                    color: (_restDay == null && i == 0) || _restDay == i
                        ? KColors.crimson
                        : KColors.borderSubtle),
                borderRadius: BorderRadius.circular(kRadius),
              ),
              child: Text(labels[i], style: KType.labelMono),
            ),
          ),
      ],
    );
  }

  HabitSpec _buildSpec(String id) => HabitSpec(
        id: id,
        directive: _directive.text.trim(),
        unit: _unit,
        intervalQty: _unit == FreqUnit.daily ? null : _qty,
        windowStartMin: _startMin,
        windowEndMin: _endMin,
        restDay: _restDay,
      );

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await activeHabitRows(widget.db);
      final existing = rows
          .where((r) => r.id != widget.edit?.id)
          .map(specFromRow)
          .toList();
      final id = widget.edit?.id ??
          'h${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';
      final spec = _buildSpec(id);

      final result = validateHabit(existing, spec);
      if (!result.ok) {
        setState(() {
          _error = result.message;
          _busy = false;
        });
        return;
      }

      if (isEdit) {
        await updateHabit(widget.db, spec);
      } else {
        await insertHabit(widget.db, spec);
        await ensureProgramStart(widget.db);
      }

      // First-ever activation: priming sheet before the OS permission prompt
      // (PRD §7.6). Denial leaves the app as a manual tracker with a banner.
      if (!await primingDone(widget.db)) {
        if (!mounted) return;
        final enable = await showPrimingSheet(context);
        await setAppState(widget.db, 'priming_done', '1');
        if (enable) await requestNotificationPermission();
      }

      await fullSync(widget.db, tz.local);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate() async {
    await deactivateHabit(widget.db, widget.edit!.id);
    await fullSync(widget.db, tz.local);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadius),
            side: const BorderSide(color: KColors.borderSubtle)),
        title: Text('Delete habit?', style: KType.headlineMd),
        content: Text(
            'The habit is removed from Today. Its history stays in your stats.',
            style: KType.bodySm.copyWith(color: KColors.lowContrast)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('CANCEL',
                  style: KType.labelCaps.copyWith(color: KColors.lowContrast))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('DELETE',
                  style: KType.labelCaps.copyWith(color: KColors.crimson))),
        ],
      ),
    );
    if (confirmed != true) return;
    await tombstoneHabit(widget.db, widget.edit!.id);
    await fullSync(widget.db, tz.local);
    if (mounted) Navigator.of(context).pop();
  }
}
