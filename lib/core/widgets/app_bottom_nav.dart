import 'package:flutter/material.dart';

import '../constants/design_tokens.dart';

/// MyOS bottom navigation. Not Material's NavigationBar: DESIGN.md fixes the
/// container at 56px over the canvas, forbids indicator pills, and splits the
/// four workspaces into equal columns with stroke icons. The only state
/// treatment is the accent rule on top of the active column.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, 'Beranda'),
    _Destination('Finance', Icons.account_balance_wallet_outlined, 'Keuangan'),
    _Destination('Goals', Icons.flag_outlined, 'Target'),
    _Destination('Projects', Icons.work_outline, 'Proyek'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MyOSColors.canvas,
        border: Border(top: BorderSide(color: MyOSColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: SizedBox(
          height: MyOSSpace.navHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.semanticLabel);

  final String label;
  final IconData icon;
  final String semanticLabel;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MyOSColors.accent : MyOSColors.textMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.semanticLabel,
      child: InkWell(
        onTap: onTap,
        splashColor: MyOSColors.surfaceHigh,
        highlightColor: Colors.transparent,
        // The bar is fixed at 56px by the design system, so a large system
        // text scale shrinks the stack instead of overflowing it.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 2,
                margin: const EdgeInsets.only(bottom: 6),
                color: selected ? MyOSColors.accent : Colors.transparent,
              ),
              Icon(destination.icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                destination.label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
