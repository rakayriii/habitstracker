import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

/// Progress meter: a 4px rail with a square cap. Height stays fixed so a list
/// of meters reads as one column, no animation, no glow.
class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    super.key,
    required this.value,
    this.color = MyOSColors.accent,
    this.height = 4,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: MyOSColors.track),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Meter with its own right-aligned readout, the most common shape on the
/// dashboard: title above, percentage beside it.
class LabeledMeter extends StatelessWidget {
  const LabeledMeter({
    super.key,
    required this.label,
    required this.trailing,
    required this.value,
    this.color = MyOSColors.accent,
  });

  final String label;
  final String trailing;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: MyOSText.dataSm.copyWith(color: MyOSColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: MyOSSpace.sm),
            Text(
              trailing,
              style: MyOSText.dataSm.copyWith(
                color: MyOSColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressMeter(value: value, color: color),
      ],
    );
  }
}
