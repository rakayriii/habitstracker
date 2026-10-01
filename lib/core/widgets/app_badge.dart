import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

enum BadgeTone { accent, positive, warning, critical, neutral }

Color _toneColor(BadgeTone tone) => switch (tone) {
  BadgeTone.accent => MyOSColors.accentDim,
  BadgeTone.positive => MyOSColors.positive,
  BadgeTone.warning => MyOSColors.warning,
  BadgeTone.critical => MyOSColors.negative,
  BadgeTone.neutral => MyOSColors.textSecondary,
};

/// Micro-badge. 4px radius, 10% fill, 25% border, uppercase `label-sm`. It
/// exists to report a state (status, category, system flag) and nothing else.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.dense = false,
  });

  final String label;
  final BadgeTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 5 : 6,
        vertical: dense ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: MyOSText.labelSm.copyWith(
          color: color,
          fontSize: dense ? 10 : 11,
          height: dense ? 13 / 10 : 14 / 11,
        ),
      ),
    );
  }
}

/// Tappable chip for filters. Unselected is a flat surface cell; selected
/// lifts to the level 2 well with the accent border, which is the only
/// selected-state treatment in the system.
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MyOSColors.surfaceHigh : MyOSColors.surface,
      borderRadius: BorderRadius.circular(MyOSRadius.sm),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(MyOSRadius.sm),
        splashColor: MyOSColors.surfaceHighest,
        highlightColor: MyOSColors.surfaceHigh,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MyOSSpace.sm,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MyOSRadius.sm),
            border: Border.all(
              color: selected ? MyOSColors.accent : MyOSColors.border,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: MyOSText.labelSm.copyWith(
              color: selected ? MyOSColors.textPrimary : MyOSColors.textMuted,
              letterSpacing: 0.33,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling filter rail. Scrolls only when the set outgrows the
/// viewport, so it never steals vertical space on a small phone.
class FilterRail extends StatelessWidget {
  const FilterRail({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.margin),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: MyOSSpace.sm),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}
