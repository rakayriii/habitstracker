import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

/// Executive header. Fixed above the scroll view: workspace label, title,
/// contextual state counter, and an initial-mask avatar. The avatar is a
/// display element, not a control, so it carries no tap behaviour until there
/// is a profile destination to open.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.workspace,
    required this.title,
    this.meta,
    this.counter,
    this.avatarInitial,
    this.onAvatarTap,
  });

  final String workspace;
  final String title;
  final String? meta;
  final String? counter;
  final String? avatarInitial;

  /// When set, the avatar becomes a control that opens the settings sheet.
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MyOSSpace.margin,
        MyOSSpace.md,
        MyOSSpace.margin,
        MyOSSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 48px is the floor, not a cap: a large system text scale grows the
          // header rather than clipping the workspace title.
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MyOSSpace.headerHeight,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.toUpperCase(),
                        style: MyOSText.labelSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: MyOSText.headlineMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (counter != null) ...[
                  const SizedBox(width: MyOSSpace.sm),
                  Text(
                    counter!,
                    style: MyOSText.dataSm,
                    textAlign: TextAlign.right,
                  ),
                ],
                if (avatarInitial != null) ...[
                  const SizedBox(width: MyOSSpace.md),
                  _Avatar(
                    initial: avatarInitial!,
                    onTap: onAvatarTap,
                  ),
                ],
              ],
            ),
          ),
          if (meta != null) ...[
            const SizedBox(height: MyOSSpace.xs),
            Text(
              meta!,
              style: MyOSText.bodySm.copyWith(color: MyOSColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Initial-mask avatar: a 32px circle in the level 2 well with the operator
/// initial. Placeholder by design, no photo is invented.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, this.onTap});

  final String initial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MyOSColors.surfaceHigh,
        shape: BoxShape.circle,
        border: Border.all(color: MyOSColors.border),
      ),
      child: Text(
        initial.toUpperCase(),
        style: MyOSText.dataSm.copyWith(
          color: MyOSColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );

    if (onTap == null) return avatar;
    return Semantics(
      button: true,
      label: 'Pengaturan',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: avatar,
        ),
      ),
    );
  }
}
