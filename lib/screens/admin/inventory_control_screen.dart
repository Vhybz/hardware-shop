import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/camera_barcode_scanner_dialog.dart';
import '../../core/constants.dart';
import '../../widgets/main_app_bar.dart';
import '../../services/product_service.dart';
import '../../services/warehouse_service.dart';
import '../../models/product.dart';
import '../../core/uuid_utils.dart';
import '../../core/utils.dart';
import 'package:intl/intl.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/passcode_guard.dart';
import '../../widgets/app_cached_image.dart';

import '../../services/customer_provider.dart';
import '../../services/product_seeder.dart';
import '../../services/app_settings_provider.dart';
import '../../widgets/role_pop_scope.dart';

class InventoryControlScreen extends ConsumerStatefulWidget {
  const InventoryControlScreen({super.key});

  @override
  ConsumerState<InventoryControlScreen> createState() => _InventoryControlScreenState();
}

class _InventoryControlScreenState extends ConsumerState<InventoryControlScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final activeRole = user.activePrimaryRole;
    final isAdmin = activeRole == UserRole.admin || activeRole == UserRole.superAdmin;

    final theme = Theme.of(context);
    final productsAsync = ref.watch(productsFutureProvider);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/stock';

    // Safety: Reset selected category if it no longer exists after deletions
    if (productsAsync.hasValue) {
      final products = productsAsync.value!;
      final availableCategories = ['All', ...products.where((p) => !p.isDeleted).map((p) => _normalizeCategory(p)).toSet()];
      if (!availableCategories.contains(_selectedCategory)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCategory = 'All');
        });
      }
    }

    return RolePopScope(
      currentRoute: currentRoute,
      child: PasscodeGuard(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: const MainAppBar(title: 'Inventory Control', showMenuButton: true),
          drawer: isDesktop
              ? null
              : Drawer(
                  child: AppSidebar(
                    userId: user.id,
                    userName: user.name,
                    userRole: user.activePrimaryRole.name.toUpperCase(),
                    currentRoute: currentRoute,
                    items: MenuService.getMenuItemsForUser(user),
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
                  items: MenuService.getMenuItemsForUser(user),
                  onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
                ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, ref, productsAsync.value ?? [], isAdmin: isAdmin),
                        const SizedBox(height: AppSpacing.l),
                        _buildFilters(theme, productsAsync.value ?? []),
                        const SizedBox(height: AppSpacing.l),
                        productsAsync.when(
                          data: (products) {
                            final activeProducts = products
                                .where((p) => !p.isDeleted)
                                .where((p) {
                                  final normCat = _normalizeCategory(p);
                                  return _selectedCategory == 'All' || normCat == _selectedCategory;
                                })
                                .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                               p.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                               (p.sku != null && p.sku!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
                                               p.id.toLowerCase().contains(_searchQuery.toLowerCase()))
                                .toList();

                            // Sort: Priced products and higher quantity first
                            activeProducts.sort((a, b) {
                              // 1. Priced products (price > 0) come first
                              final bool aPriced = a.retailPrice > 0;
                              final bool bPriced = b.retailPrice > 0;
                              if (aPriced != bPriced) return aPriced ? -1 : 1;
                              
                              // 2. Products with higher quantity come first
                              return b.stockQuantity.compareTo(a.stockQuantity);
                            });
                            
                            if (activeProducts.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Text('No products match criteria', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                                ),
                              );
                            }
                            return _buildProductGrid(context, activeProducts, ref, isAdmin: isAdmin);
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, _) => Center(child: Text('Error: $err')),
                        ),
                        // Add padding for bottom navigation bars
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: isAdmin ? SafeArea(
            child: FloatingActionButton.extended(
              onPressed: () => _showAddProductDialog(context, ref),
              backgroundColor: theme.colorScheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add New Product', style: TextStyle(color: Colors.white)),
            ),
          ) : null,
        ),
      ),
    );
  }

  void _scanBarcodeToUpdateStock(BuildContext context, WidgetRef ref) {
    CameraBarcodeScannerDialog.show(
      context,
      title: 'Scan Product Barcode to Update Stock',
      onScanned: (rawValue) {
        final products = ref.read(productsFutureProvider).value ?? [];
        final matched = products.where((p) => !p.isDeleted).where((p) {
          final skuMatch = p.sku != null && p.sku!.toLowerCase() == rawValue.trim().toLowerCase();
          final idMatch = p.id.toLowerCase() == rawValue.trim().toLowerCase();
          final nameMatch = p.name.toLowerCase() == rawValue.trim().toLowerCase();
          return skuMatch || idMatch || nameMatch;
        }).firstOrNull;

        if (matched != null) {
          _showUpdateStockDialog(context, ref, matched);
          return 'Found: ${matched.name}';
        } else {
          return 'No product found for barcode "$rawValue"';
        }
      },
    );
  }

  void _handleBarcodeSearchSubmit(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final products = ref.read(productsFutureProvider).value ?? [];
    final matched = products.where((p) => !p.isDeleted).where((p) {
      final skuMatch = p.sku != null && p.sku!.toLowerCase() == clean.toLowerCase();
      final idMatch = p.id.toLowerCase() == clean.toLowerCase();
      final nameMatch = p.name.toLowerCase() == clean.toLowerCase();
      return skuMatch || idMatch || nameMatch;
    }).firstOrNull;

    if (matched != null) {
      _showUpdateStockDialog(context, ref, matched);
    }
  }

  Widget _buildFilters(ThemeData theme, List<Product> products) {
    final categories = ['All', ...products.map((p) => _normalizeCategory(p)).toSet()];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 650;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                onSubmitted: _handleBarcodeSearchSubmit,
                decoration: InputDecoration(
                  hintText: 'Search or scan barcode / SKU...',
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined),
                        tooltip: 'Scan with Camera',
                        onPressed: () => _scanBarcodeToUpdateStock(context, ref),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        ),
                    ],
                  ),
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.m),
              DropdownButtonFormField<String>(
                initialValue: categories.contains(_selectedCategory) ? _selectedCategory : 'All',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Sort Category',
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                ),
                items: categories.map((c) => DropdownMenuItem(
                  value: c, 
                  child: Text(c, overflow: TextOverflow.ellipsis, maxLines: 1),
                )).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                onSubmitted: _handleBarcodeSearchSubmit,
                decoration: InputDecoration(
                  hintText: 'Search or scan barcode / SKU...',
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined),
                        tooltip: 'Scan with Camera',
                        onPressed: () => _scanBarcodeToUpdateStock(context, ref),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        ),
                    ],
                  ),
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                initialValue: categories.contains(_selectedCategory) ? _selectedCategory : 'All',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Sort Category',
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                ),
                items: categories.map((c) => DropdownMenuItem(
                  value: c, 
                  child: Text(c, overflow: TextOverflow.ellipsis, maxLines: 1),
                )).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, List<Product> products, {required bool isAdmin}) {
    final theme = Theme.of(context);

    final actionButtons = [
      if (isAdmin) ...[
        PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'unlimited') {
              _showBulkUnlimitedDialog(context, ref, products, true);
            } else if (val == 'fixed') {
              _showBulkUnlimitedDialog(context, ref, products, false);
            }
          },
          child: OutlinedButton.icon(
            onPressed: null, // Let PopupMenuButton handle it
            icon: const Icon(Icons.settings_suggest_outlined, size: 18),
            label: const Text('Bulk Actions', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'unlimited',
              child: Row(
                children: [
                  Icon(Icons.all_inclusive, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Set ALL to Unlimited'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'fixed',
              child: Row(
                children: [
                  Icon(Icons.pin, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Set ALL to Fixed Qty'),
                ],
              ),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () => _showPromotionDialog(context, ref, products),
          icon: const Icon(Icons.campaign_outlined, size: 18),
          label: const Text('Promotions', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade800,
            side: BorderSide(color: Colors.orange.shade800),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/warehouse'),
          icon: const Icon(Icons.warehouse_outlined, size: 18),
          label: const Text('Warehouse Hub', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/admin/product-report'),
          icon: const Icon(Icons.assessment_outlined, size: 18),
          label: const Text('Activity Report', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Catalog & Stock Defaults'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose an action:'),
                    SizedBox(height: 12),
                    Text('• Load Catalog: Populates default hardware & building materials categories with 0.0 Pcs initial stock.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SizedBox(height: 6),
                    Text('• Reset All to 0 Pcs: Sets ALL existing products store & warehouse stock to 0.0 Pcs.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(productSeederProvider).seedProducts();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catalog loaded with 0.0 Pcs stock defaults!'), backgroundColor: Colors.green));
                      }
                    },
                    child: const Text('LOAD CATALOG (0 PCS)'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(productSeederProvider).resetAllStockToZero();
                      await ref.read(productSeederProvider).seedProducts();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ All product stock quantities reset to 0.0 Pcs!'), backgroundColor: Colors.green));
                      }
                    },
                    child: const Text('RESET ALL TO 0 PCS'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Load Defaults', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _showManageCategoriesDialog(context, ref, products),
          icon: const Icon(Icons.category_outlined, size: 18),
          label: const Text('Manage Categories', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ]
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 950;

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Master Stock List', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text('Manage products, pricing, and stock levels', 
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (actionButtons.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.m),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actionButtons,
                ),
              ],
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Master Stock List', 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text('Manage products, pricing, and stock levels', 
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (actionButtons.isNotEmpty)
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actionButtons,
                ),
              ),
          ],
        );
      },
    );
  }

  void _showBulkUnlimitedDialog(BuildContext context, WidgetRef ref, List<Product> products, bool isUnlimited) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUnlimited ? 'Set All to Unlimited?' : 'Set All to Fixed Qty?'),
        content: Text(isUnlimited 
          ? 'This will make every product in the catalog "Unlimited", meaning sales will not decrease the current stock levels. Continue?'
          : 'This will make every product follow "Fixed" stock, where sales will subtract from the defined quantity. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              ref.read(productsFutureProvider.notifier).setUnlimitedStatus(isUnlimited);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('All products updated to ${isUnlimited ? "Unlimited" : "Fixed"} stock.'))
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: isUnlimited ? Colors.blue : Colors.green, foregroundColor: Colors.white),
            child: const Text('PROCEED'),
          ),
        ],
      ),
    );
  }

  void _showPromotionDialog(BuildContext context, WidgetRef ref, List<Product> products, {Product? initialProduct}) {
    final formKey = GlobalKey<FormState>();
    final promoSearchController = TextEditingController();
    final percentageController = TextEditingController(
      text: initialProduct != null 
        ? (initialProduct.discountPercentage % 1 == 0 
            ? initialProduct.discountPercentage.toInt().toString() 
            : initialProduct.discountPercentage.toString())
        : ''
    );
    final theme = Theme.of(context);
    DateTime? startDate = initialProduct?.promoStartDate;
    DateTime? endDate = initialProduct?.promoEndDate;
    PromoTarget selectedTarget = initialProduct?.promoTarget ?? PromoTarget.both;
    PromoCustomerTarget selectedCustomerTarget = initialProduct?.promoCustomerTarget ?? PromoCustomerTarget.all;
    String? selectedCustomerId = initialProduct?.targetCustomerId;
    
    final selectedIds = <String>{};
    if (initialProduct != null) {
      selectedIds.add(initialProduct.id);
    } else {
      for (var p in products) {
        selectedIds.add(p.id);
      }
    }

    final customPriceControllers = <String, TextEditingController>{};
    final customPercentageControllers = <String, TextEditingController>{};
    final productManuallyEdited = <String, bool>{};

    for (var p in products) {
      customPriceControllers[p.id] = TextEditingController();
      customPercentageControllers[p.id] = TextEditingController();
      productManuallyEdited[p.id] = false;
    }

    void updatePricesFromGlobal() {
      final globalPercentage = double.tryParse(percentageController.text) ?? 0.0;
      for (var p in products) {
        if (productManuallyEdited[p.id] != true) {
          final newPrice = p.retailPrice * (1 - (globalPercentage / 100));
          final newText = newPrice.toStringAsFixed(2);
          if (customPriceControllers[p.id]!.text != newText) {
             customPriceControllers[p.id]!.text = newText;
          }
          final newPctText = globalPercentage.toStringAsFixed(1);
          if (customPercentageControllers[p.id]!.text != newPctText) {
             customPercentageControllers[p.id]!.text = newPctText;
          }
        }
      }
    }

    updatePricesFromGlobal();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          
          percentageController.addListener(() {
             setState(() {
                updatePricesFromGlobal();
             });
          });

          final searchQuery = promoSearchController.text.trim().toLowerCase();
          final filteredProducts = searchQuery.isEmpty
              ? products
              : products.where((p) {
                  final name = p.name.toLowerCase();
                  final category = p.category.toLowerCase();
                  final unit = p.unit.toLowerCase();
                  final id = p.id.toLowerCase();
                  final branch = p.branchCode?.toLowerCase() ?? '';
                  final retail = p.retailPrice.toString();
                  final wholesale = p.wholesalePrice.toString();
                  return name.contains(searchQuery) ||
                      category.contains(searchQuery) ||
                      unit.contains(searchQuery) ||
                      id.contains(searchQuery) ||
                      branch.contains(searchQuery) ||
                      retail.contains(searchQuery) ||
                      wholesale.contains(searchQuery);
                }).toList();

          final allFilteredSelected = filteredProducts.isNotEmpty &&
              filteredProducts.every((p) => selectedIds.contains(p.id));

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
            title: Row(
              children: [
                const Icon(Icons.campaign_outlined, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(child: Text('Run Promotion', style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      TextFormField(
                        controller: percentageController,
                        decoration: const InputDecoration(
                          labelText: 'Discount Percentage (%)',
                          hintText: 'e.g. 10 or 12.5',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0 || n > 100) return 'Invalid % (0.1 - 100)';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<PromoTarget>(
                        initialValue: selectedTarget,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Promotion Target'),
                        items: const [
                          DropdownMenuItem(value: PromoTarget.both, child: Text('Both Retail & Wholesale', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: PromoTarget.retail, child: Text('Retail Only', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: PromoTarget.wholesale, child: Text('Wholesale Only', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => selectedTarget = v!),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<PromoCustomerTarget>(
                        initialValue: selectedCustomerTarget,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Customer Eligibility'),
                        items: const [
                          DropdownMenuItem(value: PromoCustomerTarget.all, child: Text('All Customers (Public)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: PromoCustomerTarget.regularsOnly, child: Text('Regulars/Favorites Only', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: PromoCustomerTarget.specialOnly, child: Text('Special Customers (VIPs) Only', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: PromoCustomerTarget.specificPerson, child: Text('Specific Person (One Customer)', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => selectedCustomerTarget = v!),
                      ),
                      if (selectedCustomerTarget == PromoCustomerTarget.specificPerson) ...[
                        const SizedBox(height: AppSpacing.m),
                        Builder(
                          builder: (context) {
                            final allCustomers = ref.watch(customerProvider);
                            return DropdownButtonFormField<String>(
                              initialValue: selectedCustomerId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Special Person / Customer',
                                prefixIcon: Icon(Icons.person_pin_circle_rounded),
                              ),
                              items: allCustomers.map((c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Text('${c.name} (${c.phone})', overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (val) => setState(() => selectedCustomerId = val),
                              validator: (val) => (selectedCustomerTarget == PromoCustomerTarget.specificPerson && (val == null || val.isEmpty)) ? 'Please select a customer' : null,
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.m),
                      InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: (startDate != null && endDate != null) 
                              ? DateTimeRange(start: startDate!, end: endDate!)
                              : DateTimeRange(start: DateTime.now(), end: DateTime.now().add(const Duration(days: 7))),
                          );
                          if (picked != null) {
                            setState(() {
                              startDate = picked.start;
                              endDate = picked.end;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: startDate == null ? Colors.grey : theme.colorScheme.primary),
                            borderRadius: BorderRadius.circular(AppRadius.s),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.date_range, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  startDate == null 
                                    ? 'Select Promotion Dates (Required)' 
                                    : '${DateFormat('MMM dd').format(startDate!)} - ${DateFormat('MMM dd').format(endDate!)}',
                                  style: TextStyle(
                                    color: startDate == null ? Colors.grey : theme.colorScheme.onSurface,
                                    fontWeight: startDate == null ? FontWeight.normal : FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      const Divider(),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Select Products (${selectedIds.length}/${products.length}):', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (allFilteredSelected) {
                                  for (var p in filteredProducts) {
                                    selectedIds.remove(p.id);
                                  }
                                } else {
                                  for (var p in filteredProducts) {
                                    selectedIds.add(p.id);
                                  }
                                }
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              searchQuery.isEmpty
                                  ? (allFilteredSelected ? 'Deselect All' : 'Select All')
                                  : (allFilteredSelected ? 'Deselect Visible' : 'Select Visible'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: promoSearchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name, category, code, price...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: promoSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    promoSearchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.s),
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(AppRadius.s),
                        ),
                        child: filteredProducts.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No products match "$searchQuery"',
                                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(4),
                                itemCount: filteredProducts.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final p = filteredProducts[index];
                                  final isSelected = selectedIds.contains(p.id);

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          selectedIds.remove(p.id);
                                        } else {
                                          selectedIds.add(p.id);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(AppRadius.s),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? theme.colorScheme.primary.withValues(alpha: 0.08) 
                                            : theme.cardColor,
                                        borderRadius: BorderRadius.circular(AppRadius.s),
                                        border: Border.all(
                                          color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.5),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      if (val == true) {
                                                        selectedIds.add(p.id);
                                                      } else {
                                                        selectedIds.remove(p.id);
                                                      }
                                                    });
                                                  },
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  activeColor: theme.colorScheme.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      p.name,
                                                      style: TextStyle(
                                                        fontSize: 13, 
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                        color: theme.colorScheme.onSurface,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      '${p.category} • Current: ₵${p.retailPrice.toStringAsFixed(2)}',
                                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (isSelected) ...[
                                            const SizedBox(height: 8),
                                            Wrap(
                                              alignment: WrapAlignment.end,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                Text(
                                                  '₵${p.retailPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 72,
                                                  height: 32,
                                                  child: TextField(
                                                    controller: customPercentageControllers[p.id],
                                                    decoration: InputDecoration(
                                                      suffixText: '% off',
                                                      suffixStyle: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(4),
                                                        borderSide: const BorderSide(color: Colors.green, width: 1.5),
                                                      ),
                                                    ),
                                                    style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                                                    textAlign: TextAlign.right,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                    ],
                                                    onChanged: (val) {
                                                      productManuallyEdited[p.id] = true;
                                                      final newPct = double.tryParse(val) ?? 0.0;
                                                      final newPrice = p.retailPrice * (1 - (newPct / 100));
                                                      customPriceControllers[p.id]!.text = newPrice.toStringAsFixed(2);
                                                    },
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 85,
                                                  height: 32,
                                                  child: TextField(
                                                    controller: customPriceControllers[p.id],
                                                    decoration: InputDecoration(
                                                      prefixText: '₵',
                                                      prefixStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                      labelText: 'Price',
                                                      labelStyle: const TextStyle(fontSize: 10),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(4),
                                                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                                                      ),
                                                    ),
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                    textAlign: TextAlign.right,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                                    ],
                                                    onChanged: (val) {
                                                      productManuallyEdited[p.id] = true;
                                                      final currentPrice = double.tryParse(val) ?? p.retailPrice;
                                                      final discount = p.retailPrice > 0 ? ((p.retailPrice - currentPrice) / p.retailPrice) * 100 : 0.0;
                                                      customPercentageControllers[p.id]!.text = discount.toStringAsFixed(1);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actionsOverflowButtonSpacing: 8,
          actionsAlignment: MainAxisAlignment.end,
          actions: [
              TextButton(
                onPressed: () {
                  ref.read(productsFutureProvider.notifier).clearPromotions();
                  Navigator.pop(context);
                },
                child: const Text('Clear All Promos', style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
              ElevatedButton(
                onPressed: (selectedIds.isEmpty || startDate == null || endDate == null) ? null : () {
                  if (formKey.currentState!.validate()) {
                    final percentage = double.tryParse(percentageController.text) ?? 0;
                    
                    final individualPercentages = <String, double>{};
                    for (var pId in selectedIds) {
                      if (productManuallyEdited[pId] == true) {
                         final customPct = double.tryParse(customPercentageControllers[pId]!.text) ?? 0.0;
                         individualPercentages[pId] = customPct > 0 ? customPct : 0;
                      }
                    }

                    ref.read(productsFutureProvider.notifier).applyPromotion(
                      percentage, 
                      startDate!, 
                      endDate!, 
                      selectedTarget,
                      selectedCustomerTarget,
                      selectedIds: selectedIds.toList(),
                      individualPercentages: individualPercentages,
                      targetCustomerId: selectedCustomerTarget == PromoCustomerTarget.specificPerson ? selectedCustomerId : null,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text('Apply to ${selectedIds.length} Items', style: const TextStyle(fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, WidgetRef ref) {
    final products = ref.read(productsFutureProvider).value ?? [];
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final retailPriceController = TextEditingController();
    final wholesalePriceController = TextEditingController();
    final costPriceController = TextEditingController();
    final stockController = TextEditingController(text: '0');
    final pcsPerPackController = TextEditingController(text: '12');
    final packsPerBoxController = TextEditingController(text: '10');
    final alertThresholdController = TextEditingController(text: '2');
    final otherCategoryController = TextEditingController();
    final customNameController = TextEditingController();
    final theme = Theme.of(context);

    String selectedCategory = 'Building Materials';
    String? selectedProductName;
    WeightUnit selectedUnit = WeightUnit.pcs;
    WeightUnit alertUnit = WeightUnit.box; // Boxes default as requested
    bool hasBarcode = true;
    bool hasPacks = false;
    bool hasBoxes = false;
    bool isUnlimited = false;
    bool allowRetail = true;
    bool allowWholesale = true;

    final Map<String, List<String>> categoryProductMap = {
      'Building Materials': [
        'Cement', 'Sand', 'Stones', 'Blocks', 'Mortar', 'Lime', 'Tile Adhesive', 'Grout', 'Other'
      ],
      'Steel & Rebar': [
        'Iron Rods', 'BRC Mesh', 'Binding Wire', 'Steel Pipes', 'Angle Bars', 'Flat Bars', 'Other'
      ],
      'Plumbing & PVC': [
        'PVC Pipes', 'Pipe Fittings', 'Valves', 'Water Tanks', 'Taps', 'Sink Waste', 'Flexi Hoses', 'Other'
      ],
      'Electricals': [
        'Electrical Cables', 'Switches', 'Sockets', 'Circuit Breakers', 'Conduit Pipes', 'LED Bulbs', 'DB Boards', 'Other'
      ],
      'Paints & Finishes': [
        'Emulsion Paint', 'Oil Paint', 'Undercoat Primer', 'Thinner', 'Paint Rollers', 'Brushes', 'Sandpaper', 'Other'
      ],
      'Roofing & Timber': [
        'Roofing Sheets', 'Roofing Nails', 'Timber Battens', 'Plywood', 'Felt', 'Ridge Caps', 'Other'
      ],
      'Tools & Fasteners': [
        'Hammers', 'Trowels', 'Tape Measures', 'Nails', 'Screws', 'Bolts & Nuts', 'Drill Bits', 'Safety Helmets / Boots', 'Other'
      ],
      'Other': ['Custom Entry']
    };

    final existingCategories = products.map((p) => _normalizeCategory(p)).toSet();
    final List<String> categories = categoryProductMap.keys.toList();
    for (var cat in existingCategories) {
      if (!categories.contains(cat)) {
        categories.insert(categories.length - 1, cat);
      }
    }

    Uint8List? imageBytes;
    String? imageName;
    bool isUploading = false;

    final standardSizes = ['Big', 'Medium', 'Small', 'Mini', 'Large', 'Extra Large', 'Custom'];
    bool hasSize = false;
    String selectedSize = 'Medium';
    final customSizeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Container(
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add New Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Enter product details for the shop catalog', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.all(AppSpacing.l),
          content: Form(
            key: formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Center(
                  child: InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 80,
                      );
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setState(() {
                          imageBytes = bytes;
                          imageName = image.name;
                        });
                      }
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: imageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.m),
                              child: Image.memory(imageBytes!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(height: 4),
                                Text('Add Image', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() {
                    selectedCategory = v!;
                    selectedProductName = null;
                    nameController.clear();
                  }),
                ),
                if (selectedCategory == 'Other') ...[
                  const SizedBox(height: AppSpacing.m),
                  _buildFormTextField(
                    context: context,
                    controller: otherCategoryController,
                    label: 'Custom Category Name',
                    hint: 'e.g. Rabbit',
                    icon: Icons.edit_note,
                    isName: true,
                    validator: (v) => (selectedCategory == 'Other' && (v == null || v.isEmpty)) ? 'Required' : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<String>(
                  initialValue: selectedProductName,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  items: (categoryProductMap[selectedCategory] ?? (products.where((p) => p.category == selectedCategory).map((p) => p.name).toSet().toList()..add('Other'))).map((name) {
                    return DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) => setState(() {
                    selectedProductName = v;
                    if (v != 'Other' && v != 'Custom Entry') {
                      nameController.text = v!;
                    } else {
                      nameController.clear();
                    }
                  }),
                  validator: (v) => (v == null) ? 'Required' : null,
                ),
                if (selectedProductName == 'Other' || selectedProductName == 'Custom Entry') ...[
                  const SizedBox(height: AppSpacing.m),
                  _buildFormTextField(
                    context: context,
                    controller: customNameController,
                    label: 'Custom Product Name',
                    hint: 'e.g. Sirloin Steak',
                    icon: Icons.edit_note,
                    isName: true,
                    onChanged: (v) => nameController.text = v,
                    validator: (v) => ((selectedProductName == 'Other' || selectedProductName == 'Custom Entry') && (v == null || v.isEmpty)) ? 'Required' : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.s),
                SwitchListTile(
                  title: const Text('Barcode Available', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(hasBarcode ? 'Product has a barcode/SKU to scan' : 'No barcode for this product', style: const TextStyle(fontSize: 11)),
                  value: hasBarcode,
                  onChanged: (v) => setState(() {
                    hasBarcode = v;
                    if (!hasBarcode) skuController.clear();
                  }),
                  activeThumbColor: theme.colorScheme.primary,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                if (hasBarcode) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormTextField(
                          context: context,
                          controller: skuController,
                          label: 'SKU / Barcode Number',
                          hint: 'Type or scan barcode...',
                          icon: Icons.qr_code_scanner,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined),
                        tooltip: 'Scan Barcode with Camera',
                        onPressed: () {
                          CameraBarcodeScannerDialog.show(
                            context,
                            title: 'Scan Barcode into SKU',
                            onScanned: (raw) {
                              skuController.text = raw;
                              return 'SKU captured: $raw';
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    if (allowRetail)
                      Expanded(
                        child: _buildFormTextField(
                          context: context,
                          controller: retailPriceController,
                          label: 'Retail',
                          prefix: '₵ ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onTap: () {
                            if (retailPriceController.text == '0.0' || retailPriceController.text == '0') {
                              retailPriceController.clear();
                            }
                          },
                          validator: (v) {
                            if (!allowRetail) return null;
                            if (v == null || v.isEmpty) return 'Required';
                            final val = double.tryParse(v);
                            if (val == null) return 'Invalid price';
                            final cost = double.tryParse(costPriceController.text) ?? 0.0;
                            if (cost > 0 && val < cost) return '< Cost';
                            return null;
                          },
                        ),
                      ),
                    if (allowRetail && ref.watch(appSettingsProvider).enableWholesale && allowWholesale)
                      const SizedBox(width: AppSpacing.s),
                    if (ref.watch(appSettingsProvider).enableWholesale && allowWholesale) ...[
                      Expanded(
                        child: _buildFormTextField(
                          context: context,
                          controller: wholesalePriceController,
                          label: 'Wholesale',
                          prefix: '₵ ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onTap: () {
                            if (wholesalePriceController.text == '0.0' || wholesalePriceController.text == '0') {
                              wholesalePriceController.clear();
                            }
                          },
                          validator: (v) {
                            if (!ref.read(appSettingsProvider).enableWholesale || !allowWholesale) return null;
                            if (v == null || v.isEmpty) return 'Required';
                            final val = double.tryParse(v);
                            if (val == null) return 'Invalid price';
                            if (allowRetail) {
                              final retail = double.tryParse(retailPriceController.text) ?? 0.0;
                              if (retail > 0 && val > retail) return '> Retail';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: _buildFormTextField(
                        context: context,
                        controller: costPriceController,
                        label: 'Cost',
                        prefix: '₵ ',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onTap: () {
                          if (costPriceController.text == '0.0' || costPriceController.text == '0') {
                            costPriceController.clear();
                          }
                        },
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final val = double.tryParse(v);
                          if (val == null) return 'Invalid price';
                          if (allowRetail) {
                            final retail = double.tryParse(retailPriceController.text) ?? 0.0;
                            if (retail > 0 && val > retail) return '> Retail';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<String>(
                  initialValue: (allowRetail && allowWholesale)
                      ? 'both'
                      : ((allowRetail && !allowWholesale) ? 'retail_only' : 'wholesale_only'),
                  decoration: InputDecoration(
                    labelText: 'Allowed Sales Channel',
                    prefixIcon: const Icon(Icons.point_of_sale_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'both', child: Text('Retail & Wholesale')),
                    DropdownMenuItem(value: 'retail_only', child: Text('Retail Only')),
                    DropdownMenuItem(value: 'wholesale_only', child: Text('Wholesale Only')),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      if (val == 'both') {
                        allowRetail = true;
                        allowWholesale = true;
                      } else if (val == 'retail_only') {
                        allowRetail = true;
                        allowWholesale = false;
                      } else if (val == 'wholesale_only') {
                        allowRetail = false;
                        allowWholesale = true;
                        retailPriceController.text = '0.0';
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.m),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Packaging Options & Units:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 0,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Checkbox(value: true, onChanged: null),
                        Text('1. Pcs (Default)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: hasPacks,
                          onChanged: (v) => setState(() => hasPacks = v ?? false),
                        ),
                        const Text('2. Packs', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: hasBoxes,
                          onChanged: (v) => setState(() => hasBoxes = v ?? false),
                        ),
                        const Text('3. Boxes', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                if (hasPacks || hasBoxes) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (hasPacks)
                        Expanded(
                          child: _buildFormTextField(
                            context: context,
                            controller: pcsPerPackController,
                            label: 'Pcs per Pack',
                            hint: 'e.g. 12',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (!hasPacks) return null;
                              if (v == null || v.isEmpty) return 'Required';
                              if (double.tryParse(v) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      if (hasPacks && hasBoxes) const SizedBox(width: AppSpacing.s),
                      if (hasBoxes)
                        Expanded(
                          child: _buildFormTextField(
                            context: context,
                            controller: packsPerBoxController,
                            label: hasPacks ? 'Packs per Box' : 'Pcs per Box',
                            hint: hasPacks ? 'e.g. 10' : 'e.g. 120',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (!hasBoxes) return null;
                              if (v == null || v.isEmpty) return 'Required';
                              if (double.tryParse(v) == null) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildFormTextField(
                        context: context,
                        controller: stockController,
                        label: isUnlimited ? 'Current Qty' : 'Initial Stock',
                        suffix: selectedUnit.name,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (isUnlimited) return null;
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid qty';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<WeightUnit>(
                        initialValue: selectedUnit,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: [
                          WeightUnit.pcs,
                          WeightUnit.bag,
                          WeightUnit.bundle,
                          WeightUnit.length,
                          WeightUnit.bucket,
                          WeightUnit.litre,
                          WeightUnit.kg,
                          WeightUnit.metre,
                          WeightUnit.roll,
                          WeightUnit.pack,
                          WeightUnit.box,
                        ].map((u) => DropdownMenuItem(value: u, child: Text(u.displayName, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => selectedUnit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildFormTextField(
                        context: context,
                        controller: alertThresholdController,
                        label: 'Stock Alert Threshold',
                        hint: 'e.g. 2 Boxes',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<WeightUnit>(
                        initialValue: alertUnit,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Alert Unit'),
                        items: const [
                          DropdownMenuItem(value: WeightUnit.pcs, child: Text('1. PCS', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: WeightUnit.pack, child: Text('2. PACKS', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: WeightUnit.box, child: Text('3. BOXES', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (u) {
                          if (u != null) setState(() => alertUnit = u);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),
                SwitchListTile(
                  title: const Text('Unlimited Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Sales will not subtract from quantity', style: TextStyle(fontSize: 11)),
                  value: isUnlimited, 
                  onChanged: (v) => setState(() => isUnlimited = v),
                  activeThumbColor: Colors.blue,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: AppSpacing.s),
                SwitchListTile(
                  title: const Text('Enable Size / Variant', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(hasSize ? 'Size: ${selectedSize == 'Custom' ? (customSizeController.text.isEmpty ? 'Custom' : customSizeController.text) : selectedSize}' : 'Default Size: Standard', style: const TextStyle(fontSize: 11)),
                  value: hasSize, 
                  onChanged: (v) => setState(() => hasSize = v),
                  activeThumbColor: theme.colorScheme.primary,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                if (hasSize) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: standardSizes.contains(selectedSize) ? selectedSize : 'Custom',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select Size',
                            prefixIcon: Icon(Icons.straighten_rounded),
                          ),
                          items: standardSizes.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => selectedSize = v);
                          },
                        ),
                      ),
                      if (selectedSize == 'Custom') ...[
                        const SizedBox(width: AppSpacing.s),
                        Expanded(
                          child: _buildFormTextField(
                            context: context,
                            controller: customSizeController,
                            label: 'Custom Size',
                            hint: 'e.g. 500ml, 100g, XL',
                            validator: (v) => (hasSize && selectedSize == 'Custom' && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (formKey.currentState!.validate()) {
                  final double retail = double.tryParse(retailPriceController.text) ?? 0.0;
                  final double wholesale = double.tryParse(wholesalePriceController.text) ?? 0.0;
                  final double cost = double.tryParse(costPriceController.text) ?? 0.0;

                  if (cost > 0 && retail < cost) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ Retail Price (₵${retail.toStringAsFixed(2)}) cannot be less than Cost Price (₵${cost.toStringAsFixed(2)}).'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (retail > 0 && wholesale > retail) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ Wholesale Price (₵${wholesale.toStringAsFixed(2)}) cannot be greater than Retail Price (₵${retail.toStringAsFixed(2)}).'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => isUploading = true);
                  
                  String finalImageUrl = 'assets/images/cos1.jpg';
                  
                  if (imageBytes != null && imageName != null) {
                    final uploadedUrl = await ref.read(productsFutureProvider.notifier).uploadImage(
                      imageBytes!, 
                      'prod_${DateTime.now().millisecondsSinceEpoch}_$imageName'
                    );
                    if (uploadedUrl != null) {
                      finalImageUrl = uploadedUrl;
                    }
                  }

                  String finalName = nameController.text;

                  final String validUuid = UuidUtils.generate();
                  final double rawStock = double.tryParse(stockController.text) ?? 0.0;
                  final double pcsPerPackVal = double.tryParse(pcsPerPackController.text) ?? 12.0;
                  final double packsPerBoxVal = double.tryParse(packsPerBoxController.text) ?? 10.0;
                  final double totalPcsPerBoxVal = hasPacks ? (pcsPerPackVal * packsPerBoxVal) : pcsPerPackVal;

                  double calculatedPcs = rawStock;
                  if (selectedUnit == WeightUnit.pack) {
                    calculatedPcs = rawStock * pcsPerPackVal;
                  } else if (selectedUnit == WeightUnit.box) {
                    calculatedPcs = rawStock * totalPcsPerBoxVal;
                  }

                  final double rawAlert = double.tryParse(alertThresholdController.text) ?? 2.0;
                  double calculatedAlertPcs = rawAlert;
                  if (alertUnit == WeightUnit.pack) {
                    calculatedAlertPcs = rawAlert * pcsPerPackVal;
                  } else if (alertUnit == WeightUnit.box) {
                    calculatedAlertPcs = rawAlert * totalPcsPerBoxVal;
                  }

                  final String finalSize = hasSize
                      ? (selectedSize == 'Custom' ? customSizeController.text.trim() : selectedSize)
                      : 'Standard';

                  final newProduct = Product(
                    id: validUuid,
                    name: finalName,
                    size: finalSize,
                    sku: (hasBarcode && skuController.text.trim().isNotEmpty) ? skuController.text.trim() : null,
                    retailPrice: double.tryParse(retailPriceController.text) ?? 0.0,
                    wholesalePrice: double.tryParse(wholesalePriceController.text) ?? 0.0,
                    costPrice: double.tryParse(costPriceController.text) ?? 0.0,
                    category: selectedCategory == 'Other' ? otherCategoryController.text : selectedCategory,
                    imageUrl: finalImageUrl,
                    stockQuantity: calculatedPcs,
                    hasPacks: hasPacks,
                    hasBoxes: hasBoxes,
                    pcsPerPack: pcsPerPackVal,
                    packsPerBox: packsPerBoxVal,
                    pcsPerBox: totalPcsPerBoxVal,
                    unit: selectedUnit.name,
                    lowStockThreshold: calculatedAlertPcs,
                    minStoreStock: calculatedAlertPcs,
                    isUnlimited: isUnlimited,
                    allowRetail: allowRetail,
                    allowWholesale: allowWholesale,
                  );
                  await ref.read(productsFutureProvider.notifier).addProduct(newProduct);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
              ),
              child: isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, WidgetRef ref, Product product) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product.name);
    final skuController = TextEditingController(text: product.sku ?? '');
    final retailPriceController = TextEditingController(text: product.retailPrice.toString());
    final wholesalePriceController = TextEditingController(text: product.wholesalePrice.toString());
    final costPriceController = TextEditingController(text: product.costPrice.toString());
    final pcsPerPackController = TextEditingController(text: product.pcsPerPack.toInt().toString());
    final packsPerBoxController = TextEditingController(text: product.packsPerBox.toInt().toString());
    final currentPcsPerBox = product.totalPcsPerBox;
    
    final double initialAlertBoxes = product.lowStockThreshold / currentPcsPerBox;
    final alertThresholdController = TextEditingController(
      text: initialAlertBoxes % 1 == 0 ? initialAlertBoxes.toInt().toString() : initialAlertBoxes.toStringAsFixed(1)
    );
    WeightUnit alertUnit = WeightUnit.box; // Boxes default as requested
    bool hasBarcode = product.sku != null && product.sku!.trim().isNotEmpty;
    bool hasPacks = product.hasPacks;
    bool hasBoxes = product.hasBoxes;

    final otherCategoryController = TextEditingController();
    final theme = Theme.of(context);
    
    final categories = ['Building Materials', 'Steel & Rebar', 'Plumbing & PVC', 'Electricals', 'Paints & Finishes', 'Roofing & Timber', 'Tools & Fasteners', 'Other'];
    String normalized = _normalizeCategory(product);
    String selectedCategory = categories.contains(normalized) ? normalized : 'Other';
    bool isUnlimited = product.isUnlimited;
    bool allowRetail = product.allowRetail;
    bool allowWholesale = product.allowWholesale;

    if (selectedCategory == 'Other') {
      otherCategoryController.text = product.category;
    }
    
    Uint8List? imageBytes;
    String? imageName;
    bool isUploading = false;

    final standardSizes = ['Big', 'Medium', 'Small', 'Mini', 'Large', 'Extra Large', 'Custom'];
    bool hasSize = product.size != null && product.size!.trim().isNotEmpty && product.size != 'Standard';
    String selectedSize = (hasSize && standardSizes.contains(product.size)) ? product.size! : (hasSize ? 'Custom' : 'Medium');
    final customSizeController = TextEditingController(text: (hasSize && !standardSizes.contains(product.size)) ? product.size : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Text('Edit Product: ${product.name}'),
          content: Form(
            key: formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1024,
                          maxHeight: 1024,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setState(() {
                            imageBytes = bytes;
                            imageName = image.name;
                          });
                        }
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.m),
                          child: imageBytes != null
                              ? Image.memory(imageBytes!, fit: BoxFit.cover)
                              : AppCachedImage(imageUrl: product.imageUrl, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _buildFormTextField(
                    context: context,
                    controller: nameController, 
                    label: 'Product Name',
                    isName: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  SwitchListTile(
                    title: const Text('Barcode Available', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(hasBarcode ? 'Product has a barcode/SKU to scan' : 'No barcode for this product', style: const TextStyle(fontSize: 11)),
                    value: hasBarcode,
                    onChanged: (v) => setState(() {
                      hasBarcode = v;
                      if (!hasBarcode) skuController.clear();
                    }),
                    activeThumbColor: theme.colorScheme.primary,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (hasBarcode) ...[
                    const SizedBox(height: AppSpacing.s),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFormTextField(
                            context: context,
                            controller: skuController,
                            label: 'SKU / Barcode Number',
                            hint: 'Type or scan barcode...',
                            icon: Icons.qr_code_scanner,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.camera_alt_outlined),
                          tooltip: 'Scan Barcode with Camera',
                          onPressed: () {
                            CameraBarcodeScannerDialog.show(
                              context,
                              title: 'Scan Barcode into SKU',
                              onScanned: (raw) {
                                skuController.text = raw;
                                return 'SKU captured: $raw';
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => selectedCategory = v!),
                  ),
                  if (selectedCategory == 'Other') ...[
                    const SizedBox(height: 16),
                    _buildFormTextField(
                      context: context,
                      controller: otherCategoryController,
                      label: 'Custom Category Name',
                      isName: true,
                      validator: (v) => (selectedCategory == 'Other' && (v == null || v.isEmpty)) ? 'Required' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (allowRetail)
                        Expanded(
                          child: _buildFormTextField(
                            context: context,
                            controller: retailPriceController, 
                            label: 'Retail', 
                            prefix: '₵ ',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onTap: () {
                              if (retailPriceController.text == '0.0' || retailPriceController.text == '0') {
                                retailPriceController.clear();
                              }
                            },
                            validator: (v) {
                              if (!allowRetail) return null;
                              if (v == null || v.isEmpty) return 'Required';
                              final val = double.tryParse(v);
                              if (val == null) return 'Invalid price';
                              final cost = double.tryParse(costPriceController.text) ?? 0.0;
                              if (cost > 0 && val < cost) return '< Cost';
                              return null;
                            },
                          ),
                        ),
                      if (allowRetail && ref.watch(appSettingsProvider).enableWholesale && allowWholesale)
                        const SizedBox(width: 8),
                      if (ref.watch(appSettingsProvider).enableWholesale && allowWholesale) ...[
                        Expanded(
                          child: _buildFormTextField(
                            context: context,
                            controller: wholesalePriceController, 
                            label: 'Wholesale', 
                            prefix: '₵ ',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onTap: () {
                              if (wholesalePriceController.text == '0.0' || wholesalePriceController.text == '0') {
                                wholesalePriceController.clear();
                              }
                            },
                            validator: (v) {
                              if (!ref.read(appSettingsProvider).enableWholesale || !allowWholesale) return null;
                              if (v == null || v.isEmpty) return 'Required';
                              final val = double.tryParse(v);
                              if (val == null) return 'Invalid price';
                              if (allowRetail) {
                                final retail = double.tryParse(retailPriceController.text) ?? 0.0;
                                if (retail > 0 && val > retail) return '> Retail';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormTextField(
                          context: context,
                          controller: costPriceController, 
                          label: 'Cost', 
                          prefix: '₵ ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onTap: () {
                            if (costPriceController.text == '0.0' || costPriceController.text == '0') {
                              costPriceController.clear();
                            }
                          },
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final val = double.tryParse(v);
                            if (val == null) return 'Invalid price';
                            if (allowRetail) {
                              final retail = double.tryParse(retailPriceController.text) ?? 0.0;
                              if (retail > 0 && val > retail) return '> Retail';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: (allowRetail && allowWholesale)
                        ? 'both'
                        : ((allowRetail && !allowWholesale) ? 'retail_only' : 'wholesale_only'),
                    decoration: InputDecoration(
                      labelText: 'Allowed Sales Channel',
                      prefixIcon: const Icon(Icons.point_of_sale_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'both', child: Text('Retail & Wholesale')),
                      DropdownMenuItem(value: 'retail_only', child: Text('Retail Only')),
                      DropdownMenuItem(value: 'wholesale_only', child: Text('Wholesale Only')),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        if (val == 'both') {
                          allowRetail = true;
                          allowWholesale = true;
                        } else if (val == 'retail_only') {
                          allowRetail = true;
                          allowWholesale = false;
                        } else if (val == 'wholesale_only') {
                          allowRetail = false;
                          allowWholesale = true;
                          retailPriceController.text = '0.0';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Packaging Options & Units:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Checkbox(value: true, onChanged: null),
                          Text('1. Pcs (Default)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: hasPacks,
                            onChanged: (v) => setState(() => hasPacks = v ?? false),
                          ),
                          const Text('2. Packs', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: hasBoxes,
                            onChanged: (v) => setState(() => hasBoxes = v ?? false),
                          ),
                          const Text('3. Boxes', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  if (hasPacks || hasBoxes) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (hasPacks)
                          Expanded(
                            child: _buildFormTextField(
                              context: context,
                              controller: pcsPerPackController,
                              label: 'Pcs per Pack',
                              hint: 'e.g. 12',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (!hasPacks) return null;
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                        if (hasPacks && hasBoxes) const SizedBox(width: AppSpacing.s),
                        if (hasBoxes)
                          Expanded(
                            child: _buildFormTextField(
                              context: context,
                              controller: packsPerBoxController,
                              label: hasPacks ? 'Packs per Box' : 'Pcs per Box',
                              hint: hasPacks ? 'e.g. 10' : 'e.g. 120',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (!hasBoxes) return null;
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildFormTextField(
                          context: context,
                          controller: alertThresholdController,
                          label: 'Stock Alert Threshold',
                          hint: 'e.g. 2 Boxes',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<WeightUnit>(
                          initialValue: alertUnit,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Alert Unit'),
                          items: const [
                            DropdownMenuItem(value: WeightUnit.pcs, child: Text('1. PCS', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: WeightUnit.pack, child: Text('2. PACKS', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: WeightUnit.box, child: Text('3. BOXES', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (u) {
                            if (u != null) setState(() => alertUnit = u);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Unlimited Stock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Sales will not subtract from quantity', style: TextStyle(fontSize: 11)),
                    value: isUnlimited, 
                    onChanged: (v) => setState(() => isUnlimited = v),
                    activeThumbColor: Colors.blue,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: AppSpacing.s),
                  SwitchListTile(
                    title: const Text('Enable Size / Variant', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(hasSize ? 'Size: ${selectedSize == 'Custom' ? (customSizeController.text.isEmpty ? 'Custom' : customSizeController.text) : selectedSize}' : 'Default Size: Standard', style: const TextStyle(fontSize: 11)),
                    value: hasSize, 
                    onChanged: (v) => setState(() => hasSize = v),
                    activeThumbColor: theme.colorScheme.primary,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (hasSize) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: standardSizes.contains(selectedSize) ? selectedSize : 'Custom',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Size',
                              prefixIcon: Icon(Icons.straighten_rounded),
                            ),
                            items: standardSizes.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => selectedSize = v);
                            },
                          ),
                        ),
                        if (selectedSize == 'Custom') ...[
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: _buildFormTextField(
                              context: context,
                              controller: customSizeController,
                              label: 'Custom Size',
                              hint: 'e.g. 500ml, 100g, XL',
                              validator: (v) => (hasSize && selectedSize == 'Custom' && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context), 
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
            ),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                if (formKey.currentState!.validate()) {
                  final double retail = double.tryParse(retailPriceController.text) ?? 0.0;
                  final double wholesale = double.tryParse(wholesalePriceController.text) ?? 0.0;
                  final double cost = double.tryParse(costPriceController.text) ?? 0.0;

                  if (cost > 0 && retail < cost) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ Retail Price (₵${retail.toStringAsFixed(2)}) cannot be less than Cost Price (₵${cost.toStringAsFixed(2)}).'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (retail > 0 && wholesale > retail) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('⚠️ Wholesale Price (₵${wholesale.toStringAsFixed(2)}) cannot be greater than Retail Price (₵${retail.toStringAsFixed(2)}).'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() => isUploading = true);

                  String finalImageUrl = product.imageUrl;

                  if (imageBytes != null && imageName != null) {
                    final uploadedUrl = await ref.read(productsFutureProvider.notifier).uploadImage(
                      imageBytes!, 
                      'prod_${DateTime.now().millisecondsSinceEpoch}_$imageName'
                    );
                    if (uploadedUrl != null) {
                      finalImageUrl = uploadedUrl;
                    }
                  }

                  final double pcsPerPackVal = double.tryParse(pcsPerPackController.text) ?? 12.0;
                  final double packsPerBoxVal = double.tryParse(packsPerBoxController.text) ?? 10.0;
                  final double totalPcsPerBoxVal = hasPacks ? (pcsPerPackVal * packsPerBoxVal) : pcsPerPackVal;

                  final double rawAlert = double.tryParse(alertThresholdController.text) ?? 2.0;
                  double calculatedAlertPcs = rawAlert;
                  if (alertUnit == WeightUnit.pack) {
                    calculatedAlertPcs = rawAlert * pcsPerPackVal;
                  } else if (alertUnit == WeightUnit.box) {
                    calculatedAlertPcs = rawAlert * totalPcsPerBoxVal;
                  }

                  final String finalSize = hasSize
                      ? (selectedSize == 'Custom' ? customSizeController.text.trim() : selectedSize)
                      : 'Standard';

                  final updated = product.copyWith(
                    name: nameController.text,
                    sku: (hasBarcode && skuController.text.trim().isNotEmpty) ? skuController.text.trim() : null,
                    size: finalSize,
                    retailPrice: double.tryParse(retailPriceController.text),
                    wholesalePrice: double.tryParse(wholesalePriceController.text),
                    costPrice: double.tryParse(costPriceController.text),
                    category: selectedCategory == 'Other' ? otherCategoryController.text : selectedCategory,
                    hasPacks: hasPacks,
                    hasBoxes: hasBoxes,
                    pcsPerPack: pcsPerPackVal,
                    packsPerBox: packsPerBoxVal,
                    pcsPerBox: totalPcsPerBoxVal,
                    lowStockThreshold: calculatedAlertPcs,
                    minStoreStock: calculatedAlertPcs,
                    imageUrl: finalImageUrl,
                    isUnlimited: isUnlimited,
                    allowRetail: allowRetail,
                    allowWholesale: allowWholesale,
                  );
                  await ref.read(productsFutureProvider.notifier).updateProduct(updated);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
              child: isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    String? suffix,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isName = false,
    Function(String)? onChanged,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
      inputFormatters: [
        if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s\-]')),
        if (keyboardType == const TextInputType.numberWithOptions(decimal: true))
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      validator: validator,
    );
  }

  Widget _buildProductGrid(BuildContext context, List<Product> products, WidgetRef ref, {required bool isAdmin}) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1));
      final aspectRatio = isMobile ? (constraints.maxWidth < 400 ? 1.2 : 1.4) : 0.72;
      
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: aspectRatio,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          final isLowStock = product.stockQuantity <= product.lowStockThreshold;
          final hasPromo = product.isPromoScheduled;
          final pendingWeight = ref.watch(productPendingWeightProvider(product.name));
          final hasIncoming = pendingWeight > 0;

          return Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            child: isMobile 
              ? InkWell(
                  onTap: isAdmin ? () => _showUpdateStockDialog(context, ref, product) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.s),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.s),
                            child: AppCachedImage(
                              imageUrl: product.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_) => const Icon(Icons.image),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFormattedName(product.name, const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  if (isAdmin) _buildItemMenu(context, ref, product),
                                ],
                              ),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      product.category.toUpperCase(), 
                                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (hasIncoming) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text('IN TRANSIT', style: TextStyle(color: Colors.blue.shade700, fontSize: 8, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text('₵${product.retailPrice.toStringAsFixed(2)}', 
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        if (hasPromo) 
                                          Text('PROMO ACTIVE', 
                                            style: TextStyle(color: Colors.orange.shade800, fontSize: 9, fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: (product.isUnlimited ? Colors.blue : (isLowStock ? Colors.red : Colors.green)).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            product.stockControlStoreDisplay, 
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: product.isUnlimited ? Colors.blue : (isLowStock ? Colors.red : Colors.green)),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (hasIncoming)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text('+${pendingWeight.toStringAsFixed(1)}${product.unit} coming', 
                                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          )
                                        else if (product.dailyStockAdded > 0 && 
                                            product.lastStockUpdate != null && 
                                            product.lastStockUpdate!.year == DateTime.now().year &&
                                            product.lastStockUpdate!.month == DateTime.now().month &&
                                            product.lastStockUpdate!.day == DateTime.now().day)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text('+${product.dailyStockAdded}${product.unit} today', 
                                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          AppCachedImage(
                            imageUrl: product.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_) => Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Center(child: Icon(Icons.image)),
                            ),
                          ),
                          if (isLowStock)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                child: const Text('LOW STOCK', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (hasIncoming)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(4)),
                                child: const Text('IN TRANSIT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (product.retailPrice <= 0)
                            Positioned(
                              top: hasIncoming ? 32 : 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4)),
                                child: const Text('PRICING REQ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (hasPromo)
                            Positioned(
                              top: (product.retailPrice <= 0 && hasIncoming) ? 56 : (product.retailPrice <= 0 || hasIncoming ? 32 : 8),
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  '${product.discountPercentage % 1 == 0 ? product.discountPercentage.toInt() : product.discountPercentage}% OFF', 
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  product.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (product.size != null && product.size!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    product.size!.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              if (hasIncoming) ...[
                                const SizedBox(width: 8),
                                Text('+${pendingWeight.toStringAsFixed(1)}${product.unit} IN TRANSIT', 
                                  style: TextStyle(color: Colors.blue.shade700, fontSize: 8, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildFormattedName(product.name, const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              if (isAdmin) _buildItemMenu(context, ref, product),
                            ],
                          ),
                          Text(product.category, 
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text('Ret: ₵${product.retailPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, decoration: product.isPromoActiveFor(false, null, ignoreCustomerFilter: true) ? TextDecoration.lineThrough : null)),
                                    ),
                                    if (product.isPromoActiveFor(false, null, ignoreCustomerFilter: true)) 
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text('₵${product.getPrice(false, ignoreCustomerFilter: true).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text('Whl: ₵${product.wholesalePrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, decoration: product.isPromoActiveFor(true, null, ignoreCustomerFilter: true) ? TextDecoration.lineThrough : null)),
                                    ),
                                    if (product.isPromoActiveFor(true, null, ignoreCustomerFilter: true)) 
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text('₵${product.getPrice(true, ignoreCustomerFilter: true).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    product.stockControlStoreDisplay, 
                                    style: TextStyle(fontWeight: FontWeight.bold, color: product.isUnlimited ? Colors.blue : (isLowStock ? Colors.red : Colors.green))
                                  ),
                                  if (hasIncoming)
                                    Text('+${pendingWeight.toStringAsFixed(1)}${product.unit} coming', 
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue.shade700))
                                  else if (product.dailyStockAdded > 0 &&
                                      product.lastStockUpdate != null && 
                                      product.lastStockUpdate!.year == DateTime.now().year &&
                                      product.lastStockUpdate!.month == DateTime.now().month &&
                                      product.lastStockUpdate!.day == DateTime.now().day)
                                    Text('+${product.dailyStockAdded}${product.unit} today', 
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isAdmin)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _showUpdateStockDialog(context, ref, product),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text('Update Stock', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
          );
        },
      );
    });
  }

  Widget _buildFormattedName(String name, TextStyle baseStyle) {
    if (!name.contains('(')) {
      return Text(name, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final int splitIndex = name.lastIndexOf('(');
    final String mainName = name.substring(0, splitIndex).trim();
    final String range = name.substring(splitIndex).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(mainName, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(range, 
          style: baseStyle.copyWith(
            fontSize: baseStyle.fontSize! - 2, 
            color: baseStyle.color?.withValues(alpha: 0.7) ?? Colors.black54,
            fontWeight: FontWeight.normal,
          ), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
      ],
    );
  }

  Widget _buildItemMenu(BuildContext context, WidgetRef ref, Product product) {
    final bool isWholeChicken = product.name.contains('Whole Chicken');

    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'edit') {
          _showEditProductDialog(context, ref, product);
        } else if (val == 'portion' && isWholeChicken) {
          _showChickenPortioningDialog(context, ref, product);
        } else if (val == 'delete') {
          _confirmDeleteProduct(context, ref, product);
        } else if (val == 'stop_promo') {
          ref.read(productsFutureProvider.notifier).removePromotion(product.id);
        } else if (val == 'extend_promo') {
          _showPromotionDialog(context, ref, [product], initialProduct: product);
        }
      },
      icon: const Icon(Icons.more_vert, size: 18),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        if (isWholeChicken)
          const PopupMenuItem(
            value: 'portion',
            child: Row(
              children: [
                Icon(Icons.restaurant_rounded, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text('Portion Bird'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 18),
              SizedBox(width: 8),
              Text('Edit Details'),
            ],
          ),
        ),
        if (product.discountPercentage > 0) ...[
          const PopupMenuItem(
            value: 'extend_promo',
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text('Extend/Modify Promo'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'stop_promo',
            child: Row(
              children: [
                Icon(Icons.block, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Text('Stop Promotion'),
              ],
            ),
          ),
        ],
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Product', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _showUpdateStockDialog(BuildContext context, WidgetRef ref, Product product) {
    final formKey = GlobalKey<FormState>();
    final stockController = TextEditingController();
    final theme = Theme.of(context);
    WeightUnit selectedUnit = WeightUnit.values.firstWhere(
      (u) => u.name.toLowerCase() == product.unit.toLowerCase() || (product.unit.toLowerCase() == 'pcs' && u == WeightUnit.pcs), 
      orElse: () => WeightUnit.pcs
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.primaryMaroon),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Update Stock: ${product.name}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  overflow: TextOverflow.ellipsis
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Inventory', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(WeightConverter.formatShort(product.stockQuantity, unit: product.unit), 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: theme.colorScheme.primary)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: stockController,
                          decoration: InputDecoration(
                            labelText: selectedUnit == WeightUnit.unit ? 'Add/Remove Qty' : 'Add/Remove (${selectedUnit.name})',
                            hintText: 'e.g. 50.0 or -10.5',
                            helperText: 'Use negative to reduce',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
                          autofocus: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          const Text('UNIT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                          ToggleButtons(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                            isSelected: [
                              selectedUnit == WeightUnit.pcs || selectedUnit == WeightUnit.unit, 
                              selectedUnit == WeightUnit.box,
                            ],
                            onPressed: (index) {
                              setState(() {
                                selectedUnit = index == 0 ? WeightUnit.pcs : WeightUnit.box;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            selectedColor: Colors.white,
                            fillColor: theme.colorScheme.primary,
                            children: const [
                              Text('pcs', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              Text('box', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  double change = double.tryParse(stockController.text) ?? 0.0;
                  if (change != 0) {
                    if (selectedUnit == WeightUnit.box) {
                      change = change * product.totalPcsPerBox;
                    } else if (selectedUnit == WeightUnit.pack) {
                      change = change * product.pcsPerPack;
                    } else if (selectedUnit == WeightUnit.g) {
                      change = WeightConverter.fromG(change);
                    } else if (selectedUnit == WeightUnit.lb) {
                      change = WeightConverter.toKg(change);
                    }
                    ref.read(productsFutureProvider.notifier).updateStock(product.id, change);
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${product.name}? This will remove it from the catalog for all terminals.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(productsFutureProvider.notifier).deleteProduct(product.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} deleted successfully'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Product'),
          ),
        ],
      ),
    );
  }

  void _showChickenPortioningDialog(BuildContext context, WidgetRef ref, Product wholeChicken) {
    final qtyController = TextEditingController(text: '1');
    
    // Weight controllers for all parts
    final thighWeightController = TextEditingController(text: '0');
    final wingWeightController = TextEditingController(text: '0');
    final drumWeightController = TextEditingController(text: '0');
    final breastWeightController = TextEditingController(text: '0');
    final backWeightController = TextEditingController(text: '0');
    final gizzardWeightController = TextEditingController(text: '0');

    final type = wholeChicken.name.contains('Soft') ? 'Soft' : 'Hard';
    bool isProcessing = false;
    WeightUnit selectedUnit = WeightUnit.kg;
    bool isLegSeparated = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Row(
            children: [
              const Icon(Icons.restaurant_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(child: Text('Portion: ${wholeChicken.name}', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter the total weight for each part group resulting from this batch.', 
                style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(
                        labelText: 'Number of Birds',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      const Text('INPUT UNIT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                      ToggleButtons(
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
                        isSelected: [
                          selectedUnit == WeightUnit.pcs || selectedUnit == WeightUnit.unit, 
                          selectedUnit == WeightUnit.box,
                        ],
                        onPressed: (index) {
                          setState(() {
                            selectedUnit = index == 0 ? WeightUnit.pcs : WeightUnit.box;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: Colors.orange,
                        children: const [
                          Text('pcs', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('box', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(),
              ),
              
              const Text('PART WEIGHTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 1)),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Separate Thighs & Drumsticks?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                subtitle: const Text('OFF: Thigh includes Drumstick. ON: They are separate.', style: TextStyle(fontSize: 9)),
                value: isLegSeparated, 
                onChanged: (v) => setState(() => isLegSeparated = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.orange,
              ),
              const SizedBox(height: 8),
              
              _weightInputField(
                isLegSeparated ? 'Thighs (Separated)' : ((double.tryParse(drumWeightController.text) ?? 0) > 0 ? 'Thighs (Separated)' : 'Thighs (Whole Leg)'), 
                thighWeightController, 
                selectedUnit,
                enabled: isLegSeparated || (double.tryParse(drumWeightController.text) ?? 0) == 0,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              _weightInputField('Wings Weight', wingWeightController, selectedUnit),
              const SizedBox(height: 8),
              _weightInputField(
                isLegSeparated ? 'Drumsticks (Separated)' : ((double.tryParse(thighWeightController.text) ?? 0) > 0 ? 'Drumsticks (Included in Thigh)' : 'Drumsticks Weight'), 
                drumWeightController, 
                selectedUnit,
                enabled: isLegSeparated || (double.tryParse(thighWeightController.text) ?? 0) == 0,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              _weightInputField('Breast Weight', breastWeightController, selectedUnit),
              const SizedBox(height: 8),
              _weightInputField('Back Weight', backWeightController, selectedUnit),
              const SizedBox(height: 8),
              _weightInputField('Gizzard Weight', gizzardWeightController, selectedUnit),
            ],
          ),
          actions: [
            TextButton(onPressed: isProcessing ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                final int birds = int.tryParse(qtyController.text) ?? 0;
                if (birds <= 0) return;
                
                if (birds > wholeChicken.stockQuantity) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough whole chickens in stock!')));
                  return;
                }

                setState(() => isProcessing = true);
                try {
                  final notifier = ref.read(productsFutureProvider.notifier);
                  final products = ref.read(productsFutureProvider).value ?? [];
                  
                  // 0. Extract Range Suffix (e.g. "(3.0 - 4.0 LB)")
                  String rangeSuffix = '';
                  if (wholeChicken.name.contains('(') && wholeChicken.name.contains(')')) {
                    rangeSuffix = wholeChicken.name.substring(wholeChicken.name.lastIndexOf('('));
                  }

                  if (rangeSuffix.isEmpty) {
                    throw Exception('Weight range suffix missing. Cannot portion bird without range.');
                  }

                  // 1. Update Whole Chicken
                  await notifier.updateStock(wholeChicken.id, -birds.toDouble(), reason: 'PORTIONING_REDUCTION');

                  // Helper to convert and update
                  Future<void> updatePart(String partName, String enteredWeight) async {
                    double weight = double.tryParse(enteredWeight) ?? 0.0;
                    if (weight <= 0) return;

                    // Convert to KG for database consistency if needed
                    if (selectedUnit == WeightUnit.lb) {
                      weight = WeightConverter.toKg(weight);
                    }

                    // Find the specific card that matches type (Soft/Hard), Part Name, and Range
                    final part = products.where((p) => 
                      p.name.contains(type) && 
                      p.name.contains(partName) && 
                      p.name.contains(rangeSuffix)
                    ).firstOrNull;

                    if (part != null) {
                      await notifier.updateStock(part.id, weight, reason: 'PORTIONING_ADDITION_${rangeSuffix.replaceAll('(', '').replaceAll(')', '').replaceAll(' ', '')}');
                    }
                  }

                  // 2. Update all parts
                  await updatePart('Thigh', thighWeightController.text);
                  await updatePart('Wings', wingWeightController.text);
                  await updatePart('Drumsticks', drumWeightController.text);
                  await updatePart('Breast', breastWeightController.text);
                  await updatePart('Back', backWeightController.text);

                  // 3. Update Gizzard (Single global card)
                  double gizzardWeight = double.tryParse(gizzardWeightController.text) ?? 0.0;
                  if (gizzardWeight > 0) {
                    if (selectedUnit == WeightUnit.lb) gizzardWeight = WeightConverter.toKg(gizzardWeight);
                    final gizzard = products.firstWhere((p) => p.name.toUpperCase() == 'GIZZARD');
                    await notifier.updateStock(gizzard.id, gizzardWeight, reason: 'PORTIONING_GIZZARD_WEIGHT');
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Portioned $birds chickens and updated part weights!'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    setState(() => isProcessing = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: isProcessing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Weights'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightInputField(String label, TextEditingController controller, WeightUnit unit, {bool enabled = true, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit.name,
        border: const OutlineInputBorder(),
        isDense: true,
        fillColor: enabled ? null : Colors.grey.shade100,
        filled: !enabled,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    );
  }

  String _normalizeCategory(Product p) {
    final cat = p.category.trim();
    if (cat.isEmpty) return 'Other';
    final upper = cat.toUpperCase();
    if (upper.contains('BUILDING') || upper.contains('CEMENT') || upper.contains('SAND') || upper.contains('BLOCK')) return 'Building Materials';
    if (upper.contains('STEEL') || upper.contains('REBAR') || upper.contains('IRON')) return 'Steel & Rebar';
    if (upper.contains('PLUMBING') || upper.contains('PVC') || upper.contains('PIPE')) return 'Plumbing & PVC';
    if (upper.contains('ELECTRICAL') || upper.contains('CABLE')) return 'Electricals';
    if (upper.contains('PAINT') || upper.contains('FINISH')) return 'Paints & Finishes';
    if (upper.contains('ROOF') || upper.contains('TIMBER')) return 'Roofing & Timber';
    if (upper.contains('TOOL') || upper.contains('FASTENER') || upper.contains('NAIL') || upper.contains('SCREW')) return 'Tools & Fasteners';
    return cat[0].toUpperCase() + cat.substring(1).toLowerCase();
  }

  void _showManageCategoriesDialog(BuildContext context, WidgetRef ref, List<Product> products) {
    final activeProducts = products.where((p) => !p.isDeleted).toList();
    final categoriesMap = <String, int>{};

    for (var p in activeProducts) {
      final cat = p.category.trim().isEmpty ? 'Other' : p.category.trim();
      categoriesMap[cat] = (categoriesMap[cat] ?? 0) + 1;
    }

    final sortedCategories = categoriesMap.keys.toList()..sort();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
              title: const Row(
                children: [
                  Icon(Icons.category_rounded, color: AppColors.primaryMaroon),
                  SizedBox(width: 10),
                  Text('Manage Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categories are linked to active products. Select any category below to reassign or delete its products.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: sortedCategories.map((cat) {
                            final count = categoriesMap[cat] ?? 0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('$count product(s)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                tooltip: 'Delete / Reassign Category "$cat"',
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  _confirmDeleteCategory(context, ref, cat, count, activeProducts);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCategory(BuildContext context, WidgetRef ref, String categoryName, int productCount, List<Product> activeProducts) {
    final catProducts = activeProducts.where((p) => p.category.trim() == categoryName || _normalizeCategory(p) == categoryName).toList();
    final otherCategories = activeProducts.map((p) => p.category.trim()).where((c) => c != categoryName && c.isNotEmpty).toSet().toList();
    if (!otherCategories.contains('Other')) otherCategories.add('Other');

    String selectedReassignTarget = otherCategories.first;

    showDialog(
      context: context,
      builder: (confirmDialogContext) => StatefulBuilder(
        builder: (context, setConfirmState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          title: Text('Delete Category "$categoryName"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('There are $productCount product(s) in "$categoryName".'),
              const SizedBox(height: 16),
              const Text('Reassign products to another category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedReassignTarget,
                decoration: const InputDecoration(
                  labelText: 'Target Category',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: otherCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  if (v != null) setConfirmState(() => selectedReassignTarget = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(confirmDialogContext),
              child: const Text('CANCEL'),
            ),
            OutlinedButton(
              onPressed: () async {
                final service = ref.read(productServiceProvider);
                for (var p in catProducts) {
                  final updated = p.copyWith(category: selectedReassignTarget);
                  await service.updateProduct(updated);
                }
                ref.invalidate(productsFutureProvider);
                if (confirmDialogContext.mounted) Navigator.pop(confirmDialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Category "$categoryName" reassigned to "$selectedReassignTarget" and deleted!'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('REASSIGN & DELETE CATEGORY'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final service = ref.read(productServiceProvider);
                for (var p in catProducts) {
                  await service.deleteProduct(p.id);
                }
                ref.invalidate(productsFutureProvider);
                if (confirmDialogContext.mounted) Navigator.pop(confirmDialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Category "$categoryName" and its $productCount product(s) deleted!'), backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('DELETE PRODUCTS & CATEGORY'),
            ),
          ],
        ),
      ),
    );
  }
}
