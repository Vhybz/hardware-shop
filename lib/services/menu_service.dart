import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../widgets/app_sidebar.dart';
import '../models/user_model.dart';
import 'user_provider.dart';
import 'transfer_provider.dart';

class MenuClicksNotifier extends StateNotifier<Map<String, int>> {
  MenuClicksNotifier() : super({}) {
    _loadClicks();
  }

  void _loadClicks() {
    try {
      final box = Hive.box('app_settings');
      final Map<dynamic, dynamic>? clicks = box.get('menu_clicks');
      if (clicks != null) {
        state = Map<String, int>.from(clicks);
      }
    } catch (e) {
      debugPrint('Error loading menu clicks: $e');
    }
  }

  void recordClick(String route) {
    if (route == '/admin' || route == '/cashier') return; // Don't track home routes
    final newClicks = Map<String, int>.from(state);
    newClicks[route] = (newClicks[route] ?? 0) + 1;
    state = newClicks;
    
    try {
      final box = Hive.box('app_settings');
      box.put('menu_clicks', newClicks);
    } catch (e) {
      debugPrint('Error saving menu clicks: $e');
    }
  }
}

final menuClicksProvider = StateNotifierProvider<MenuClicksNotifier, Map<String, int>>((ref) {
  return MenuClicksNotifier();
});

