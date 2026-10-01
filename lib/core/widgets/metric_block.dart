import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

/// Data metric display: micro-label, value, delta. The value is the only
/// element on a screen allowed to reach `data-mono-lg`.
class MetricBlock extends StatelessWidget {
  const MetricBlock({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive,
    this.footnote,
    this.valueStyle,
  });

  final String label;
  final String value;
  final String? delta;
  final bool? deltaPositive;
  final String? footnote;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: MyOSText.labelSm,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: MyOSSpace.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                value,
                style: valueStyle ?? MyOSText.dataLg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: MyOSSpace.sm),
              DeltaPill(text: delta!, positive: deltaPositive ?? true),
            ],
          ],
        ),
        if (footnote != null) ...[
          const SizedBox(height: MyOSSpace.xs),
          Text(
            footnote!,
            style: MyOSText.bodySm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Delta pill. Square-ish 4px radius, 10% fill and a 20% border of the same
/// hue: colour only ever reports direction, never decoration.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? MyOSColors.positive : MyOSColors.negative;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: MyOSText.dataSm.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
