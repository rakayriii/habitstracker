import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

/// Section header. DESIGN.md: sentence case, `headline-sm` weight applied to a
/// `text-secondary` colour, optional numeric badge on the right. Never
/// uppercase, never oversized.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: MyOSText.headlineSm.copyWith(color: MyOSColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: MyOSSpace.sm),
          Text(count!, style: MyOSText.dataSm),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: MyOSSpace.md),
          _ActionLink(label: actionLabel!, onTap: onAction!),
        ],
      ],
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MyOSRadius.sm),
        splashColor: MyOSColors.surfaceHigh,
        highlightColor: MyOSColors.surfaceHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MyOSSpace.xs,
            vertical: 2,
          ),
          child: Text(
            label,
            style: MyOSText.labelMd.copyWith(color: MyOSColors.accentDim),
          ),
        ),
      ),
    );
  }
}
