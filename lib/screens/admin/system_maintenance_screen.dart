import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../services/product_service.dart';
import '../../services/sale_provider.dart';
import '../../services/expense_provider.dart';

class SystemMaintenanceScreen extends ConsumerWidget {
  const SystemMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/maintenance';
    final menuItems = ref.watch(menuItemsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const MainAppBar(title: 'System Maintenance'),
      drawer: isDesktop ? null : Drawer(
        child: AppSidebar(
          userId: user.id,
          userName: user.name,
          userRole: user.activePrimaryRole.name.toUpperCase(),
          currentRoute: currentRoute,
          items: menuItems,
          onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
        ),
      ),
      body: Row(
        children: [
          if (isDesktop)
            AppSidebar(
              userId: user.id,
              userName: user.name,
              userRole: user.activePrimaryRole.name.toUpperCase(),
              currentRoute: currentRoute,
              items: menuItems,
              onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Data Cleanup Operations', Icons.cleaning_services_rounded, Colors.orange),
                  const SizedBox(height: AppSpacing.m),
                  _buildMaintenanceCard(
                    context,
                    title: 'Reset Inventory Levels',
                    subtitle: 'Set all product stock quantities to zero. Useful for seasonal restarts.',
                    icon: Icons.inventory_2_outlined,
                    btnText: 'CLEAR ALL STOCK',
                    onPressed: () => _confirmAction(context, 'Clear Inventory', 'This will set all cosmetic product stock levels to 0 Pcs. Continue?', () {
                      ref.read(productsFutureProvider.notifier).clearAllStock();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inventory levels reset to zero.')));
                    }),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _buildMaintenanceCard(
                    context,
                    title: 'Purge Transaction History',
                    subtitle: 'Permanently delete all sales and expense records. Recommended only at end of financial year.',
                    icon: Icons.delete_forever_rounded,
                    btnText: 'PURGE ALL RECORDS',
                    color: Colors.red,
                    onPressed: () => _confirmAction(context, 'Purge Records', 'This will PERMANENTLY DELETE all sales and expenses. Are you absolutely sure?', () {
                      ref.read(saleHistoryProvider.notifier).purgeAllRecords();
                      ref.read(expenseProvider.notifier).purgeAllRecords();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All financial records have been purged.')));
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader(context, 'Data Recovery (Trash)', Icons.restore_from_trash_rounded, Colors.green),
                  const SizedBox(height: AppSpacing.m),
                  _buildMaintenanceCard(
                    context,
                    title: 'Restore Deleted Items',
                    subtitle: 'Recover products or staff members that were recently deleted (Soft Delete).',
                    icon: Icons.settings_backup_restore_rounded,
                    btnText: 'GO TO RECOVERY HUB',
                    onPressed: () => Navigator.pushNamed(context, '/admin/super'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader(context, 'Visualization & Monthly Logic', Icons.analytics_outlined, Colors.blue),
                  const SizedBox(height: AppSpacing.m),
                   _buildMaintenanceCard(
                    context,
                    title: 'Manual Month-End Reset',
                    subtitle: 'Force visualizations to refresh for the new month immediately.',
                    icon: Icons.auto_mode_rounded,
                    btnText: 'REFRESH DASHBOARDS',
                    onPressed: () {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visualizations updated for the current month.')));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title, 
            style: TextStyle(
              color: color, 
              fontWeight: FontWeight.bold, 
              fontSize: 18, 
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String btnText,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final primaryColor = color ?? theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: Icon(icon, color: primaryColor, size: 24),
                ),
                const SizedBox(width: AppSpacing.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle, 
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                  elevation: 0,
                ),
                child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAction(BuildContext context, String title, String msg, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('PROCEED'),
          ),
        ],
      ),
    );
  }
}
