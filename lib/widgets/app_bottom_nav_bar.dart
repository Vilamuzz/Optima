import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/printer_settings_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/restock_screen.dart';
import '../screens/store_profile_screen.dart';
import '../theme/app_theme.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({super.key, required this.currentIndex});

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget target;
    switch (index) {
      case 0:
        target = const HomeScreen();
        break;
      case 1:
        target = const RestockScreen();
        break;
      case 2:
        target = const ProductListScreen();
        break;
      case 3:
        target = const PrinterSettingsScreen();
        break;
      case 4:
        target = const StoreProfileScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => target,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => _onDestinationSelected(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.insights_rounded),
          selectedIcon: Icon(Icons.insights_rounded, color: AppTheme.primaryEmerald),
          label: 'Sales',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_shopping_cart_rounded),
          selectedIcon: Icon(Icons.add_shopping_cart_rounded, color: AppTheme.primaryEmerald),
          label: 'Restock',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_rounded),
          selectedIcon: Icon(Icons.inventory_2_rounded, color: AppTheme.primaryEmerald),
          label: 'Products',
        ),
        NavigationDestination(
          icon: Icon(Icons.print_rounded),
          selectedIcon: Icon(Icons.print_rounded, color: AppTheme.primaryEmerald),
          label: 'Printer',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_rounded),
          selectedIcon: Icon(Icons.storefront_rounded, color: AppTheme.primaryEmerald),
          label: 'Store',
        ),
      ],
    );
  }
}