class MenuService {
  static List<SidebarItem> getMenuItemsForUser(UserAccount user, {int? pendingTransfersCount, Map<String, int>? clicks}) {
    final List<SidebarItem> items = [];
    final roles = user.activeRoles;
    
    // Check if user is Admin or Super Admin
    final isAdmin = roles.contains(UserRole.admin) || roles.contains(UserRole.superAdmin);

    // Section categories
    const secOverview = 'Overview & Analytics';
    const secStore = 'Store Front & Sales';
    const secInventory = 'Inventory & Supply Chain';
    const secFinance = 'Finance & Compliance';
    const secAdmin = 'Administration & System';

    // List of all possible admin items
    final List<SidebarItem> adminItems = [
      SidebarItem(icon: Icons.dashboard_rounded, label: 'Admin Dashboard', route: '/admin', category: secOverview),
      SidebarItem(icon: Icons.bar_chart_rounded, label: 'Sales & Analytics', route: '/admin/sales', category: secOverview),
      SidebarItem(icon: Icons.point_of_sale_rounded, label: 'Point Of Sale', route: '/cashier', category: secStore),
      SidebarItem(icon: Icons.people_outline_rounded, label: 'Customer Directory', route: '/admin/customers', category: secStore),
      SidebarItem(icon: Icons.assignment_return_rounded, label: 'Returns & Refunds Hub', route: '/admin/returns', category: secStore),
      SidebarItem(icon: Icons.account_balance_wallet_rounded, label: 'Debt Tracker', route: '/admin/debts', category: secStore),
      SidebarItem(icon: Icons.inventory_2_rounded, label: 'Master Stock Control', route: '/admin/stock', category: secInventory),
      SidebarItem(icon: Icons.warehouse_rounded, label: 'Warehouse Operations', route: '/warehouse', category: secInventory, badgeCount: pendingTransfersCount),
      SidebarItem(icon: Icons.assessment_rounded, label: 'Product Activity Report', route: '/admin/product-report', category: secInventory),
      SidebarItem(icon: Icons.receipt_long_rounded, label: 'Business Expenses', route: '/admin/expenses', category: secFinance),
      SidebarItem(icon: Icons.account_balance_rounded, label: 'GRA Tax Compliance', route: '/admin/tax', category: secFinance),
      SidebarItem(icon: Icons.payments_rounded, label: 'Salary Management', route: '/admin/salaries', category: secFinance),
      SidebarItem(icon: Icons.folder_open_rounded, label: 'Compliance Documents', route: '/admin/documents', category: secFinance),
      SidebarItem(icon: Icons.admin_panel_settings_rounded, label: 'Staff Management', route: '/admin/staff', category: secAdmin),
      SidebarItem(icon: Icons.history_rounded, label: 'Company Recents', route: '/admin/recents', category: secAdmin),
      SidebarItem(icon: Icons.security_update_good_rounded, label: 'System Audit Trail', route: '/admin/audit', category: secAdmin),
      SidebarItem(icon: Icons.build_circle_rounded, label: 'System Maintenance', route: '/admin/maintenance', category: secAdmin),
    ];

    // 1. Admin Module
    if (roles.contains(UserRole.superAdmin) || isAdmin) {
      for (final item in adminItems) {
        // Super Admins always see everything.
        if (roles.contains(UserRole.superAdmin)) {
          items.add(SidebarItem(
            icon: item.icon,
            label: item.label,
            route: item.route,
            isCatchy: user.newlyAddedPermissions.contains(item.route),
            category: item.category,
            badgeCount: item.badgeCount,
          ));
          continue;
        }

        // Logic for regular Admin:
        final bool isSystemTool = item.route == '/admin' || 
                                  item.route == '/admin/tax' ||
                                  item.route == '/admin/documents' ||
                                  item.route == '/admin/salaries' ||
                                  item.route == '/admin/staff' ||
                                  item.route == '/admin/recents' || 
                                  item.route == '/admin/audit' || 
                                  item.route == '/admin/maintenance' ||
                                  item.route == '/admin/settings' ||
                                  item.route == '/admin/stock' ||
                                  item.route == '/warehouse' ||
                                  item.route == '/admin/product-report';
        
        final hasSpecificRestrictions = user.enabledPermissions.isNotEmpty && 
                                         user.enabledPermissions.any((p) => p.startsWith('/admin'));

        if (isSystemTool || !hasSpecificRestrictions || user.enabledPermissions.contains(item.route)) {
          items.add(SidebarItem(
            icon: item.icon,
            label: item.label,
            route: item.route,
            isCatchy: user.newlyAddedPermissions.contains(item.route),
            category: item.category,
            badgeCount: item.badgeCount,
          ));
        }
      }
    } else {
      // Check if non-admin has been granted specific admin duties
      for (final item in adminItems) {
        if (user.enabledPermissions.contains(item.route)) {
          items.add(SidebarItem(
            icon: item.icon,
            label: item.label,
            route: item.route,
            isCatchy: user.newlyAddedPermissions.contains(item.route),
            category: item.category,
            badgeCount: item.badgeCount,
          ));
        }
      }
    }

    // 2. Cashier Module
    final hasCashierAccess = roles.contains(UserRole.superAdmin) || 
                             roles.contains(UserRole.cashier) || 
                             roles.contains(UserRole.admin) || 
                             user.enabledPermissions.any((p) => p == '/cashier' || p.startsWith('/cashier'));
    
    if (hasCashierAccess) {
      items.add(SidebarItem(
        icon: Icons.point_of_sale_rounded, 
        label: 'Point Of Sale', 
        route: '/cashier', 
        isCatchy: user.newlyAddedPermissions.contains('/cashier'),
        category: secStore,
      ));
      
      if (roles.contains(UserRole.cashier)) {
        items.add(SidebarItem(
          icon: Icons.bar_chart_rounded,
          label: 'Daily Sales Report',
          route: '/admin/sales',
          category: secOverview,
        ));
        items.add(SidebarItem(
          icon: Icons.receipt_long_rounded,
          label: 'Business Expenses',
          route: '/admin/expenses',
          category: secFinance,
        ));
      }
    }

    // 3. Warehouse Operations Module Access
    final hasWarehouseAccess = roles.contains(UserRole.superAdmin) || 
                               roles.contains(UserRole.admin) || 
                               user.enabledPermissions.contains('/warehouse');

    if (hasWarehouseAccess) {
      items.add(SidebarItem(
        icon: Icons.warehouse_rounded, 
        label: 'Warehouse Operations', 
        route: '/warehouse', 
        isCatchy: user.newlyAddedPermissions.contains('/warehouse'),
        badgeCount: pendingTransfersCount,
        category: secInventory,
      ));
    }

    // 4. System Access (Always visible to all users)
    items.add(SidebarItem(icon: Icons.info_outline_rounded, label: 'About System', route: '/about', category: secAdmin));
    items.add(SidebarItem(icon: Icons.settings_rounded, label: 'User Settings', route: '/settings', category: secAdmin));

    // Special: Super Admin Root Access
    if (roles.contains(UserRole.superAdmin)) {
      items.add(SidebarItem(icon: Icons.security, label: 'Root Access (Restore)', route: '/admin/super', isCatchy: true, category: secAdmin));
    }

    final uniqueItems = _deduplicateItems(items);
    
    // Sort items by click counts if provided, keeping home routes at the very top, and about/settings at the bottom
    if (clicks != null && clicks.isNotEmpty) {
      uniqueItems.sort((a, b) {
        // 1. Home Routes always at the top
        final aIsHome = a.route == '/admin' || a.route == '/cashier';
        final bIsHome = b.route == '/admin' || b.route == '/cashier';
        if (aIsHome && !bIsHome) return -1;
        if (!aIsHome && bIsHome) return 1;

        // 2. Settings / About always at the bottom
        final aIsBottom = a.route == '/settings' || a.route == '/about' || a.route == '/admin/super';
        final bIsBottom = b.route == '/settings' || b.route == '/about' || b.route == '/admin/super';
        if (aIsBottom && !bIsBottom) return 1;
        if (!aIsBottom && bIsBottom) return -1;

        // 3. Sort by clicks descending
        final aClicks = clicks[a.route] ?? 0;
        final bClicks = clicks[b.route] ?? 0;
        
        if (aClicks != bClicks) {
          return bClicks.compareTo(aClicks);
        }
        
        // 4. Preserve original relative ordering for ties (we just return 0 to maintain stability, though Dart's sort is not guaranteed stable prior to 2.12. In modern Dart it is stable).
        return 0;
      });
    }

    return uniqueItems;
  }

