import 'package:flutter/material.dart';

import '../constants/design_tokens.dart';

/// Level 1 container: solid surface, 1px structural border, no shadow.
/// Depth comes from the tonal ramp, never from blur or drop shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MyOSSpace.md),
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MyOSColors.surface,
        borderRadius: BorderRadius.circular(MyOSRadius.lg),
        border: Border.all(color: borderColor ?? MyOSColors.border),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(MyOSRadius.lg),
                splashColor: MyOSColors.surfaceHighest,
                highlightColor: MyOSColors.surfaceHigh,
                child: content,
              ),
            ),
    );
  }
}

/// Level 2 block: an inset well used for child blocks inside a card.
class AppWell extends StatelessWidget {
  const AppWell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: MyOSSpace.md,
      vertical: MyOSSpace.sm,
    ),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MyOSColors.surfaceHigh,
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        border: Border.all(color: MyOSColors.hairline),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(MyOSRadius.md),
                splashColor: MyOSColors.surfaceHighest,
                highlightColor: MyOSColors.surfaceHighest,
                child: content,
              ),
            ),
    );
  }
}
