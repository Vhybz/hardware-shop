import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/main_app_bar.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/role_pop_scope.dart';
import '../../services/birthday_service.dart';
import '../../widgets/passcode_guard.dart';
import 'warehouse_dashboard.dart';
import 'warehouse_intake_screen.dart';
import 'warehouse_goods_screen.dart';
import 'warehouse_dispatch_screen.dart';
import '../profile_screen.dart';

enum WarehouseScreen {
  dashboard,
  intake,
  goods,
  dispatch,
  profile,
}

final warehouseNavProvider = StateNotifierProvider<WarehouseNavNotifier, WarehouseScreen>((ref) {
  return WarehouseNavNotifier();
});

class WarehouseNavNotifier extends StateNotifier<WarehouseScreen> {
  WarehouseNavNotifier() : super(WarehouseScreen.dashboard);

  void setScreen(WarehouseScreen screen) {
    state = screen;
  }
}

class WarehouseShell extends ConsumerWidget {
  const WarehouseShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        BirthdayService.checkAndShowBirthdayWish(context, user);
      }
    });

    final currentScreen = ref.watch(warehouseNavProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final theme = Theme.of(context);

    return RolePopScope(
      currentRoute: '/warehouse',
      child: PopScope(
        canPop: currentScreen == WarehouseScreen.dashboard,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (currentScreen != WarehouseScreen.dashboard) {
            ref.read(warehouseNavProvider.notifier).setScreen(WarehouseScreen.dashboard);
          }
        },
        child: PasscodeGuard(
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: MainAppBar(
              title: _getScreenTitle(currentScreen),
              onProfileTap: () => ref.read(warehouseNavProvider.notifier).setScreen(WarehouseScreen.profile),
            ),
            drawer: isDesktop ? null : Drawer(child: _buildSidebar(ref, currentScreen, user, context)),
            body: Row(
              children: [
                if (isDesktop) _buildSidebar(ref, currentScreen, user, context),
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: _buildContent(currentScreen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getScreenTitle(WarehouseScreen screen) {
    switch (screen) {
      case WarehouseScreen.dashboard: return 'Warehouse Operations Dashboard';
      case WarehouseScreen.intake: return 'Goods Intake Workflow';
      case WarehouseScreen.goods: return 'Warehouse Goods & Inventory';
      case WarehouseScreen.dispatch: return 'Store Replenishment Dispatch';
      case WarehouseScreen.profile: return 'Personal Profile';
    }
  }

  Widget _buildSidebar(WidgetRef ref, WarehouseScreen current, UserAccount user, BuildContext context) {
    const currentRoute = '/warehouse';
    final baseMenuItems = ref.watch(menuItemsProvider);
    const secInventory = 'Inventory & Supply Chain';
    final warehouseSubItems = [
      SidebarItem(icon: Icons.dashboard_rounded, label: 'Warehouse Dashboard', route: 'warehouse:dashboard', category: secInventory),
      SidebarItem(icon: Icons.move_to_inbox_rounded, label: 'Goods Intake', route: 'warehouse:intake', category: secInventory),
      SidebarItem(icon: Icons.inventory_2_rounded, label: 'Warehouse Goods', route: 'warehouse:goods', category: secInventory),
      SidebarItem(icon: Icons.local_shipping_rounded, label: 'Store Dispatch', route: 'warehouse:dispatch', category: secInventory),
    ];

    final menuItems = [
      ...warehouseSubItems,
      ...baseMenuItems.where((item) => item.route != '/warehouse'),
    ];

    return AppSidebar(
      userId: user.id,
      userName: user.name,
      userRole: user.activePrimaryRole.name.toUpperCase(),
      currentRoute: 'warehouse:${current.name}',
      items: menuItems,
      onTap: (route) {
        if (route.startsWith('warehouse:')) {
          final screenStr = route.split(':')[1];
          final screen = WarehouseScreen.values.firstWhere(
            (e) => e.name == screenStr,
            orElse: () => WarehouseScreen.dashboard,
          );
          ref.read(warehouseNavProvider.notifier).setScreen(screen);
        } else {
          MenuService.navigate(context, ref, route, currentRoute);
        }
      },
    );
  }

  Widget _buildContent(WarehouseScreen screen) {
    switch (screen) {
      case WarehouseScreen.dashboard: return const WarehouseDashboard();
      case WarehouseScreen.intake: return const WarehouseIntakeScreen();
      case WarehouseScreen.goods: return const WarehouseGoodsScreen();
      case WarehouseScreen.dispatch: return const WarehouseDispatchScreen();
      case WarehouseScreen.profile: return const ProfileView();
    }
  }
}

// Legacy alias for compatibility
typedef ButcherShell = WarehouseShell;
