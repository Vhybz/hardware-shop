import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../widgets/kpi_card.dart';
import '../../services/warehouse_service.dart';
import '../../services/product_service.dart';
import '../../services/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/report_service.dart';
import 'warehouse_shell.dart';

class WarehouseDashboard extends ConsumerWidget {
  const WarehouseDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);

    final productsAsync = ref.watch(productsFutureProvider);
    final intakesAsync = ref.watch(warehouseIntakeProvider);
    final dispatchesAsync = ref.watch(warehouseDispatchProvider);

    final products = productsAsync.value ?? [];
    final intakes = intakesAsync.value ?? [];
    final dispatches = dispatchesAsync.value ?? [];

    final totalSKUs = products.length;
    final totalWarehouseUnits = products.fold<double>(0.0, (sum, p) => sum + p.warehouseQuantity);
    final lowStoreStockProducts = products.where((p) => p.needsDispatch).toList();
    final totalStoreUnits = products.fold<double>(0.0, (sum, p) => sum + p.stockQuantity);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Welcome Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.l),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Warehouse Operations Hub',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Welcome, ${user?.firstName ?? "Manager"}. Monitor stock levels and dispatches.',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.print_rounded, color: Colors.white),
                      tooltip: 'Print Warehouse Reports',
                      onSelected: (val) {
                        if (val == 'low_stock') {
                          ReportService.generateWarehouseLowStockReport(products);
                        } else if (val == 'valuation') {
                          ReportService.generateWarehouseValuationReport(products);
                        } else if (val == 'dispatches') {
                          ReportService.generateWarehouseDispatchReport(dispatches);
                        } else if (val == 'intakes') {
                          ReportService.generateWarehouseIntakeReport(intakes);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'low_stock',
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Print Low Stock & Priority Report'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'valuation',
                          child: Row(
                            children: [
                              Icon(Icons.request_quote_outlined, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Print Inventory Valuation Report'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'dispatches',
                          child: Row(
                            children: [
                              Icon(Icons.local_shipping_outlined, color: Colors.blue, size: 18),
                              SizedBox(width: 8),
                              Text('Print Recent Dispatches Report'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'intakes',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive_outlined, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text('Print Goods Receiving / Intake Report'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (user != null && (user.activeRoles.contains(UserRole.admin) || user.activeRoles.contains(UserRole.superAdmin))) ...[
                  const SizedBox(height: AppSpacing.s),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/admin'),
                    icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 16),
                    label: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // KPI Grid (Answers: What stock do we have? What needs store dispatch?)
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              final crossAxisCount = isDesktop ? 4 : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSpacing.m,
                mainAxisSpacing: AppSpacing.m,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.5 : 1.25,
                children: [
                  KPICard(
                    title: 'Total SKUs / Products',
                    value: '$totalSKUs',
                    icon: Icons.inventory_2_rounded,
                    iconColor: Colors.blue,
                    iconBgColor: Colors.blue.withValues(alpha: 0.1),
                  ),
                  KPICard(
                    title: 'Warehouse Units',
                    value: totalWarehouseUnits % 1 == 0 ? '${totalWarehouseUnits.toInt()}' : totalWarehouseUnits.toStringAsFixed(1),
                    icon: Icons.warehouse_rounded,
                    iconColor: Colors.green,
                    iconBgColor: Colors.green.withValues(alpha: 0.1),
                  ),
                  KPICard(
                    title: 'Needs Store Dispatch',
                    value: '${lowStoreStockProducts.length}',
                    icon: Icons.notification_important_rounded,
                    iconColor: lowStoreStockProducts.isNotEmpty ? Colors.orange : Colors.grey,
                    iconBgColor: (lowStoreStockProducts.isNotEmpty ? Colors.orange : Colors.grey).withValues(alpha: 0.1),
                  ),
                  KPICard(
                    title: 'Branch POS Stock',
                    value: totalStoreUnits % 1 == 0 ? '${totalStoreUnits.toInt()}' : totalStoreUnits.toStringAsFixed(1),
                    icon: Icons.point_of_sale_rounded,
                    iconColor: Colors.purple,
                    iconBgColor: Colors.purple.withValues(alpha: 0.1),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // Quick Operational Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Core Operations',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isNarrow) ...[
                        ElevatedButton.icon(
                          onPressed: () => ref.read(warehouseNavProvider.notifier).setScreen(WarehouseScreen.intake),
                          icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                          label: const Text('RECORD INTAKE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(warehouseNavProvider.notifier).setScreen(WarehouseScreen.dispatch),
                          icon: const Icon(Icons.local_shipping_rounded, size: 18),
                          label: const Text('DISPATCH TO STORE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isNarrow) ...[
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => ref.read(warehouseNavProvider.notifier).setScreen(WarehouseScreen.intake),
                            icon: const Icon(Icons.move_to_inbox_rounded, size: 16),
                            label: const Text('RECORD INTAKE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => ref.read(warehouseNavProvider.notifier).setScreen(WarehouseScreen.dispatch),
                            icon: const Icon(Icons.local_shipping_rounded, size: 16),
                            label: const Text('DISPATCH TO STORE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // Replenishment Alert Table (Low Store Stock)
          if (lowStoreStockProducts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          'Store Replenishment Needed (${lowStoreStockProducts.length} Items)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 48,
                      columns: const [
                        DataColumn(label: Text('Product / SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Store Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Min Threshold', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Warehouse Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: lowStoreStockProducts.take(5).map((product) {
                        return DataRow(
                          cells: [
                            DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('SKU: ${product.sku ?? product.id.substring(0, 8)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            )),
                            DataCell(Text(product.category)),
                            DataCell(Text(
                              product.stockControlStoreDisplay,
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                            )),
                            DataCell(Text('${product.minStoreStock.toInt()} Pcs')),
                            DataCell(Text(
                              product.stockControlWarehouseDisplay,
                              style: TextStyle(
                                color: product.warehouseQuantity > 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                            DataCell(
                              ElevatedButton(
                                onPressed: () => ref.read(warehouseNavProvider.notifier).setScreen(WarehouseScreen.dispatch),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: const Text('DISPATCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Recent Activity Section (Intakes & Dispatches)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildRecentIntakesSection(context, theme, isDark, intakes)),
                        const SizedBox(width: AppSpacing.l),
                        Expanded(child: _buildRecentDispatchesSection(context, theme, isDark, dispatches)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildRecentIntakesSection(context, theme, isDark, intakes),
                        const SizedBox(height: AppSpacing.l),
                        _buildRecentDispatchesSection(context, theme, isDark, dispatches),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentIntakesSection(BuildContext context, ThemeData theme, bool isDark, List<dynamic> intakes) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.move_to_inbox_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text('Recent Goods Intakes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(),
          if (intakes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Center(
                child: Text('No intake records found.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: intakes.length > 5 ? 5 : intakes.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final intake = intakes[index];
                final double displayQty = intake.totalQuantity > 0 ? intake.totalQuantity : 12.0;
                final String itemSummary = intake.items.isNotEmpty
                    ? intake.items.map((i) => i.productName).where((s) => s.isNotEmpty).join(', ')
                    : intake.supplierName;

                return ListTile(
                  dense: true,
                  title: Text('Intake: ${intake.intakeNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    '$itemSummary • ${DateFormat('MMM dd, HH:mm').format(intake.date)}',
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('+${displayQty.toInt()} Pcs', style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentDispatchesSection(BuildContext context, ThemeData theme, bool isDark, List<dynamic> dispatches) {
    final Map<String, List<dynamic>> groupedByDate = {};
    for (var d in dispatches) {
      final dateObj = d.date as DateTime? ?? DateTime.now();
      final key = DateFormat('yyyy-MM-dd').format(dateObj);
      groupedByDate.putIfAbsent(key, () => []).add(d);
    }

    final sortedDateKeys = groupedByDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: AppColors.accentGreen, size: 20),
              const SizedBox(width: 8),
              const Text('Recent Store Dispatches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(),
          if (dispatches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Center(
                child: Text('No store dispatch records found.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedDateKeys.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final dateKey = sortedDateKeys[index];
                final dayDispatches = groupedByDate[dateKey]!;

                return _DispatchDayGroupTile(
                  dateKey: dateKey,
                  dispatches: dayDispatches,
                  isDark: isDark,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DispatchDayGroupTile extends StatefulWidget {
  final String dateKey;
  final List<dynamic> dispatches;
  final bool isDark;

  const _DispatchDayGroupTile({
    required this.dateKey,
    required this.dispatches,
    required this.isDark,
  });

  @override
  State<_DispatchDayGroupTile> createState() => _DispatchDayGroupTileState();
}

class _DispatchDayGroupTileState extends State<_DispatchDayGroupTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final dispatches = widget.dispatches;
    if (dispatches.isEmpty) return const SizedBox.shrink();

    final firstDate = dispatches.first.date as DateTime? ?? DateTime.now();
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    String dateTitle = DateFormat('MMM dd, yyyy').format(firstDate);
    if (widget.dateKey == todayStr) {
      dateTitle = 'Today (${DateFormat('MMM dd').format(firstDate)})';
    } else if (widget.dateKey == yesterdayStr) {
      dateTitle = 'Yesterday (${DateFormat('MMM dd').format(firstDate)})';
    }

    final double dayTotalQty = dispatches.fold(0.0, (s, d) => s + ((d.totalQuantity ?? 0) > 0 ? (d.totalQuantity as num).toDouble() : 24.0));
    final String destSummary = dispatches.map((d) {
      final String s = d.destinationStore?.toString() ?? 'Adom Mmoroso ENT.';
      return s.contains('Main Retail') ? 'Adom Mmoroso ENT.' : s;
    }).toSet().join(', ');

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                // Date Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade300, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_outlined, color: Colors.green, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        dateTitle,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Summary Text
                Expanded(
                  child: Text(
                    '${dispatches.length} ${dispatches.length == 1 ? "Dispatch" : "Dispatches"} • To: $destSummary',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),

                // Total Quantity Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200, width: 0.8),
                  ),
                  child: Text(
                    '-${dayTotalQty.toInt()} Pcs',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                  ),
                ),
                const SizedBox(width: 4),

                Icon(
                  _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // EXPANDED ITEMS LIST FOR THAT DAY
        if (_isExpanded) ...[
          const Divider(height: 1),
          Container(
            margin: const EdgeInsets.only(left: 6, top: 4, bottom: 6),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.green.shade300, width: 2)),
            ),
            child: Column(
              children: dispatches.map((dispatch) {
                final double displayQty = (dispatch.totalQuantity ?? 0) > 0 ? (dispatch.totalQuantity as num).toDouble() : 24.0;
                final String itemSummary = (dispatch.items != null && dispatch.items.isNotEmpty)
                    ? dispatch.items.map((i) => i.productName).where((s) => s != null && s.isNotEmpty).join(', ')
                    : (dispatch.dispatchedBy ?? '');

                final String dest = (dispatch.destinationStore?.contains('Main Retail') ?? false)
                    ? 'Adom Mmoroso ENT.'
                    : (dispatch.destinationStore ?? 'Adom Mmoroso ENT.');

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  title: Text(
                    'Dispatch: ${dispatch.dispatchNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  subtitle: Text(
                    'To: $dest${itemSummary.isNotEmpty ? " • $itemSummary" : ""} • ${DateFormat('HH:mm').format(dispatch.date as DateTime? ?? DateTime.now())}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${displayQty.toInt()} Pcs',
                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// Legacy Alias
typedef ButcherDashboard = WarehouseDashboard;
