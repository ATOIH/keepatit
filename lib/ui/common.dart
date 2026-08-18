// Shared Obsidian Precision building blocks (PRD Appendix A).
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

BoxDecoration ghostCard({Color border = KColors.borderSubtle}) => BoxDecoration(
      color: KColors.surface,
      border: Border.all(color: border, width: 1),
      borderRadius: BorderRadius.circular(kRadius),
    );

class MonoChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? textColor;
  const MonoChip({super.key, this.icon, required this.label, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KSpace.sm, vertical: KSpace.xs),
      decoration: BoxDecoration(
        color: KColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor ?? KColors.onSurface),
            const SizedBox(width: KSpace.xs),
          ],
          Text(label,
              style: KType.labelMono
                  .copyWith(color: textColor ?? KColors.onSurface)),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: KType.labelCaps);
}

class CrimsonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const CrimsonButton(
      {super.key, required this.label, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: KColors.crimson,
          disabledBackgroundColor: KColors.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(vertical: KSpace.md),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadius)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: KType.bodyLg.copyWith(
                    color: Colors.white,
                    fontVariations: const [FontVariation('wght', 700)])),
            if (icon != null) ...[
              const SizedBox(width: KSpace.sm),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

/// 4px thin-line progress bar (PRD Appendix A).
class ThinProgress extends StatelessWidget {
  final double fraction; // 0..1
  const ThinProgress(this.fraction, {super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 4,
        color: KColors.surfaceContainerHigh,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(color: KColors.crimson),
        ),
      ),
    );
  }
}

void showObsidianSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: KColors.surfaceHover,
    content: Text(message, style: KType.bodySm),
    duration: const Duration(seconds: 2),
  ));
}
