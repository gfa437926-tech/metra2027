import 'package:flutter/material.dart';

/// One shared navigation surface that adapts to compact and wide layouts.
/// Authorization and destination visibility must be supplied by a
/// server-authoritative access context; this widget does not infer roles.
class MetraAdaptiveNavigation extends StatelessWidget {
  const MetraAdaptiveNavigation({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.child,
    required this.onDestinationSelected,
    this.wideBreakpoint = 760,
  });

  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final Widget child;
  final ValueChanged<int> onDestinationSelected;
  final double wideBreakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= wideBreakpoint) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map((item) => NavigationRailDestination(
                            icon: item.icon,
                            selectedIcon: item.selectedIcon ?? item.icon,
                            label: Text(item.label),
                          ))
                      .toList(growable: false),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: child),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: child),
              NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: destinations,
              ),
            ],
          );
        },
      );
}
