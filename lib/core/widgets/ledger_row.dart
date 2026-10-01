import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

/// Dense ledger row: primary label with secondary metadata beneath, tabular
/// value on the right, hairline divider between continuous items. Minimum
/// height 44px per DESIGN.md list spec.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.title,
    required this.value,
    this.subtitle = '',
    this.valueColor,
    this.leading,
    this.divider = true,
    this.onTap,
    this.titleStyle,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color? valueColor;
  final Widget? leading;
  final bool divider;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MyOSSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: MyOSSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: titleStyle ??
                        MyOSText.bodyMd.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: MyOSText.bodySm.copyWith(
                        fontSize: 11,
                        color: MyOSColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: MyOSSpace.md),
            Text(
              value,
              style: MyOSText.dataMd.copyWith(color: valueColor),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );

    final body = divider
        ? DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: MyOSColors.hairline),
              ),
            ),
            child: row,
          )
        : row;

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: MyOSColors.surfaceHigh,
        highlightColor: MyOSColors.surfaceHigh,
        child: body,
      ),
    );
  }
}

/// 16x16 binary selector. Transparent until checked, then a solid accent cell
/// with the tick punched out in canvas colour.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      label: semanticLabel,
      child: InkResponse(
        onTap: () => onChanged(!checked),
        radius: 22,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: checked ? MyOSColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: checked ? MyOSColors.accent : MyOSColors.textMuted,
              width: 1.5,
            ),
          ),
          child: checked
              ? const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: MyOSColors.canvas,
                )
              : null,
        ),
      ),
    );
  }
}
