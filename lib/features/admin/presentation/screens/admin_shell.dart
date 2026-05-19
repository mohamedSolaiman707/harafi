import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width > 800)
            NavigationRail(
              extended: true,
              selectedIndex: _getSelectedIndex(location),
              onDestinationSelected: (index) => _onItemTapped(index, context),
              labelType: NavigationRailLabelType.none,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('لوحة التحكم'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: Text('الطلبات'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('الفنيين'),
                ),
              ],
            ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 800
          ? NavigationBar(
              selectedIndex: _getSelectedIndex(location),
              onDestinationSelected: (index) => _onItemTapped(index, context),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  label: 'الطلبات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'الفنيين',
                ),
              ],
            )
          : null,
    );
  }

  int _getSelectedIndex(String location) {
    if (location.startsWith('/admin/orders')) return 1;
    if (location.startsWith('/admin/techs')) return 2;
    if (location.startsWith('/admin')) return 0;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/admin');
        break;
      case 1:
        context.go('/admin/orders');
        break;
      case 2:
        context.go('/admin/techs');
        break;
    }
  }
}
