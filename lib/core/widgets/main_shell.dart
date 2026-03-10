import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(
      path: '/deliveries',
      label: 'Livraisons',
      icon: Icons.shopping_basket_outlined,
      activeIcon: Icons.shopping_basket,
    ),
    _TabItem(
      path: '/products',
      label: 'Produits',
      icon: Icons.eco_outlined,
      activeIcon: Icons.eco,
    ),
    _TabItem(
      path: '/compare',
      label: 'Comparer',
      icon: Icons.compare_arrows_outlined,
      activeIcon: Icons.compare_arrows,
    ),
    _TabItem(
      path: '/analytics',
      label: 'Analytics',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_tabs[index].path),
        items: _tabs
            .map((tab) => BottomNavigationBarItem(
                  icon: Icon(tab.icon),
                  activeIcon: Icon(tab.activeIcon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
