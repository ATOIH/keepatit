// First-run permission priming (PRD §7.6, design delta DD-3).
// One bottom sheet, shown once, before the OS notification prompt.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'common.dart';

/// Returns true when the user chose ENABLE TRIGGERS.
Future<bool> showPrimingSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: KColors.surface,
    isDismissible: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      side: BorderSide(color: KColors.borderSubtle),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(KSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Triggers are the product'),
            const SizedBox(height: KSpace.md),
            Text(
              "Keep At It works through notifications — that's the whole "
              'product. Allow them, or the app stays silent.',
              style: KType.bodyLg,
            ),
            const SizedBox(height: KSpace.lg),
            CrimsonButton(
              label: 'ENABLE TRIGGERS',
              icon: Icons.notifications_active,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: KSpace.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('NOT NOW',
                    style:
                        KType.labelCaps.copyWith(color: KColors.lowContrast)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
