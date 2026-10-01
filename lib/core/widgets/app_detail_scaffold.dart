import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../constants/design_tokens.dart';

/// Shell for every screen that is not one of the four hub tabs: detail pages,
/// forms, and the account list. Same header grammar as the hubs, with a back
/// control and an optional action, and an optional action bar pinned to the
/// bottom.
class AppDetailScaffold extends StatelessWidget {
  const AppDetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.bottomBar,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? bottomBar;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyOSColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MyOSSpace.xs,
                MyOSSpace.sm,
                MyOSSpace.margin,
                MyOSSpace.sm,
              ),
              child: Row(
                children: [
                  _BackButton(onBack: onBack),
                  const SizedBox(width: MyOSSpace.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: MyOSText.headlineSm,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: MyOSText.dataSm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: MyOSSpace.sm),
                    ...actions,
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MyOSSpace.margin,
                  MyOSSpace.md,
                  MyOSSpace.margin,
                  MyOSSpace.xl,
                ),
                child: child,
              ),
            ),
            if (bottomBar != null)
              Container(
                decoration: const BoxDecoration(
                  color: MyOSColors.canvas,
                  border: Border(
                    top: BorderSide(color: MyOSColors.border),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  MyOSSpace.margin,
                  MyOSSpace.md,
                  MyOSSpace.margin,
                  MyOSSpace.md + MediaQuery.paddingOf(context).bottom,
                ),
                child: bottomBar,
              ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Kembali',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onBack ?? () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(MyOSRadius.sm),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: const Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: MyOSColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Header action, an icon only trigger so the header stays one line.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tone = MyOSActionTone.accent,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final MyOSActionTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MyOSActionTone.accent => MyOSColors.accentDim,
      MyOSActionTone.critical => MyOSColors.negative,
    };
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: MyOSColors.surfaceHigh,
        borderRadius: BorderRadius.circular(MyOSRadius.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MyOSRadius.sm),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MyOSRadius.sm),
              border: Border.all(color: MyOSColors.border),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

enum MyOSActionTone { accent, critical }

/// Text action used where an icon would be ambiguous, for example "Hapus".
class HeaderTextAction extends StatelessWidget {
  const HeaderTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = MyOSActionTone.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final MyOSActionTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MyOSActionTone.accent => MyOSColors.accentDim,
      MyOSActionTone.critical => MyOSColors.negative,
    };
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MyOSRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MyOSSpace.xs,
              vertical: 6,
            ),
            child: Text(
              label,
              style: MyOSText.labelMd.copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading state for a first read.
///
/// Deliberately static. The read is a local SQLite query, an indeterminate
/// progress bar would animate for a few milliseconds and then stop, and an
/// endless animation on a screen that is already fast is noise. This states
/// that the read is running and holds its place in the layout.
class LoadingLine extends StatelessWidget {
  const LoadingLine({super.key, this.label = 'MEMUAT DATA'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MyOSSpace.sm),
      child: Row(
        children: [
          const SizedBox(
            width: 10,
            height: 1,
            child: ColoredBox(color: MyOSColors.accentDim),
          ),
          const SizedBox(width: MyOSSpace.sm),
          Text(label, style: MyOSText.labelSm),
        ],
      ),
    );
  }
}

/// Full page for a route whose id does not resolve.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.what, this.onBack});

  final String what;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AppDetailScaffold(
      title: what,
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Halaman ini tidak tersedia.', style: MyOSText.bodyMd),
          const SizedBox(height: MyOSSpace.md),
          PrimaryShellButton(
            label: 'Kembali',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Plain secondary button, exported here so the scaffold has no dependency on
/// the form kit.
class PrimaryShellButton extends StatelessWidget {
  const PrimaryShellButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MyOSColors.surfaceHigh,
      borderRadius: BorderRadius.circular(MyOSRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MyOSRadius.md),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: MyOSSpace.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MyOSRadius.md),
            border: Border.all(color: MyOSColors.border),
          ),
          child: Text(label, style: MyOSText.labelMd),
        ),
      ),
    );
  }
}