  static List<Map<String, String>> getAllAvailableDuties() {
    return [
      {'route': '/admin', 'label': 'Admin Dashboard'},
      {'route': '/admin/sales', 'label': 'Sales Analytics'},
      {'route': '/admin/expenses', 'label': 'Business Expenses'},
      {'route': '/admin/till', 'label': 'Till & Sales Log (Redirect)'},
      {'route': '/admin/customers', 'label': 'Customer Directory'},
      {'route': '/admin/documents', 'label': 'Compliance Documents'},
      {'route': '/admin/debts', 'label': 'Debt Tracker'},
      {'route': '/admin/stock', 'label': 'Master Stock Control'},
      {'route': '/warehouse', 'label': 'Warehouse Operations Access'},
      {'route': '/admin/product-report', 'label': 'Product Activity Report'},
      {'route': '/admin/salaries', 'label': 'Salary Management'},
      {'route': '/admin/staff', 'label': 'Staff Management'},
      {'route': '/admin/recents', 'label': 'Company Recents'},
      {'route': '/admin/maintenance', 'label': 'System Maintenance'},
      {'route': '/cashier', 'label': 'Point Of Sale Access'},
      {'route': '/settings', 'label': 'System Settings'},
    ];
  }

  static List<SidebarItem> _deduplicateItems(List<SidebarItem> items) {
    final seen = <String>{};
    return items.where((item) => seen.add(item.route)).toList();
  }

  static void navigate(BuildContext context, WidgetRef ref, String route, String currentRoute) {
    if (route == currentRoute) return;
    
    // Record click before navigating
    ref.read(menuClicksProvider.notifier).recordClick(route);
    
    // Ensure we are using the correct Navigator context
    final navigator = Navigator.of(context);
    navigator.pushReplacementNamed(route);
  }

  static String getHomeRoute(UserAccount user) {
    switch (user.activePrimaryRole) {
      case UserRole.admin:
      case UserRole.superAdmin:
        return '/admin';
      case UserRole.cashier:
        return '/cashier';
    }
  }
}

/// A reactive provider for menu items based on the current user
final menuItemsProvider = Provider<List<SidebarItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final pendingCount = ref.watch(pendingIncomingTransfersProvider).length;
  final clicks = ref.watch(menuClicksProvider);
  return MenuService.getMenuItemsForUser(user, pendingTransfersCount: pendingCount, clicks: clicks);
});
