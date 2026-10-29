import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../core/utils.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/product_card.dart';
import '../../widgets/cart_item_tile.dart';
import '../../widgets/hold_to_repeat_button.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/camera_barcode_scanner_dialog.dart';
import '../../widgets/process_return_dialog.dart';
import '../../services/cart_provider.dart';
import '../../services/product_service.dart';
import '../../services/transfer_provider.dart';
import '../../services/sale_provider.dart';
import '../../services/sale_return_service.dart';
import '../../services/customer_provider.dart';
import '../../services/feedback_service.dart';
import '../../services/app_settings_provider.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../services/expense_provider.dart';
import '../../services/offline_sync_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/transfer_models.dart';
import '../../models/sale_model.dart';
import '../../models/product.dart';
import '../../models/customer_model.dart';
import '../../models/user_model.dart';
import '../../services/receipt_service.dart';
import '../../services/sms_service.dart';
import '../../widgets/role_pop_scope.dart';
import '../../services/held_receipt_provider.dart';
import '../../services/birthday_service.dart';
import '../../services/branch_provider.dart';
import '../../widgets/phone_prompt_dialog.dart';
import '../../widgets/passcode_guard.dart';

import '../../services/customer_metrics_provider.dart';

enum POSView { sales, history }

class CashierPOS extends ConsumerStatefulWidget {
  const CashierPOS({super.key});

  @override
  ConsumerState<CashierPOS> createState() => _CashierPOSState();
}

class _CashierPOSState extends ConsumerState<CashierPOS> {
  POSView _currentView = POSView.sales;
  String _selectedCategory = 'All';
  bool _hasCheckedDialogs = false;
  
  String _productSearchQuery = '';
  final String _historySearchQuery = '';
  DateTimeRange? _historyDateRange;

  // Search input & USB Scanner Focus
  final TextEditingController _posSearchController = TextEditingController();
  final FocusNode _posSearchFocusNode = FocusNode();
  final FocusNode _globalKeyboardFocusNode = FocusNode();
  String _usbScanBuffer = '';
  DateTime? _lastUsbKeyTime;

  // Selected customer for the current sale
  Customer? _selectedCustomer;
  String? _uploadedReceiptUrl;
  bool _applyDailyPromo = true;
  bool _isProcessingCheckout = false;

  static const Map<String, List<String>> allowedCatalog = {
    'BUILDING MATERIALS': [
      'Cement', 'Sand', 'Stones', 'Blocks', 'Mortar', 'Lime', 'Tile Adhesive', 'Grout'
    ],
    'STEEL & REBAR': [
      'Iron Rods', 'BRC Mesh', 'Binding Wire', 'Steel Pipes', 'Angle Bars', 'Flat Bars'
    ],
    'PLUMBING & PVC': [
      'PVC Pipes', 'Pipe Fittings', 'Valves', 'Water Tanks', 'Taps', 'Sink Waste', 'Flexi Hoses'
    ],
    'ELECTRICALS': [
      'Electrical Cables', 'Switches', 'Sockets', 'Circuit Breakers', 'Conduit Pipes', 'LED Bulbs', 'DB Boards'
    ],
    'PAINTS & FINISHES': [
      'Emulsion Paint', 'Oil Paint', 'Undercoat Primer', 'Thinner', 'Paint Rollers', 'Brushes', 'Sandpaper'
    ],
    'ROOFING & TIMBER': [
      'Roofing Sheets', 'Roofing Nails', 'Timber Battens', 'Plywood', 'Felt', 'Ridge Caps'
    ],
    'TOOLS & FASTENERS': [
      'Hammers', 'Trowels', 'Tape Measures', 'Nails', 'Screws', 'Bolts & Nuts', 'Drill Bits', 'Safety Helmets / Boots'
    ],
  };

  @override
  void initState() {
    super.initState();
    // Force a fresh sync of transfers when the POS opens
    Future.microtask(() {
      ref.read(transferProvider.notifier).loadTransfers();
    });
  }

  @override
  void dispose() {
    _posSearchController.dispose();
    _posSearchFocusNode.dispose();
    _globalKeyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleGlobalKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final character = event.character;
      final key = event.logicalKey;

      final primaryFocus = FocusManager.instance.primaryFocus;
      final isEditingOtherField = primaryFocus != null &&
          primaryFocus.context?.widget is EditableText &&
          primaryFocus != _posSearchFocusNode;

      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        if (_usbScanBuffer.trim().isNotEmpty) {
          final scannedCode = _usbScanBuffer;
          _usbScanBuffer = '';
          if (!isEditingOtherField) {
            _handleBarcodeScan(scannedCode);
          }
        }
      } else if (character != null && character.isNotEmpty) {
        final now = DateTime.now();
        if (_lastUsbKeyTime == null || now.difference(_lastUsbKeyTime!).inMilliseconds > 300) {
          _usbScanBuffer = '';
        }
        _lastUsbKeyTime = now;
        _usbScanBuffer += character;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    // Check for Birthday (run ONLY ONCE on initial mount)
    if (!_hasCheckedDialogs) {
      _hasCheckedDialogs = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          BirthdayService.checkAndShowBirthdayWish(context, user);
        }
      });
    }

    // Instant Permission Guard: Redirect if access is revoked
    final roles = user.activeRoles;
    final hasAccess = roles.contains(UserRole.cashier) || roles.contains(UserRole.superAdmin) || user.enabledPermissions.contains('/cashier');
    
    if (!hasAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final isWholesale = ref.watch(isWholesaleProvider);
    final menuItems = ref.watch(menuItemsProvider);

    // Safety: Reset selected category if it no longer exists after deletions
    final productsAsync = ref.watch(productsFutureProvider);
    if (productsAsync.hasValue) {
      final products = productsAsync.value!;
      final availableCategories = ['All', ...{
        ...allowedCatalog.keys,
        ...products.where((p) => !p.isDeleted).map((p) => _getMappedCategory(p))
      }];
      if (!availableCategories.contains(_selectedCategory.toUpperCase()) && _selectedCategory != 'All') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCategory = 'All');
        });
      }
    }

    return RolePopScope(
      currentRoute: '/cashier',
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentView != POSView.sales) {
            setState(() => _currentView = POSView.sales);
          } else {
            // Already on Sales (Home), stay here instead of showing exit dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Use the menu to logout or switch accounts'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        child: PasscodeGuard(
          child: KeyboardListener(
            focusNode: _globalKeyboardFocusNode,
            autofocus: true,
            onKeyEvent: _handleGlobalKeyEvent,
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
            appBar: MainAppBar(
              title: _currentView == POSView.sales 
                  ? 'POS System (${isWholesale ? "Wholesale" : "Retail"})' 
                  : 'Sales History',
              actions: [],
            ),
            drawer: isDesktop ? null : Drawer(child: _buildSidebar(context, user, menuItems)),
            body: Row(
              children: [
                if (isDesktop) _buildSidebar(context, user, menuItems),
                Expanded(
                  child: _currentView == POSView.sales 
                    ? _buildPOSLayout(isMobile, isDesktop)
                    : _buildHistoryLayout(),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(child: _buildFooter()),
            floatingActionButton: (isMobile && _currentView == POSView.sales)
                ? SafeArea(
                    child: FloatingActionButton.extended(
                      onPressed: () => _showMobileCart(),
                      label: const Text('View Cart'),
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.shopping_cart),
                          if (ref.watch(cartProvider).isNotEmpty)
                            Positioned(
                              right: -8,
                              top: -8,
                              child: CircleAvatar(
                                radius: 8,
                                backgroundColor: Colors.red,
                                child: Text(
                                  '${ref.watch(cartProvider).length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  )
                : null,
            ),
          ),
        ),
      ),
    );
  }

  void _showMobileCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        bottom: true,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: _buildCartSection(context, ref)),
            ],
          ),
        ),
      ),
    );
  }

  void _holdCurrentReceipt() {
    final cartItems = ref.read(cartProvider);
    final total = ref.read(cartProvider.notifier).subtotal;
    
    final saleItems = cartItems.map((item) => SaleItem(
      product: item.product,
      quantity: item.quantity,
      priceAtSale: item.priceAtSale,
      originalPrice: item.originalPrice,
      selectedUnit: item.selectedUnit ?? item.product.unit,
    )).toList();

    // Simple mock logic for discount/promo
    ref.read(heldReceiptProvider.notifier).holdReceipt(
      saleItems, total, 0, null, _selectedCustomer?.name, _selectedCustomer?.phone
    );
    ref.read(cartProvider.notifier).clear();
    setState(() => _selectedCustomer = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt held!')));
  }

  Widget _getPaymentMethodIcon(List<PaymentDetail> payments) {
    if (payments.isEmpty) return const SizedBox.shrink();
    if (payments.length > 1) return const Icon(Icons.call_split, size: 12, color: Colors.blue);
    
    final method = payments.first.method;
    switch (method) {
      case PaymentMethod.cash:
        return const Icon(Icons.money, size: 12, color: Colors.green);
      case PaymentMethod.mobileMoney:
        return const Icon(Icons.smartphone, size: 12, color: Colors.orange);
      case PaymentMethod.bankDeposit:
        return const Icon(Icons.account_balance, size: 12, color: Colors.purple);
      case PaymentMethod.card:
        return const Icon(Icons.credit_card, size: 12, color: Colors.indigo);
    }
  }

  void _showHeldReceipts() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l))),
      builder: (context) {
        final held = ref.watch(heldReceiptProvider);
        if (held.isEmpty) {
          return Container(
            height: 200,
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt_rounded, size: 48, color: theme.disabledColor),
                const SizedBox(height: 16),
                const Text('No held receipts found.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Text('HELD TRANSACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  Text('${held.length} Receipts', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: held.length,
                itemBuilder: (context, index) {
                  final h = held[index];
                  final itemsPreview = h.items.take(2).map((i) => i.product.name).join(', ');
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m), side: BorderSide(color: theme.dividerColor)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Held at ${DateFormat('HH:mm:ss').format(h.timestamp)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('₵${h.totalAmount.toStringAsFixed(2)}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(h.customerName ?? 'Walk-in', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 12),
                              Icon(Icons.shopping_basket_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${h.items.length} items', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          if (itemsPreview.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(itemsPreview + (h.items.length > 2 ? '...' : ''), 
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                      onTap: () {
                        // Resume logic
                        ref.read(cartProvider.notifier).clear();
                        for (var item in h.items) {
                          ref.read(cartProvider.notifier).addItemWithCustomPrice(
                            item.product, 
                            item.quantity, 
                            item.priceAtSale, 
                            item.originalPrice,
                            selectedUnit: item.selectedUnit,
                          );
                        }
                        ref.read(heldReceiptProvider.notifier).resumeReceipt(h);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildPOSLayout(bool isMobile, bool isDesktop) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: _buildProductSection(context, ref),
          ),
        ),
        if (!isMobile)
          Container(
            width: isDesktop ? 400 : 300,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : AppColors.borderGray)),
            ),
            child: Material(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: _buildCartSection(context, ref),
            ),
          ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, UserAccount user, List<SidebarItem> menuItems) {
    const currentRoute = '/cashier';
    return AppSidebar(
      userId: user.id,
      userName: user.name,
      userRole: user.activePrimaryRole.name.toUpperCase(),
      currentRoute: currentRoute,
      items: menuItems,
      onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
    );
  }

  List<Product>? _cachedPosProducts;

  List<Product> _getHiveCachedProducts() {
    if (_cachedPosProducts != null && _cachedPosProducts!.isNotEmpty) {
      return _cachedPosProducts!;
    }
    try {
      if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
        final box = Hive.box(OfflineSyncService.productsBoxName);
        if (box.isNotEmpty) {
          _cachedPosProducts = box.values
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .where((p) => !p.isDeleted)
              .toList();
          return _cachedPosProducts!;
        }
      }
    } catch (_) {}
    return [];
  }

  Widget _buildProductSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final productsAsync = ref.watch(productsFutureProvider);
    final isWholesale = ref.watch(isWholesaleProvider);
    final transfers = ref.watch(transferProvider);

    if (user == null) return const SizedBox.shrink();
    int crossAxisCount = ResponsiveLayout.isMobile(context) ? 2 : (ResponsiveLayout.isTablet(context) ? 3 : 4);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        children: [
          // Build controls with ALL standard categories always visible
          // Build controls with ALL categories found in the database, plus standard ones
          _buildPOSControls(['All', ...{...allowedCatalog.keys, ...productsAsync.value?.where((p) => !p.isDeleted).map((p) => _getMappedCategory(p)) ?? {}}]),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final display = products.isNotEmpty ? products : _getHiveCachedProducts();
                return _buildProductGridWidget(display, isWholesale, user, transfers, crossAxisCount, theme);
              },
              loading: () {
                final cached = _getHiveCachedProducts();
                if (cached.isNotEmpty) {
                  return _buildProductGridWidget(cached, isWholesale, user, transfers, crossAxisCount, theme);
                }
                return const Center(child: CircularProgressIndicator());
              },
              error: (err, st) {
                final cached = _getHiveCachedProducts();
                if (cached.isNotEmpty) {
                  return _buildProductGridWidget(cached, isWholesale, user, transfers, crossAxisCount, theme);
                }
                return Center(child: Text('Error: $err'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGridWidget(List<Product> products, bool isWholesale, UserAccount user, List<StockTransfer> transfers, int crossAxisCount, ThemeData theme) {
    final filtered = products
        .where((p) => !p.isDeleted)
        .where((p) {
          final mappedCat = _getMappedCategory(p);
          final matchesCategory = _selectedCategory == 'All' || mappedCat.toUpperCase() == _selectedCategory.toUpperCase() || p.category.toUpperCase() == _selectedCategory.toUpperCase();
          final query = _productSearchQuery.trim().toLowerCase();
          final matchesSearch = query.isEmpty ||
              p.name.toLowerCase().contains(query) ||
              (p.sku != null && p.sku!.toLowerCase().contains(query)) ||
              (p.brand != null && p.brand!.toLowerCase().contains(query));
          return matchesCategory && matchesSearch;
        })
        .toList();

    filtered.sort((a, b) {
      final aIsStocked = a.isUnlimited || a.stockQuantity > 0;
      final bIsStocked = b.isUnlimited || b.stockQuantity > 0;

      final aIsPriced = a.getPrice(isWholesale, customer: _selectedCustomer) > 0.01;
      final bIsPriced = b.getPrice(isWholesale, customer: _selectedCustomer) > 0.01;

      final aIsStockedAndPriced = aIsStocked && aIsPriced;
      final bIsStockedAndPriced = bIsStocked && bIsPriced;

      if (aIsStockedAndPriced != bIsStockedAndPriced) return aIsStockedAndPriced ? -1 : 1;
      if (aIsStocked != bIsStocked) return aIsStocked ? -1 : 1;
      if (aIsPriced != bIsPriced) return aIsPriced ? -1 : 1;
      if (a.stockQuantity != b.stockQuantity) return b.stockQuantity.compareTo(a.stockQuantity);
      return _compareNaturally(a.name, b.name);
    });

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _productSearchQuery.isNotEmpty 
                  ? 'No products match "$_productSearchQuery"'
                  : (_selectedCategory != 'All' ? 'No items in "$_selectedCategory"' : 'No items in this category'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (_selectedCategory != 'All' || _productSearchQuery.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCategory = 'All';
                    _productSearchQuery = '';
                    _posSearchController.clear();
                  });
                },
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Show All Products', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }

    final cartItems = ref.watch(cartProvider);
    final cartQtyMap = <String, double>{
      for (final item in cartItems) item.product.id: item.quantity,
    };

    final saleReturns = ref.watch(saleReturnProvider).value ?? [];
    final refundedQtyMap = <String, double>{};
    final swappedQtyMap = <String, double>{};

    for (final ret in saleReturns) {
      for (final item in ret.items) {
        if (item.returnToStock) {
          refundedQtyMap[item.product.id] = (refundedQtyMap[item.product.id] ?? 0.0) + item.quantityReturned;
        }
      }
      if (ret.isProductSwap && ret.replacementProductId != null) {
        swappedQtyMap[ret.replacementProductId!] = (swappedQtyMap[ret.replacementProductId!] ?? 0.0) + (ret.replacementQuantity ?? 0.0);
      }
    }

    final inTransitSet = <String>{};
    final transferWeightMap = <String, double>{};

    for (final t in transfers) {
      final mType = t.meatType.toLowerCase();
      String cutToMatch = mType;
      if (mType.contains(' - ')) {
        cutToMatch = mType.split(' - ').last.trim();
      }

      if (t.status == TransferStatus.pending && t.destination == user.branchCode) {
        inTransitSet.add(cutToMatch);
        inTransitSet.add(mType);
      }

      if (t.status == TransferStatus.received || t.destination == user.branchCode) {
        transferWeightMap[cutToMatch] = (transferWeightMap[cutToMatch] ?? 0.0) + t.weight;
        transferWeightMap[mType] = (transferWeightMap[mType] ?? 0.0) + t.weight;
      }
    }

    return GridView.builder(
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.s,
        mainAxisSpacing: AppSpacing.s,
        childAspectRatio: ResponsiveLayout.isMobile(context) ? 0.65 : (ResponsiveLayout.isTablet(context) ? 0.75 : 0.8),
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final product = filtered[index];
        final pNameLower = product.name.toLowerCase();

        final mappedCat = _getMappedCategory(product);
        final hasPromo = product.isPromoActiveFor(isWholesale, _selectedCustomer);
        final currentPrice = product.getPrice(isWholesale, customer: _selectedCustomer);
        final isPriced = currentPrice > 0.01;
        
        final bool productInTransit = inTransitSet.contains(pNameLower);

        double dispatchedQty = product.dailyStockAdded;
        if (dispatchedQty <= 0) {
          dispatchedQty = transferWeightMap[pNameLower] ?? 0.0;
        }

        final double? cartQty = cartQtyMap[product.id];
        final double? refundedQty = refundedQtyMap[product.id];
        final double? swappedQty = swappedQtyMap[product.id];

        final bool isDisabledInMode = isWholesale ? !product.allowWholesale : !product.allowRetail;
        final String? disabledLabel = !product.allowRetail 
            ? 'WHOLESALE ONLY' 
            : (!product.allowWholesale ? 'RETAIL ONLY' : null);

        return RepaintBoundary(
          child: ProductCard(
            name: product.name,
            category: mappedCat,
            price: isPriced ? '₵${currentPrice.toStringAsFixed(2)}/${product.unit}' : 'UNPRICED',
            originalPrice: hasPromo ? '₵${(isWholesale ? product.wholesalePrice : product.retailPrice).toStringAsFixed(2)}' : null,
            stockQuantity: product.stockQuantity,
            isUnlimited: product.isUnlimited,
            lowStockThreshold: product.lowStockThreshold,
            unit: product.unit,
            size: product.size,
            promoLabel: hasPromo ? '${product.discountPercentage % 1 == 0 ? product.discountPercentage.toInt() : product.discountPercentage}% OFF' : null,
            imageUrl: product.imageUrl,
            isInTransit: productInTransit,
            dispatchedQuantity: dispatchedQty > 0 ? dispatchedQty : null,
            isDispatchedFromWarehouse: dispatchedQty > 0,
            cartQuantity: cartQty,
            refundedQuantity: (refundedQty != null && refundedQty > 0) ? refundedQty : null,
            swappedQuantity: (swappedQty != null && swappedQty > 0) ? swappedQty : null,
            allowRetail: product.allowRetail,
            allowWholesale: product.allowWholesale,
            isDisabledMode: isDisabledInMode,
            modeDisabledLabel: disabledLabel,
            onTap: (isPriced && !isDisabledInMode) ? () => _showWeightInputDialog(product) : () {
              if (isDisabledInMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${product.name}" is ${disabledLabel?.toLowerCase() ?? "not available in this mode"}.')),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('This product is not yet priced. Please contact Admin.')),
              );
            },
            onQuickAdd: (isPriced && !isDisabledInMode) ? () => _showWeightInputDialog(product) : null,
          ),
        );
      },
    );
  }

  Widget _buildPOSControls(List<String> categories) {
    final appSettings = ref.watch(appSettingsProvider);
    final enableWholesale = appSettings.enableWholesale;
    final isWholesale = enableWholesale && ref.watch(isWholesaleProvider);
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);
    final bool isPcScreen = ResponsiveLayout.isDesktop(context) ||
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    final IconData scannerIcon = isPcScreen ? Icons.qr_code_scanner_rounded : Icons.camera_alt_rounded;
    final String scannerTooltip = isPcScreen ? 'Scan Barcode / USB Scanner' : 'Scan Barcode with Camera';
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 45,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: enableWholesale
                    ? Row(
                        children: [
                          Expanded(child: _modeButton('Retail', !isWholesale)),
                          Expanded(child: _modeButton('Wholesale', isWholesale)),
                        ],
                      )
                    : Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.storefront_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Retail Sales Register',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: AppSpacing.m),
              SizedBox(
                width: 200,
                child: _buildCategoryDropdown(categories),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 45,
                child: TextField(
                  controller: _posSearchController,
                  focusNode: _posSearchFocusNode,
                  onChanged: (v) => setState(() => _productSearchQuery = v),
                  onSubmitted: (v) => _handleBarcodeScan(v),
                  decoration: InputDecoration(
                    hintText: 'Search or scan barcode...',
                    prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_posSearchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _posSearchController.clear();
                              setState(() => _productSearchQuery = '');
                            },
                          ),
                        IconButton(
                          icon: Icon(scannerIcon, color: theme.colorScheme.primary),
                          tooltip: scannerTooltip,
                          onPressed: () => _openCameraScanner(context),
                        ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                ),
              ),
            ),
            if (isMobile) ...[
              const SizedBox(width: AppSpacing.s),
              IconButton.filledTonal(
                icon: Icon(scannerIcon),
                tooltip: scannerTooltip,
                onPressed: () => _openCameraScanner(context),
              ),
              const SizedBox(width: AppSpacing.s),
              SizedBox(
                width: 110,
                child: _buildCategoryDropdown(categories),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(List<String> categories) {
    return DropdownButtonFormField<String>(
      initialValue: categories.contains(_selectedCategory) ? _selectedCategory : 'All',
      isExpanded: true, // Crucial for preventing internal overflow
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
        isDense: true,
      ),
      items: categories.map((c) => DropdownMenuItem(
        value: c, 
        child: Text(c, 
          style: const TextStyle(fontSize: 12), 
          overflow: TextOverflow.ellipsis
        )
      )).toList(),
      onChanged: (v) => setState(() {
        _selectedCategory = v!;
        _productSearchQuery = ''; 
      }),
    );
  }

  Widget _modeButton(String label, bool isSelected) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        final newMode = label == 'Wholesale';
        if (ref.read(cartProvider).isNotEmpty) {
          _confirmModeChange(newMode);
        } else {
          ref.read(isWholesaleProvider.notifier).state = newMode;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.m - 4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _confirmModeChange(bool newMode) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Sale Mode?'),
        content: const Text('Changing the mode (Retail/Wholesale) will CLEAR your current cart because prices vary. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              ref.read(isWholesaleProvider.notifier).state = newMode;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white),
            child: const Text('Clear Cart & Change'),
          ),
        ],
      ),
    );
  }

  void _openCameraScanner(BuildContext context) {
    final bool isPcScreen = ResponsiveLayout.isDesktop(context) ||
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (isPcScreen) {
      _posSearchFocusNode.requestFocus();

      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: Colors.blue, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text('USB Barcode Scanner Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Barcode Scanner Mode Active!\nSearch input is focused and ready.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '• If your USB Barcode Scanner is connected, simply point and scan product barcodes to add them instantly to cart.\n\n'
                '• If no scanner is detected or plugged in, please insert / connect your USB Barcode Scanner into your PC USB port.',
                style: TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                CameraBarcodeScannerDialog.show(
                  context,
                  title: 'Webcam Barcode Scanner',
                  continuous: true,
                  onScanned: (barcode) => _handleBarcodeScan(barcode),
                );
              },
              icon: const Icon(Icons.camera_alt_rounded, size: 16),
              label: const Text('Use Webcam', style: TextStyle(fontSize: 11)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _posSearchFocusNode.requestFocus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚡ Barcode Scanner Input Focused: Ready to scan!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
              label: const Text('Start Scanning', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      return;
    }

    CameraBarcodeScannerDialog.show(
      context,
      title: 'Scan Product Barcode',
      continuous: true,
      onScanned: (barcode) {
        return _handleBarcodeScan(barcode);
      },
    );
  }

  String? _handleBarcodeScan(String rawQuery) {
    final query = rawQuery.replaceAll(RegExp(r'[\r\n\t\x00-\x1F]'), '').trim();
    if (query.isEmpty) return null;

    _posSearchController.clear();
    setState(() {
      _productSearchQuery = '';
    });

    final products = ref.read(productsFutureProvider).value ?? [];
    final isWholesale = ref.read(isWholesaleProvider);

    final matched = products.where((p) => !p.isDeleted).where((p) {
      final skuMatch = p.sku != null && p.sku!.trim().toLowerCase() == query.toLowerCase();
      final idMatch = p.id.trim().toLowerCase() == query.toLowerCase();
      final nameMatch = p.name.trim().toLowerCase() == query.toLowerCase();
      return skuMatch || idMatch || nameMatch;
    }).firstOrNull;

    if (matched != null) {
      final currentPrice = matched.getPrice(isWholesale, customer: _selectedCustomer);
      final basePrice = isWholesale ? matched.wholesalePrice : matched.retailPrice;

      if (currentPrice <= 0.01) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This product is not yet priced. Please contact Admin.')),
        );
        return 'Product not priced: ${matched.name}';
      }

      // Directly auto-fill the cart with 1 unit
      ref.read(cartProvider.notifier).addItemWithCustomPrice(
        matched,
        1.0,
        currentPrice,
        basePrice,
        selectedUnit: 'Pcs',
      );

      FeedbackService.playScannerBeep();

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned: ${matched.name} (+1 added to cart)'),
          duration: const Duration(milliseconds: 1200),
          backgroundColor: AppColors.accentGreen,
        ),
      );

      setState(() {
        _productSearchQuery = '';
      });

      return 'Scanned: ${matched.name} (+1 added)';
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product found for barcode "$query"'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return 'No product found for barcode "$query"';
    }
  }

  void _showWeightInputDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => ProductWeightDialog(
        product: product,
        customer: _selectedCustomer,
        onAdd: (weight, price, original, selectedUnit) {
          ref.read(cartProvider.notifier).addItemWithCustomPrice(
            product, weight, price, original, selectedUnit: selectedUnit,
          );
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} (${WeightConverter.formatShort(weight, unit: selectedUnit)}) added to cart'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCartSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartItems = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_outlined),
              const SizedBox(width: 8),
              const Text('Current Sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                onPressed: () => _showHeldReceipts(),
                icon: const Icon(Icons.list_alt, color: Colors.blue),
                tooltip: 'View Held Receipts',
              ),
              const Spacer(),
              if (cartItems.isNotEmpty)
                IconButton(
                  onPressed: () => _holdCurrentReceipt(),
                  icon: const Icon(Icons.pause_circle_outline, color: Colors.orange),
                  tooltip: 'Hold Receipt',
                ),
              if (cartItems.isNotEmpty)
                IconButton(
                  onPressed: () => notifier.clear(),
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        // Customer Selection
        Material(
          color: Colors.transparent,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline, size: 20),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    _selectedCustomer?.name ?? 'Select Customer', 
                    style: TextStyle(fontWeight: _selectedCustomer != null ? FontWeight.bold : FontWeight.normal, color: theme.colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedCustomer?.isSpecial == true)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade700, width: 0.8),
                    ),
                    child: Text(
                      '⭐ SPECIAL${_selectedCustomer!.specialDiscountPercentage != null ? " • ${_selectedCustomer!.specialDiscountPercentage!.toStringAsFixed(0)}%" : ""}',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                    ),
                  ),
              ],
            ),
            subtitle: _selectedCustomer != null ? Text(_selectedCustomer!.phone, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedCustomer != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () => setState(() => _selectedCustomer = null),
                    tooltip: 'Remove Customer',
                  ),
                IconButton(
                  icon: Icon(_selectedCustomer == null ? Icons.add_circle_outline : Icons.edit, size: 18),
                  onPressed: () => _showCustomerDialog(),
                ),
              ],
            ),
            onTap: () => _showCustomerDialog(),
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: cartItems.isEmpty
              ? Center(child: Text('Cart is empty', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return CartItemTile(
                      category: item.product.category,
                      name: item.product.name,
                      qty: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1),
                      weight: WeightConverter.formatShort(item.quantity, unit: item.selectedUnit ?? item.product.unit),
                      amount: '₵${item.total.toStringAsFixed(2)}',
                      onDelete: () => notifier.removeItem(index),
                      onIncrement: () => notifier.incrementQuantity(index, 1.0),
                      onDecrement: () => notifier.incrementQuantity(index, -1.0),
                      onQuantityTap: () => _showEditCartItemQuantityDialog(index, item),
                    );
                  },
                ),
        ),
        _buildCartSummary(ref),
      ],
    );
  }

  void _showEditCartItemQuantityDialog(int index, CartItem item) {
    final controller = TextEditingController(
      text: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1),
    );
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Text('Edit Quantity: ${item.product.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Quantity (${item.selectedUnit ?? item.product.unit})',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                ),
                const SizedBox(height: 12),
                const Text('Quick Add Presets:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [1, 2, 5, 10, 20, 50, 100].map((preset) {
                    return ActionChip(
                      label: Text('+$preset', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        final currentVal = double.tryParse(controller.text) ?? 0;
                        final newVal = currentVal + preset;
                        controller.text = newVal % 1 == 0 ? newVal.toInt().toString() : newVal.toStringAsFixed(1);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final newQty = double.tryParse(controller.text.trim());
                if (newQty != null && newQty > 0) {
                  ref.read(cartProvider.notifier).updateQuantity(index, newQty);
                }
                Navigator.pop(context);
              },
              child: const Text('SET QUANTITY'),
            ),
          ],
        );
      },
    );
  }



  Future<void> _showCustomerDialog({bool isBulk = false}) async {
    await showDialog(
      context: context,
      builder: (context) => CustomerSelectionDialog(
        isBulk: isBulk,
        onSelected: (customer) {
          setState(() {
            _selectedCustomer = customer;
            
            // Auto-Switch Sale Mode based on customer type
            final isWholesale = ref.read(isWholesaleProvider);
            if (customer.isWholesaler && !isWholesale) {
              // Suggest switching to wholesale or just do it?
              // For now, let's just do it to be fast, but clear the cart as required
              if (ref.read(cartProvider).isEmpty) {
                ref.read(isWholesaleProvider.notifier).state = true;
              } else {
                _showModeSwitchOnCustomerSelect(true);
              }
            } else if (!customer.isWholesaler && isWholesale) {
              if (ref.read(cartProvider).isEmpty) {
                ref.read(isWholesaleProvider.notifier).state = false;
              } else {
                _showModeSwitchOnCustomerSelect(false);
              }
            }
          });
        },
      ),
    );
  }

  void _showModeSwitchOnCustomerSelect(bool targetWholesale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${targetWholesale ? "Wholesaler" : "Retailer"} Detected'),
        content: Text('This customer is registered as a ${targetWholesale ? "Wholesaler" : "Retailer"}. Would you like to switch the sale mode? \n\n(This will CLEAR your current cart)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('KEEP CURRENT')),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clear();
              ref.read(isWholesaleProvider.notifier).state = targetWholesale;
              Navigator.pop(context);
            },
            child: const Text('SWITCH MODE & CLEAR'),
          ),
        ],
      ),
    );
  }

  void _quickExactCashCheckout(double finalTotal, double discount, String promo) {
    if (_isProcessingCheckout || ref.read(cartProvider).isEmpty) return;

    setState(() => _isProcessingCheckout = true);
    HapticFeedback.mediumImpact();

    final payments = [
      PaymentDetail(
        method: PaymentMethod.cash,
        amount: finalTotal,
      )
    ];

    _completeSale(ref, payments, finalTotal, discount, promo);
  }

  Widget _buildCartSummary(WidgetRef ref) {
    final theme = Theme.of(context);
    final cartItems = ref.watch(cartProvider);
    final isWholesale = ref.watch(isWholesaleProvider);
    final subtotal = ref.watch(cartProvider.notifier).subtotal;

    // Promotion & Special Discount Logic
    double discountPercentage = 0;
    String promoLabel = '';
    bool promoAvailable = false;
    final bool promoAlreadyUsedToday = _selectedCustomer?.hasUsedDailyPromoToday ?? false;

    if (subtotal > 0 && _selectedCustomer != null) {
      if (_selectedCustomer!.isSpecial || (_selectedCustomer!.specialDiscountPercentage != null && _selectedCustomer!.specialDiscountPercentage! > 0)) {
        final pct = (_selectedCustomer!.specialDiscountPercentage ?? 10.0) / 100.0;
        discountPercentage = pct;
        promoLabel = 'Special Customer Discount (${(_selectedCustomer!.specialDiscountPercentage ?? 10.0).toStringAsFixed(0)}% OFF)';
        promoAvailable = true;
      } else if (isWholesale) {
        final totalWeight = cartItems.fold(0.0, (sum, item) => sum + item.quantity);
        final bool isFavorite = _selectedCustomer?.isFavorite ?? false;
        
        if (isFavorite) {
          discountPercentage = 0.10;
          promoLabel = '${cartItems.first.product.category} - Favorite Customer Reward (10% OFF)';
          promoAvailable = true;
        } else if (totalWeight >= 10) {
          discountPercentage = 0.05;
          promoLabel = '${cartItems.first.product.category} - Bulk Purchase Reward (5% OFF)';
          promoAvailable = true;
        }
      }
    } else if (isWholesale && subtotal > 0) {
      final totalWeight = cartItems.fold(0.0, (sum, item) => sum + item.quantity);
      if (totalWeight >= 10) {
        discountPercentage = 0.05;
        promoLabel = '${cartItems.first.product.category} - Bulk Purchase Reward (5% OFF)';
        promoAvailable = true;
      }
    }

    final bool isPromoActive = promoAvailable && _applyDailyPromo && !promoAlreadyUsedToday;
    final discount = isPromoActive ? (subtotal * discountPercentage) : 0.0;
    final total = subtotal - discount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          if (promoAvailable && promoAlreadyUsedToday)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(AppRadius.s),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_busy_rounded, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daily promo already used today by ${_selectedCustomer!.name}. (Once-a-day limit reached)',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else if (promoAvailable)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _applyDailyPromo ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppRadius.s),
                border: Border.all(color: _applyDailyPromo ? Colors.green.shade300 : Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: _applyDailyPromo ? Colors.green.shade800 : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(promoLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _applyDailyPromo ? Colors.green.shade900 : Colors.grey.shade700)),
                        Text('Promo selected once a day per customer', style: TextStyle(fontSize: 9, color: _applyDailyPromo ? Colors.green.shade700 : Colors.grey)),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: _applyDailyPromo,
                    activeColor: Colors.green.shade700,
                    onChanged: (val) => setState(() => _applyDailyPromo = val ?? true),
                  ),
                ],
              ),
            ),
          if (discount > 0) ...[
            _summaryRow('Subtotal', '₵${subtotal.toStringAsFixed(2)}', fontSize: 13),
            _summaryRow(promoLabel, '-₵${discount.toStringAsFixed(2)}', color: Colors.green, fontSize: 12),
            const SizedBox(height: 8),
          ],
          _summaryRow('TOTAL DUE', '₵${total.toStringAsFixed(2)}', isBold: true, fontSize: 20, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (cartItems.isEmpty || _isProcessingCheckout) ? null : () => _quickExactCashCheckout(total, discount, promoLabel),
                    icon: _isProcessingCheckout
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.flash_on_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _isProcessingCheckout 
                            ? 'PROCESSING...' 
                            : 'EXACT CASH\n(₵${total.toStringAsFixed(2)})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, height: 1.1),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      disabledBackgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (cartItems.isEmpty || _isProcessingCheckout) ? null : () => _showPaymentDialog(total, discount, promoLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      disabledBackgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                    ),
                    child: Text(
                      _isProcessingCheckout ? 'PROCESSING...' : 'PAYMENT OPTIONS',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: (cartItems.isEmpty || _isProcessingCheckout) ? null : () => _showDebtSaleDialog(total, discount, promoLabel),
              icon: const Icon(Icons.money_off, size: 18),
              label: const Text('SAVE AS DEBT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                disabledForegroundColor: Colors.grey.shade400,
                side: BorderSide(color: _isProcessingCheckout ? Colors.grey.shade300 : Colors.orange.shade800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 14, Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, 
              style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color ?? theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  void _showDebtSaleDialog(double finalTotal, double discount, String promo) async {
    // 1. Force Customer Selection if none selected
    if (_selectedCustomer == null) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Row(
            children: [
              Icon(Icons.person_search, color: Colors.blue),
              SizedBox(width: 12),
              Text('Customer Required'),
            ],
          ),
          content: const Text('This is a debt sale. You must select an existing customer profile or register a new one to proceed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'), 
              child: const Text('CANCEL SALE')
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'new'), 
              child: const Text('REGISTER NEW')
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'select'), 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text('SELECT CUSTOMER')
            ),
          ],
        ),
      );

      if (choice == 'select') {
        await _showCustomerDialog();
      } else if (choice == 'new') {
        await _showCustomerRegistrationDialog();
      } else {
        return; // User canceled or dismissed
      }
    }

    // Safety: If still null after selection flow, stop.
    if (_selectedCustomer == null) return;

    // 2. Partial Payment Dialog with Change Option
    final partialPaymentController = TextEditingController();
    
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Row(
            children: [
              Icon(Icons.money_off, color: Colors.orange),
              SizedBox(width: 12),
              Text('Confirm Debt Sale'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('Recording debt for ${_selectedCustomer!.name}.', style: const TextStyle(fontSize: 13))),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close confirm
                      await _showCustomerDialog(); // Select new
                      _showDebtSaleDialog(finalTotal, discount, promo); // Restart flow
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('CHANGE', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Total Amount: ₵${finalTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: partialPaymentController,
                decoration: const InputDecoration(
                  labelText: 'Partial Cash Payment (Optional)',
                  prefixText: '₵ ',
                  border: OutlineInputBorder(),
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              const Text('The balance will be saved as outstanding debt.', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                final double partial = double.tryParse(partialPaymentController.text) ?? 0;
                List<PaymentDetail> payments = [];
                if (partial > 0) {
                  payments.add(PaymentDetail(
                    method: PaymentMethod.cash, 
                    amount: partial,
                  ));
                }
                Navigator.pop(context);
                _completeSale(ref, payments, finalTotal, discount, promo);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              child: const Text('CONFIRM DEBT SALE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerRegistrationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => CustomerSelectionDialog(
        isBulk: true, // Forces "New Customer" view
        onSelected: (customer) {
          setState(() {
            _selectedCustomer = customer;
          });
        },
      ),
    );
  }

  void _showPaymentDialog(double finalTotal, double discount, String promo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentDialog(
        totalAmount: finalTotal,
        onComplete: (payments, receiptUrl) {
          setState(() => _uploadedReceiptUrl = receiptUrl);
          _completeSale(ref, payments, finalTotal, discount, promo);
        },
      ),
    );
  }

  void _completeSale(WidgetRef ref, List<PaymentDetail> payments, double finalTotal, double discount, String promo) async {
    if (!_isProcessingCheckout) {
      setState(() => _isProcessingCheckout = true);
    }

    try {
      final cartItems = ref.read(cartProvider);
      final currentUser = ref.read(currentUserProvider);
      
      final double amountPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
      final double balance = finalTotal - amountPaid;
      final double totalCost = cartItems.fold(0.0, (sum, item) => sum + (item.product.costPrice * item.quantity));

      // Debt Enforcement: If there's a balance, a customer MUST be selected
      if (balance > 0.01 && _selectedCustomer == null) {
        final proceed = await _showDebtCustomerRequiredDialog();
        if (!proceed) {
          if (mounted) setState(() => _isProcessingCheckout = false);
          return;
        }
        
        // Open customer dialog and wait for it
        await _showCustomerDialog();
        
        // If they registered/selected a customer, _selectedCustomer will be non-null now
        if (_selectedCustomer == null) {
          if (mounted) setState(() => _isProcessingCheckout = false);
          return;
        }
      }

      final hasBankDeposit = payments.any((p) => p.method == PaymentMethod.bankDeposit);

      final sale = SaleRecord(
        id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        items: cartItems.map((item) => SaleItem(
          product: item.product,
          quantity: item.quantity,
          priceAtSale: item.priceAtSale,
          originalPrice: item.originalPrice,
          selectedUnit: item.selectedUnit ?? item.product.unit,
        )).toList(),
        totalAmount: finalTotal,
        totalDiscount: discount,
        totalCost: totalCost,
        appliedPromo: promo.isEmpty ? null : promo,
        payments: payments,
        timestamp: DateTime.now(),
        cashierName: currentUser != null ? '${currentUser.firstName} ${currentUser.surname}' : 'Unknown Cashier',
        cashierId: currentUser?.id ?? 'N/A',
        customerName: _selectedCustomer?.name,
        customerPhone: _selectedCustomer?.phone,
        status: hasBankDeposit ? SaleStatus.awaitingDeposit : SaleStatus.completed,
        isVerified: !hasBankDeposit, // Cash/MoMo sales are verified immediately
        bankReceiptUrl: _uploadedReceiptUrl,
      );

      await ref.read(saleHistoryProvider.notifier).addSale(sale);

      // Record promo usage on customer if a promotional discount was applied
      if (_selectedCustomer != null && discount > 0) {
        final updatedCustomer = _selectedCustomer!.copyWith(lastPromoDate: DateTime.now());
        ref.read(customerProvider.notifier).updateCustomer(updatedCustomer);
      }

      ref.read(cartProvider.notifier).clear();
      
      // Send SMS with branch identification only if fully paid (NOT a debt)
      if (sale.balance <= 0.01) {
        final currentBranch = ref.read(currentBranchProvider);
        final String? branchName = currentBranch != null 
            ? '${currentBranch.name} (${currentBranch.location})' 
            : null;

        SmsService.sendReceiptSms(sale, discountAmount: discount, branchName: branchName);
      }

      setState(() {
        _selectedCustomer = null;
        _uploadedReceiptUrl = null;
        _applyDailyPromo = true;
      });

      _showPrintConfirmation(sale);
    } catch (e) {
      debugPrint('Checkout error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingCheckout = false);
      }
    }
  }

  Future<bool> _showDebtCustomerRequiredDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Customer Required', 
                style: TextStyle(fontSize: ResponsiveLayout.isMobile(context) ? 18 : null),
                overflow: TextOverflow.ellipsis
              ),
            ),
          ],
        ),
        content: const Text(
          'This transaction has an outstanding balance (Debt). \n\n'
          'To track this debt, you must select or register a customer before completing the sale.'
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel Sale'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMaroon, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const FittedBox(
                    child: Text('Register / Select Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _resetToPOSScreen() {
    Navigator.of(context).popUntil((route) => route.settings.name == '/cashier' || route.isFirst);
    if (mounted) {
      setState(() {
        _currentView = POSView.sales;
        _selectedCustomer = null;
      });
      ref.read(cartProvider.notifier).clear();
      _posSearchFocusNode.requestFocus();
    }
  }

  void _showPrintConfirmation(SaleRecord sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptSuccessDialog(
        sale: sale,
        ref: ref,
        onNextCustomer: () => _resetToPOSScreen(),
      ),
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _footerAction(Icons.point_of_sale, 'New Sale', _currentView == POSView.sales, () => setState(() => _currentView = POSView.sales)),
          _footerAction(Icons.history, 'Transaction History', _currentView == POSView.history, () => setState(() => _currentView = POSView.history)),
        ],
      ),
    );
  }

  Widget _footerAction(IconData icon, String label, bool isSelected, VoidCallback onTap, {int? badge}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              Text(label, style: TextStyle(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
          if (badge != null && badge > 0)
            Positioned(
              right: -4,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDateFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.today),
            title: const Text('Today'),
            onTap: () {
              final now = DateTime.now();
              setState(() => _historyDateRange = DateTimeRange(start: now, end: now));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Yesterday'),
            onTap: () {
              final yesterday = DateTime.now().subtract(const Duration(days: 1));
              setState(() => _historyDateRange = DateTimeRange(start: yesterday, end: yesterday));
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Specific Day'),
            onTap: () async {
              Navigator.pop(context);
              final picked = await showDatePicker(
                context: context,
                initialDate: _historyDateRange?.start ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _historyDateRange = DateTimeRange(start: picked, end: picked));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Date Range'),
            onTap: () async {
              Navigator.pop(context);
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _historyDateRange,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _historyDateRange = picked);
              }
            },
          ),
          const SizedBox(height: AppSpacing.l),
        ],
      ),
    );
  }

  Widget _buildHistoryLayout() {
    final theme = Theme.of(context);
    final salesHistory = ref.watch(saleHistoryProvider);
    final filteredHistory = salesHistory.where((s) {
      final matchesSearch = s.id.toLowerCase().contains(_historySearchQuery.toLowerCase());
      
      bool matchesDate = true;
      if (_historyDateRange != null) {
        final start = DateTime(_historyDateRange!.start.year, _historyDateRange!.start.month, _historyDateRange!.start.day);
        final end = DateTime(_historyDateRange!.end.year, _historyDateRange!.end.month, _historyDateRange!.end.day, 23, 59, 59);
        matchesDate = s.timestamp.isAfter(start.subtract(const Duration(seconds: 1))) && 
                      s.timestamp.isBefore(end.add(const Duration(seconds: 1)));
      }
      
      return matchesSearch && matchesDate;
    }).toList();

    // Stats calculations
    double totalSales = 0;
    double totalCost = 0;
    final Map<String, ({double qty, String category})> productStatsMap = {};

    for (var sale in filteredHistory) {
      if (!sale.isActive) continue;
      totalSales += sale.totalAmount;
      totalCost += sale.totalCost;
      for (var item in sale.items) {
        final existing = productStatsMap[item.product.name];
        productStatsMap[item.product.name] = (
          qty: (existing?.qty ?? 0) + item.quantity,
          category: item.product.category
        );
      }
    }
    final totalProfit = totalSales - totalCost;

    return Column(
      children: [
        // Non-scrollable Header (Date Filter)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.l, AppSpacing.l, 0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _showDateFilterOptions(context),
                  icon: const Icon(Icons.date_range),
                  label: Text(_historyDateRange == null 
                    ? 'Select Date' 
                    : _historyDateRange!.start.day == _historyDateRange!.end.day && 
                      _historyDateRange!.start.month == _historyDateRange!.end.month && 
                      _historyDateRange!.start.year == _historyDateRange!.end.year
                      ? DateFormat('MMM dd').format(_historyDateRange!.start)
                      : '${DateFormat('MMM dd').format(_historyDateRange!.start)} - ${DateFormat('MMM dd').format(_historyDateRange!.end)}'),
                ),
              ),
              if (_historyDateRange != null)
                IconButton(
                  onPressed: () => setState(() => _historyDateRange = null),
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  tooltip: 'Clear Filter',
                ),
              if (_historyDateRange != null && filteredHistory.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final period = '${DateFormat('MMM dd, yyyy').format(_historyDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_historyDateRange!.end)}';
                      ReceiptService.printDetailedHistoryReport(filteredHistory, period: period);
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('PRINT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Scrollable Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filteredHistory.isNotEmpty) ...[
                  _buildHistorySummaryCards(totalSales, totalProfit, theme),
                  const SizedBox(height: 24),
                  Text('SALES TREND', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _buildSalesChart(filteredHistory, theme),
                  const SizedBox(height: 24),
                  Text('HIGHEST PURCHASED PRODUCTS', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _buildProductQtyList(productStatsMap, theme),
                  const SizedBox(height: 24),
                ],

                Text('TRANSACTION LOG', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                filteredHistory.isEmpty 
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('No transactions found.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final sale = filteredHistory[index];
                        return _buildHistoryCard(sale);
                      },
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(SaleRecord sale) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(Icons.receipt_long, color: theme.colorScheme.primary, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(sale.id, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
                overflow: TextOverflow.ellipsis
              ),
            ),
            const SizedBox(width: 8),
            Text('₵${sale.totalAmount.toStringAsFixed(2)}', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${DateFormat('HH:mm').format(sale.timestamp)} • ${sale.items.length} items', style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 8),
                _getPaymentMethodIcon(sale.payments),
                if (sale.status != SaleStatus.completed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _getStatusColor(sale.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _getStatusColor(sale.status).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      sale.status.name.toUpperCase(),
                      style: TextStyle(color: _getStatusColor(sale.status), fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            Text('Cust: ${sale.customerName ?? "Walk-in"}', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _showSaleDetails(sale),
      ),
    );
  }

  Widget _buildHistorySummaryCards(double totalSales, double totalProfit, ThemeData theme) {
    return Row(
      children: [
        _summaryStatCard('TOTAL SALES', '₵${totalSales.toStringAsFixed(2)}', theme.colorScheme.primary, theme),
        const SizedBox(width: 12),
        _summaryStatCard('TOTAL PROFIT', '₵${totalProfit.toStringAsFixed(2)}', AppColors.accentGreen, theme),
      ],
    );
  }

  Widget _summaryStatCard(String label, String value, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart(List<SaleRecord> sales, ThemeData theme) {
    if (sales.isEmpty) return const SizedBox.shrink();

    // Group sales by day (Last 7 days or selected range)
    final now = DateTime.now();
    final List<DateTime> dates = [];
    bool isSingleDay = false;

    if (_historyDateRange != null) {
      DateTime d = _historyDateRange!.start;
      while (d.isBefore(_historyDateRange!.end.add(const Duration(days: 1)))) {
        dates.add(DateTime(d.year, d.month, d.day));
        d = d.add(const Duration(days: 1));
      }
      if (dates.length == 1) isSingleDay = true;
    } else {
      // Default to last 7 days
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        dates.add(DateTime(d.year, d.month, d.day));
      }
    }

    final List<double> chartData;
    final List<String> labels;

    if (isSingleDay) {
      // Hourly breakdown for single day
      final targetDate = dates.first;
      // We'll show blocks: 8am, 10am, 12pm, 2pm, 4pm, 6pm, 8pm (common business hours)
      final hours = [8, 10, 12, 14, 16, 18, 20];
      chartData = hours.map((h) {
        return sales
            .where((s) => s.timestamp.year == targetDate.year && 
                          s.timestamp.month == targetDate.month && 
                          s.timestamp.day == targetDate.day &&
                          s.timestamp.hour >= h && s.timestamp.hour < h + 2 &&
                          s.isActive)
            .fold(0.0, (sum, s) => sum + s.totalAmount);
      }).toList();
      labels = hours.map((h) => '${h > 12 ? h - 12 : h}${h >= 12 ? 'pm' : 'am'}').toList();
    } else {
      chartData = dates.map((date) {
        return sales
            .where((s) => s.timestamp.year == date.year && s.timestamp.month == date.month && s.timestamp.day == date.day && s.isActive)
            .fold(0.0, (sum, s) => sum + s.totalAmount);
      }).toList();
      labels = dates.map((d) => DateFormat('E').format(d).substring(0, 1)).toList();
    }

    final maxTotal = chartData.isEmpty ? 100.0 : (chartData.reduce((a, b) => a > b ? a : b) + 50.0);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: theme.dividerColor),
      ),
      child: () {
        final isDark = theme.brightness == Brightness.dark;
        final Color chartColor = isDark
            ? (theme.colorScheme.primary.computeLuminance() < 0.2 ? Colors.amber : theme.colorScheme.primary)
            : (theme.colorScheme.primary.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : theme.colorScheme.primary);

        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxTotal,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '₵${rod.toY.toStringAsFixed(0)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < labels.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(chartData.length, (index) {
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: chartData[index],
                    color: chartColor,
                    width: isSingleDay ? 24 : 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }),
          ),
        );
      }(),
    );
  }

  Widget _buildProductQtyList(Map<String, ({double qty, String category})> statsMap, ThemeData theme) {
    final sortedProducts = statsMap.entries.toList()
      ..sort((a, b) => b.value.qty.compareTo(a.value.qty));
    
    final totalQty = statsMap.values.fold(0.0, (sum, val) => sum + val.qty);

    return Column(
      children: sortedProducts.take(10).map((e) {
        final double percentage = totalQty > 0 ? (e.value.qty / totalQty) : 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.s),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(e.value.category.toUpperCase(), style: TextStyle(fontSize: 9, color: theme.colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  Text(WeightConverter.formatShort(e.value.qty, unit: 'kg'), 
                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 6,
                  backgroundColor: theme.dividerColor,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showReceiptOptionsDialog(SaleRecord sale) {
    final currentBranch = ref.read(currentBranchProvider);
    bool isProcessing = false;
    final isDebt = sale.balance > 0.01;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Rectangular
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.primaryMaroon),
              SizedBox(width: 12),
              Text('RECEIPT OPTIONS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 16)),
            ],
          ),
          content: isProcessing 
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _receiptOptionTile(
                    context,
                    icon: Icons.print_rounded,
                    title: 'PRINT RECEIPT',
                    subtitle: 'Send to thermal printer',
                    onTap: () async {
                      setState(() => isProcessing = true);
                      await ReceiptService.printReceipt(sale);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 10),
                  _receiptOptionTile(
                    context,
                    icon: Icons.sms_rounded,
                    title: 'SEND VIA SMS',
                    subtitle: isDebt 
                        ? 'Disabled for debts • Send reminder from Debt Tracker' 
                        : (sale.customerPhone ?? 'Enter custom number'),
                    enabled: !isDebt,
                    onTap: () async {
                      if (isDebt) return;
                      String? targetPhone = sale.customerPhone;
                      
                      if (targetPhone == null || targetPhone.isEmpty) {
                        targetPhone = await PhonePromptDialog.show(context);
                      }

                      if (targetPhone != null && targetPhone.isNotEmpty) {
                        setState(() => isProcessing = true);
                        final success = await SmsService.sendReceiptSms(
                          sale, 
                          branchName: currentBranch?.name,
                          customPhone: targetPhone,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'SMS Sent' : 'SMS Failed'),
                              backgroundColor: success ? Colors.green : Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _receiptOptionTile(
                    context,
                    icon: Icons.share_rounded,
                    title: 'SHARE PDF (WHATSAPP)',
                    subtitle: 'Share via WhatsApp or Email',
                    onTap: () async {
                      setState(() => isProcessing = true);
                      await ReceiptService.shareReceipt(sale);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptOptionTile(BuildContext context, {
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? theme.colorScheme.primary.withValues(alpha: 0.05) : theme.disabledColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: enabled ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.disabledColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: enabled ? theme.colorScheme.primary : theme.disabledColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: enabled ? theme.colorScheme.onSurface : theme.disabledColor, letterSpacing: 0.5)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (enabled) Icon(Icons.keyboard_arrow_right_rounded, color: theme.colorScheme.primary.withValues(alpha: 0.3), size: 18),
          ],
        ),
      ),
    );
  }

  void _showSaleDetails(SaleRecord sale) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
            backgroundColor: theme.colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Transaction Details',
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                sale.id,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('STATUS', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(sale.status).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sale.status.name.toUpperCase(),
                                        style: TextStyle(color: _getStatusColor(sale.status), fontSize: 10, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('DATE', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMM dd, yyyy HH:mm').format(sale.timestamp), 
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.right,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: AppColors.textLight),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CUSTOMER', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                    Text(sale.customerName ?? 'Walk-in Customer', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('CASHIER', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                    Text(sale.cashierName.split(' ')[0], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Text('ITEMS', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ...sale.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.product.category.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      Text(item.product.name, 
                                        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text('${WeightConverter.formatShort(item.quantity, unit: item.selectedUnit ?? item.product.unit)} x ₵${item.priceAtSale.toStringAsFixed(2)}', 
                                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text('₵${item.total.toStringAsFixed(2)}', 
                                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontSize: 13)
                                ),
                              ],
                            ),
                          )),
                          const Divider(height: 32),
                          if (sale.totalDiscount > 0) ...[
                            _detailRow('Gross Amount', '₵${sale.baseTotal.toStringAsFixed(2)}'),
                            _detailRow('Total Discount', '-₵${sale.totalDiscount.toStringAsFixed(2)}', color: Colors.green),
                            const SizedBox(height: 4),
                          ],
                          _detailRow('NET INVOICE VALUE', '₵${sale.netInvoiceValue.toStringAsFixed(2)}', isBold: true, color: theme.colorScheme.primary),
                          const Divider(height: 32),
                          Text('PAYMENT HISTORY', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          ...sale.payments.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      p.method == PaymentMethod.cash ? Icons.money : 
                                      (p.method == PaymentMethod.mobileMoney ? Icons.smartphone : Icons.account_balance), 
                                      size: 14, color: theme.colorScheme.onSurfaceVariant
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      p.method.name.toUpperCase(), 
                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface)
                                    ),
                                    if (p.reference != null)
                                      Text(' (${p.reference})', style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                                Text('₵${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )),
                          if (sale.balance > 0.01) ...[
                             const SizedBox(height: 8),
                             _detailRow('BALANCE DUE', '₵${sale.balance.toStringAsFixed(2)}', color: Colors.red, isBold: true),
                          ],
                          if (sale.bankReceiptUrl != null) ...[
                            const Divider(height: 32),
                            Text('BANK DEPOSIT RECEIPT', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _viewBankReceipt(sale.bankReceiptUrl!, receiptId: sale.bankReceiptId),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: theme.dividerColor),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.image_outlined, size: 20, color: Colors.purple),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('View Uploaded Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                                          if (sale.bankReceiptId != null)
                                            Text('ID: ${sale.bankReceiptId}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.open_in_new, size: 16, color: Colors.purple),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(top: BorderSide(color: theme.dividerColor)),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.l)),
                    ),
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 8,
                      overflowSpacing: 8,
                      children: [
                        if (sale.status != SaleStatus.cancelled && sale.status != SaleStatus.reversed)
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              ProcessReturnDialog.show(context, sale);
                            },
                            icon: const Icon(Icons.assignment_return_rounded, size: 16, color: Colors.red),
                            label: const Text('Return / Refund', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                          ),
                        if (sale.status == SaleStatus.awaitingDeposit)
                          ElevatedButton.icon(
                            onPressed: () => _showBankReceiptUploadDialog(sale),
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text('UPLOAD RECEIPT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                          ),
                        if (!sale.isVerified && sale.status != SaleStatus.awaitingDeposit)
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.read(saleHistoryProvider.notifier).verifySale(sale.id);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Transaction Verified. Inventory updated.'), backgroundColor: Colors.green),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('VERIFY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                          ),
                        if (sale.status == SaleStatus.completed)
                          TextButton.icon(
                            onPressed: () => _showReportErrorDialog(sale),
                            icon: const Icon(Icons.report_problem_outlined, color: Colors.orange, size: 16),
                            label: const Text('Report Error', style: TextStyle(color: Colors.orange, fontSize: 11)),
                          ),
                        TextButton(
                          onPressed: () => Navigator.pop(context), 
                          child: Text('Close', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12))
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showReceiptOptionsDialog(sale),
                          icon: const Icon(Icons.receipt_long_rounded, size: 14),
                          label: const Text('RECEIPT OPTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _showBankReceiptUploadDialog(SaleRecord sale) {
    final receiptIdController = TextEditingController();
    Uint8List? selectedImageBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Row(
            children: [
              Icon(Icons.account_balance, color: Colors.purple),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Complete Bank Deposit',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please provide the bank transaction reference/ID and a photo of the deposit slip.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: receiptIdController,
                    decoration: const InputDecoration(
                      labelText: 'Bank Receipt ID / Reference',
                      hintText: 'e.g. UMB-123456',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                    onChanged: (_) => setState(() {}), // Refresh to enable/disable button
                  ),
                  const SizedBox(height: 16),
                  InkWell(
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
                        setState(() => selectedImageBytes = bytes);
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selectedImageBytes != null ? Colors.purple : Colors.grey.shade300),
                      ),
                      child: selectedImageBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(selectedImageBytes!, fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, color: Colors.purple, size: 32),
                                SizedBox(height: 8),
                                Text('Select Deposit Slip Photo', style: TextStyle(fontSize: 11, color: Colors.purple)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (isUploading || selectedImageBytes == null || receiptIdController.text.isEmpty)
                  ? null
                  : () async {
                      setState(() => isUploading = true);
                      try {
                        final fileName = 'bank_${sale.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                        final url = await ref.read(expenseProvider.notifier).uploadReceipt(selectedImageBytes!, fileName);
                        
                        if (url != null) {
                          await ref.read(saleHistoryProvider.notifier).verifySale(
                            sale.id, 
                            bankReceiptUrl: url,
                            bankReceiptId: receiptIdController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            Navigator.pop(context); // Close sale details
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bank details saved & sale verified!'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => isUploading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              child: isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm & Verify'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewBankReceipt(String url, {String? receiptId}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bank Deposit Slip', style: TextStyle(fontSize: 16)),
                  if (receiptId != null)
                    Text('REF: $receiptId', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(child: Text('Could not load image')),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportErrorDialog(SaleRecord sale) {
    final theme = Theme.of(context);
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: const Row(
          children: [
            Icon(Icons.report_problem_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Report Sale Error'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please describe the error (e.g., wrong weight). This will notify the Admin for rectification.', 
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter reason here...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                ref.read(saleHistoryProvider.notifier).updateSale(
                  sale.copyWith(
                    status: SaleStatus.pendingCorrection,
                    correctionReason: reasonController.text,
                  )
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error reported to Administrator.'), backgroundColor: Colors.orange),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(SaleStatus status) {
    switch (status) {
      case SaleStatus.completed: return Colors.green;
      case SaleStatus.rectified: return Colors.blue;
      case SaleStatus.pendingCorrection: return Colors.orange;
      case SaleStatus.cancelled: return Colors.red;
      case SaleStatus.reversed: return Colors.red.shade900;
      case SaleStatus.awaitingDeposit: return Colors.purple;
    }
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(value, 
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? theme.colorScheme.onSurface)
            ),
          ),
        ],
      ),
    );
  }

  String _getMappedCategory(Product p) {
    final cat = p.category.trim().toUpperCase();
    if (cat.contains('BUILDING') || cat.contains('CEMENT') || cat.contains('SAND') || cat.contains('BLOCK')) return 'BUILDING MATERIALS';
    if (cat.contains('STEEL') || cat.contains('REBAR') || cat.contains('IRON')) return 'STEEL & REBAR';
    if (cat.contains('PLUMBING') || cat.contains('PVC') || cat.contains('PIPE')) return 'PLUMBING & PVC';
    if (cat.contains('ELECTRICAL') || cat.contains('CABLE')) return 'ELECTRICALS';
    if (cat.contains('PAINT') || cat.contains('FINISH')) return 'PAINTS & FINISHES';
    if (cat.contains('ROOF') || cat.contains('TIMBER')) return 'ROOFING & TIMBER';
    if (cat.contains('TOOL') || cat.contains('FASTENER') || cat.contains('NAIL') || cat.contains('SCREW')) return 'TOOLS & FASTENERS';
    return cat.isEmpty ? 'OTHER' : cat;
  }

  int _compareNaturally(String a, String b) {
    final RegExp digitRegex = RegExp(r'(\d+\.?\d*)');
    final Match? aMatch = digitRegex.firstMatch(a);
    final Match? bMatch = digitRegex.firstMatch(b);

    if (aMatch != null && bMatch != null) {
      final aNum = double.tryParse(aMatch.group(0)!) ?? 0;
      final bNum = double.tryParse(bMatch.group(0)!) ?? 0;
      if (aNum != bNum) return aNum.compareTo(bNum);
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}

class ProductWeightDialog extends StatefulWidget {
  final Product product;
  final Customer? customer;
  final Function(double weight, double price, double original, String unit) onAdd;

  const ProductWeightDialog({super.key, required this.product, this.customer, required this.onAdd});

  @override
  State<ProductWeightDialog> createState() => _ProductWeightDialogState();
}

class _ProductWeightDialogState extends State<ProductWeightDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qtyController;
  final _moneyController = TextEditingController();
  
  String _selectedUnit = 'Pcs'; // Default unit

  List<String> get _availableUnits {
    final base = widget.product.unit.trim();
    final defaultBase = base.isNotEmpty ? (base[0].toUpperCase() + base.substring(1)) : 'Pcs';
    final units = <String>[defaultBase];
    if (widget.product.hasPacks && !units.contains('Packs')) units.add('Packs');
    if (widget.product.hasBoxes && !units.contains('Boxes')) units.add('Boxes');
    return units;
  }

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '1');
    final base = widget.product.unit.trim();
    if (base.isNotEmpty) {
      _selectedUnit = base[0].toUpperCase() + base.substring(1);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _moneyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer(
      builder: (context, ref, _) {
        final isWholesale = ref.watch(isWholesaleProvider);
        final basePrice = widget.product.getPrice(isWholesale, customer: widget.customer);
        final originalPrice = isWholesale ? widget.product.wholesalePrice : widget.product.retailPrice;
        final hasPromo = widget.product.isPromoActiveFor(isWholesale, widget.customer);

        // Calculate multipliers
        double pcsMultiplier = 1.0;
        if (_selectedUnit == 'Packs') {
          pcsMultiplier = widget.product.pcsPerPack > 0 ? widget.product.pcsPerPack : 12.0;
        } else if (_selectedUnit == 'Boxes') {
          pcsMultiplier = widget.product.totalPcsPerBox > 0 ? widget.product.totalPcsPerBox : 120.0;
        }

        final double unitPrice = basePrice * pcsMultiplier;
        final double qtyInput = double.tryParse(_qtyController.text) ?? 1.0;
        final double totalPcsNeeded = qtyInput * pcsMultiplier;
        final double totalPrice = unitPrice * qtyInput;

        final bool isOutOfStock = widget.product.stockQuantity <= 0 && !widget.product.isUnlimited;
        final bool isExceedingStock = !widget.product.isUnlimited && totalPcsNeeded > widget.product.stockQuantity;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.product.category.toUpperCase(),
                        style: TextStyle(
                          color: theme.colorScheme.primary, 
                          fontSize: 11, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Product Name
                    Text(
                      widget.product.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Packaging Unit Selector
                    if (_availableUnits.length > 1) ...[
                      const Text(
                        'SELECT UNIT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: _availableUnits.map((u) => ButtonSegment<String>(
                          value: u,
                          label: Text(u.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        )).toList(),
                        selected: {_selectedUnit},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedUnit = newSelection.first;
                            _moneyController.clear();
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],

                    // Quantity Stepper / Input
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HoldToRepeatButton(
                          onPressed: qtyInput > 1 ? () {
                            setState(() {
                              final newQty = (qtyInput - 1).clamp(1.0, 9999.0);
                              _qtyController.text = newQty % 1 == 0 ? newQty.toInt().toString() : newQty.toStringAsFixed(1);
                              _moneyController.clear();
                            });
                          } : null,
                          padding: const EdgeInsets.all(10),
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 20,
                            color: qtyInput > 1 ? theme.colorScheme.primary : theme.disabledColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _qtyController,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Quantity',
                              suffixText: _selectedUnit.toLowerCase(),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              errorText: isExceedingStock ? 'Max: ${widget.product.stockQuantity.toInt()} pcs' : null,
                            ),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            onChanged: (v) {
                              setState(() {});
                              _moneyController.clear();
                            },
                            validator: (v) {
                              if (v == null || (double.tryParse(v) ?? 0) <= 0) return '!';
                              if (isExceedingStock) return 'Out of stock';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        HoldToRepeatButton(
                          onPressed: () {
                            setState(() {
                              final newQty = qtyInput + 1;
                              _qtyController.text = newQty % 1 == 0 ? newQty.toInt().toString() : newQty.toStringAsFixed(1);
                              _moneyController.clear();
                            });
                          },
                          padding: const EdgeInsets.all(10),
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          child: Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Unit Price & Total Calculation
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasPromo) ...[
                                Text('₵${(originalPrice * pcsMultiplier).toStringAsFixed(2)}', 
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, decoration: TextDecoration.lineThrough, fontSize: 12)),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '₵${unitPrice.toStringAsFixed(2)} / ${_selectedUnit.toLowerCase()}', 
                                style: TextStyle(color: hasPromo ? Colors.orange.shade800 : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: ₵${totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: theme.colorScheme.primary),
                          ),
                          if (_selectedUnit != 'Pcs')
                            Text(
                              '(${totalPcsNeeded.toInt()} Pcs Total)',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Out of Stock Alert
                    if (isOutOfStock)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: AppSpacing.m),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 16),
                            SizedBox(width: 8),
                            Text('OUT OF STOCK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),

                    // Add to Cart Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (isOutOfStock || isExceedingStock)
                          ? null 
                          : () {
                            if (_formKey.currentState!.validate()) {
                              widget.onAdd(totalPcsNeeded, basePrice, originalPrice, _selectedUnit);
                              Navigator.pop(context);
                            }
                          },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
                          elevation: 0,
                        ),
                        child: Text(
                          isOutOfStock ? 'OUT OF STOCK' : 'Add to Cart', 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CustomerSelectionDialog extends ConsumerStatefulWidget {
  final Function(Customer) onSelected;
  final bool isBulk;
  const CustomerSelectionDialog({super.key, required this.onSelected, this.isBulk = false});

  @override
  ConsumerState<CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends ConsumerState<CustomerSelectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _locationController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _customerTypeFilter = 'ALL'; // ALL, SPECIAL, FAVORITES, WHOLESALER
  late bool _isNewCustomer;
  bool _isWholesaler = false; // NEW

  @override
  void initState() {
    super.initState();
    _isNewCustomer = widget.isBulk; 
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider);
    final metrics = ref.watch(customerMetricsProvider);
    final theme = Theme.of(context);

    final List<Customer> sortedCustomers = List.from(customers);
    if (_searchQuery.isEmpty) {
      // Sort by spending when not searching
      sortedCustomers.sort((a, b) {
        final spendA = metrics[a.phone]?.totalSpend ?? 0;
        final spendB = metrics[b.phone]?.totalSpend ?? 0;
        return spendB.compareTo(spendA);
      });
    }

    final filtered = sortedCustomers.where((c) {
      if (_customerTypeFilter == 'SPECIAL' && !c.isSpecial) return false;
      if (_customerTypeFilter == 'FAVORITES' && !c.isFavorite) return false;
      if (_customerTypeFilter == 'WHOLESALER' && !c.isWholesaler) return false;

      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) || 
             c.phone.contains(query) ||
             (c.location?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isNewCustomer ? 'REGISTER CUSTOMER' : 'SELECT CUSTOMER',
                      style: TextStyle(
                        color: theme.colorScheme.primary, 
                        fontSize: ResponsiveLayout.isMobile(context) ? 12 : 13, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 1.2
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(_isNewCustomer ? Icons.group_rounded : Icons.person_add_alt_1_rounded, color: theme.colorScheme.primary, size: 20),
                    onPressed: () => setState(() => _isNewCustomer = !_isNewCustomer),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              if (!_isNewCustomer) ...[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name, phone or town...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPosFilterChip('All', 'ALL', theme),
                      const SizedBox(width: 4),
                      _buildPosFilterChip('⭐ Special', 'SPECIAL', theme, color: Colors.amber),
                      const SizedBox(width: 4),
                      _buildPosFilterChip('★ Favorites', 'FAVORITES', theme, color: Colors.orange),
                      const SizedBox(width: 4),
                      _buildPosFilterChip('Wholesale', 'WHOLESALER', theme, color: Colors.purpleAccent),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                    ? const Center(child: Text('No matching customers found.', style: TextStyle(color: AppColors.textLight, fontSize: 12)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              child: Icon(c.isFavorite ? Icons.star : Icons.person,
                                  color: c.isFavorite ? Colors.orange : theme.colorScheme.primary, size: 20),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text(
                              '${c.isWholesaler ? "WHOLESALER" : "RETAILER"} • ${c.phone}${c.location != null ? " • ${c.location}" : ""}', 
                              style: TextStyle(fontSize: 10, color: c.isWholesaler ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, fontWeight: c.isWholesaler ? FontWeight.bold : FontWeight.normal)
                            ),
                            trailing: c.isSpecial
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber, width: 0.8),
                                    ),
                                    child: Text(
                                      c.specialDiscountPercentage != null && c.specialDiscountPercentage! > 0
                                          ? '⭐ ${c.specialDiscountPercentage!.toStringAsFixed(0)}% OFF'
                                          : '⭐ VIP',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              widget.onSelected(c);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                ),
              ] else ...[
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_outlined)),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(labelText: 'Primary Phone', prefixIcon: Icon(Icons.phone_outlined)),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                            validator: (v) => v!.length != 10 ? 'Invalid' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone2Controller,
                            decoration: const InputDecoration(labelText: 'Alternative Phone (Optional)', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(labelText: 'Location / Area', prefixIcon: Icon(Icons.location_on_outlined)),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Customer Category', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: Center(
                                    child: Text(
                                      'RETAILER',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: !_isWholesaler ? const Color(0xFF18181B) : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  selected: !_isWholesaler,
                                  selectedColor: const Color(0xFFF59E0B),
                                  checkmarkColor: const Color(0xFF18181B),
                                  onSelected: (v) => setState(() => _isWholesaler = false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: Center(
                                    child: Text(
                                      'WHOLESALER',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isWholesaler ? const Color(0xFF18181B) : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  selected: _isWholesaler,
                                  selectedColor: const Color(0xFFF59E0B),
                                  checkmarkColor: const Color(0xFF18181B),
                                  onSelected: (v) => setState(() => _isWholesaler = true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  final user = ref.read(currentUserProvider);
                                  final String validUuid = UuidUtils.generate();

                                  final newCustomer = Customer(
                                    id: validUuid,
                                    branchCode: user?.branchCode,
                                    name: _nameController.text,
                                    phone: _phoneController.text,
                                    phone2: _phone2Controller.text.isEmpty ? null : _phone2Controller.text,
                                    location: _locationController.text,
                                    isBulkPurchaser: widget.isBulk,
                                    isWholesaler: _isWholesaler,
                                  );
                                  
                                  try {
                                    // 1. Trigger the add (now optimistic and non-blocking for network)
                                    ref.read(customerProvider.notifier).addCustomer(newCustomer);
                                    
                                    // 2. Immediately select and close dialog
                                    widget.onSelected(newCustomer);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error adding customer: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary, 
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Register & Select', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('DISMISS', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosFilterChip(String label, String type, ThemeData theme, {Color? color}) {
    final selected = _customerTypeFilter == type;
    final activeColor = color ?? theme.colorScheme.primary;
    final bool isLightColor = activeColor.computeLuminance() > 0.28 || activeColor.toARGB32() == 0xFFF59E0B;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _customerTypeFilter = type),
      selectedColor: activeColor,
      checkmarkColor: selected ? (isLightColor ? const Color(0xFF18181B) : Colors.white) : null,
      labelStyle: TextStyle(
        fontSize: 10,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? (isLightColor ? const Color(0xFF18181B) : Colors.white) : (color ?? theme.colorScheme.onSurface),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}

class PaymentDialog extends ConsumerStatefulWidget {
  final double totalAmount;
  final Function(List<PaymentDetail>, String?) onComplete;

  const PaymentDialog({super.key, required this.totalAmount, required this.onComplete});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<PaymentDetail> _payments = [];
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final _amountController = TextEditingController();
  final _refController = TextEditingController();

  String? _receiptUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalAmount.toStringAsFixed(2);
  }

  void _addPayment() {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount < 0) return; 

      final newPayment = PaymentDetail(
        method: _selectedMethod,
        amount: amount,
        reference: _refController.text.isEmpty ? null : _refController.text,
        isPaystack: false,
      );

      setState(() {
        _payments.add(newPayment);
        final paid = _payments.fold(0.0, (sum, p) => sum + p.amount);
        final remaining = (widget.totalAmount - paid).clamp(0.0, widget.totalAmount);
        _amountController.text = remaining > 0 ? remaining.toStringAsFixed(2) : '0.00';
        _refController.clear();
      });

      // High-Speed Auto Complete: If invoice is fully paid, close and finish
      final totalPaid = _payments.fold(0.0, (sum, p) => sum + p.amount);
      if (totalPaid >= widget.totalAmount - 0.01) {
        Navigator.pop(context);
        widget.onComplete(_payments, _receiptUrl);
      }
    }
  }

  Widget _buildQuickCashChip(String label, double val, double remaining) {
    final theme = Theme.of(context);
    final currentVal = double.tryParse(_amountController.text) ?? 0.0;
    final isSelected = (currentVal - val).abs() < 0.01;

    return ActionChip(
      label: Text(label, style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
        color: isSelected ? Colors.white : theme.colorScheme.primary,
      )),
      backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.08),
      side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        setState(() {
          _amountController.text = val.toStringAsFixed(2);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paid = _payments.fold(0.0, (sum, p) => sum + p.amount);
    final remaining = (widget.totalAmount - paid).clamp(0.0, widget.totalAmount);
    final bool isMoMo = _selectedMethod == PaymentMethod.mobileMoney;
    final bool isBank = _selectedMethod == PaymentMethod.bankDeposit;
    final bool isCard = _selectedMethod == PaymentMethod.card;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.l, AppSpacing.l, AppSpacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'COLLECT PAYMENT',
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ],
              ),
              const Divider(height: 24),
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Compact Summary Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.m),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        children: [
                          _billRow(context, 'Total Invoice', '₵${widget.totalAmount.toStringAsFixed(2)}', theme),
                          const SizedBox(height: 6),
                          _billRow(context, 'Balance Due', '₵${remaining.toStringAsFixed(2)}', theme, 
                            color: remaining > 0 ? Colors.red : Colors.green, isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Compact Method Selector
                    Row(
                      children: PaymentMethod.values.map((m) {
                        final isSelected = _selectedMethod == m;
                        String label = m.name.toUpperCase();
                        if (m == PaymentMethod.mobileMoney) label = 'MOMO';
                        if (m == PaymentMethod.bankDeposit) label = 'BANK';
                        if (m == PaymentMethod.card) label = 'CARD';

                        IconData mIcon = Icons.money_rounded;
                        if (m == PaymentMethod.mobileMoney) mIcon = Icons.smartphone_rounded;
                        if (m == PaymentMethod.bankDeposit) mIcon = Icons.account_balance_rounded;
                        if (m == PaymentMethod.card) mIcon = Icons.credit_card_rounded;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () {
                              setState(() {
                                _selectedMethod = m;
                                _amountController.text = remaining.toStringAsFixed(2);
                              });
                            },
                              borderRadius: BorderRadius.circular(AppRadius.s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.s),
                                  border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor),
                                  boxShadow: isSelected ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))] : null,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      mIcon,
                                      color: isSelected ? Colors.white : theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 9, 
                                        fontWeight: FontWeight.w900, 
                                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _amountController, 
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Amount Received / Applied', 
                              prefixText: '₵ ', 
                              isDense: true,
                              helperText: isBank ? 'Customer will provide deposit slip later' : 'Enter 0 for full credit/debt sale',
                              helperStyle: const TextStyle(fontSize: 9),
                            ),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.isEmpty) return '!';
                              final val = double.tryParse(v);
                              if (val == null || val < 0) return '!';
                              return null;
                            },
                          ),
                          if (_selectedMethod == PaymentMethod.cash && remaining > 0) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildQuickCashChip('Exact', remaining, remaining),
                                if (remaining <= 10) _buildQuickCashChip('₵10', 10, remaining),
                                if (remaining <= 20) _buildQuickCashChip('₵20', 20, remaining),
                                if (remaining <= 50) _buildQuickCashChip('₵50', 50, remaining),
                                if (remaining <= 100) _buildQuickCashChip('₵100', 100, remaining),
                                if (remaining <= 200) _buildQuickCashChip('₵200', 200, remaining),
                                if (remaining <= 500) _buildQuickCashChip('₵500', 500, remaining),
                              ],
                            ),
                            if ((double.tryParse(_amountController.text) ?? 0) > remaining) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppRadius.s),
                                  border: Border.all(color: AppColors.accentGreen, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('CHANGE DUE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accentGreen)),
                                    Text('₵${((double.tryParse(_amountController.text) ?? 0) - remaining).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.accentGreen)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _refController,
                            decoration: InputDecoration(
                              labelText: isMoMo ? 'MoMo Number' : (isCard ? 'Card Ref / Terminal ID' : 'Note (Optional)'),
                              prefixIcon: Icon(isMoMo ? Icons.phone_iphone_rounded : (isCard ? Icons.credit_card_rounded : Icons.note_alt_outlined)),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                            keyboardType: isMoMo ? TextInputType.phone : TextInputType.text,
                          ),
                        ],
                      ),
                    ),
                    if (isBank) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isUploading ? null : _uploadBankReceipt,
                          icon: _isUploading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_receiptUrl != null ? Icons.check_circle : Icons.add_a_photo, color: _receiptUrl != null ? Colors.green : null),
                          label: Text(_receiptUrl != null ? 'RECEIPT ATTACHED' : 'UPLOAD DEPOSIT SLIP'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _receiptUrl != null ? Colors.green : Colors.purple,
                            side: BorderSide(color: _receiptUrl != null ? Colors.green : Colors.purple),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addPayment,
                        icon: Icon(
                          isMoMo ? Icons.smartphone_rounded : (isCard ? Icons.credit_card_rounded : (isBank ? Icons.account_balance : Icons.add_circle_outline)), 
                          size: 18
                        ),
                        label: Text(
                          isMoMo ? 'APPLY MOMO PAYMENT' : (isCard ? 'APPLY CARD PAYMENT' : (isBank ? 'APPLY BANK DEPOSIT' : 'APPLY PAYMENT'))
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCard ? Colors.indigo.shade700 : (isBank ? Colors.purple : AppColors.accentGreen),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                    if (_payments.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ..._payments.map((p) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              p.method == PaymentMethod.cash ? Icons.money : 
                              (p.method == PaymentMethod.mobileMoney ? Icons.smartphone : (p.method == PaymentMethod.card ? Icons.credit_card : Icons.account_balance)), 
                              size: 16, color: Colors.green
                            ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(
                                      p.method.name.toUpperCase(), 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)
                                    )),
                                    Text('₵${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red, size: 16), 
                              onPressed: () => setState(() => _payments.remove(p))
                            ),
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                      ),
                      child: Text('CANCEL', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onComplete(_payments, _receiptUrl);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                      ),
                      child: FittedBox(
                        child: Text(
                          _payments.isEmpty ? 'RECORD AS DEBT' : 'COMPLETE SALE', 
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadBankReceipt() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await ref.read(expenseProvider.notifier).uploadReceipt(
        bytes, 
        'bank_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );
      if (mounted) setState(() => _receiptUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _billRow(BuildContext context, String label, String value, ThemeData theme, {bool isTotal = false, Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, 
              style: TextStyle(
                fontSize: isTotal ? 13 : 12, 
                color: isTotal ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                fontWeight: (isTotal || isBold) ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(
              fontSize: isTotal ? 16 : 14, 
              fontWeight: (isTotal || isBold) ? FontWeight.bold : FontWeight.w600,
              color: color ?? theme.colorScheme.onSurface,
            )),
          ),
        ],
      ),
    );
  }
}

class ReceiptSuccessDialog extends StatefulWidget {
  final SaleRecord sale;
  final WidgetRef ref;
  final VoidCallback? onNextCustomer;

  const ReceiptSuccessDialog({
    super.key, 
    required this.sale, 
    required this.ref,
    this.onNextCustomer,
  });

  @override
  State<ReceiptSuccessDialog> createState() => _ReceiptSuccessDialogState();
}

class _ReceiptSuccessDialogState extends State<ReceiptSuccessDialog> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      child: Container(
        width: screenSize.width * 0.9,
        constraints: BoxConstraints(maxWidth: 400, maxHeight: screenSize.height * 0.85),
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('SALE SUCCESSFUL', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Digital Receipt Card
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.s),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('ADOM MMOROSO ENT.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                      const Text('Digital Copy', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      if (widget.sale.balance > 0.01)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.shade800, borderRadius: BorderRadius.circular(4)),
                          child: const Text('DEBT / CREDIT SALE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      const Divider(height: 20),
                      _receiptPreviewRow('Invoice ID', widget.sale.id.substring(widget.sale.id.length - 8).toUpperCase()),
                      _receiptPreviewRow('Cashier', widget.sale.cashierName.split(' ')[0]),
                      const Divider(height: 20),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.sale.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.sale.items[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.product.name, 
                                    style: const TextStyle(fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('₵${item.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('TOTAL', 
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('₵${widget.sale.totalAmount.toStringAsFixed(2)}', 
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                          ),
                        ],
                      ),
                      if (widget.sale.balance > 0.01) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text('AMOUNT PAID', 
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('₵${widget.sale.amountPaid.toStringAsFixed(2)}', 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text('BALANCE DUE (DEBT)', 
                                style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('₵${widget.sale.balance.toStringAsFixed(2)}', 
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                      Builder(
                        builder: (context) {
                          final set = getAppreciationSet(widget.sale.id);
                          return Column(
                            children: [
                              const SizedBox(height: 8),
                              const Text('Thank you for shopping with us!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(set.akanTwi, style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.black87), textAlign: TextAlign.center),
                              const SizedBox(height: 2),
                              Text(set.hausaQuran, style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.black87), textAlign: TextAlign.center),
                              const SizedBox(height: 2),
                              Text(set.bible, style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.black87), textAlign: TextAlign.center),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'by techRaven ',
                              style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                            Icon(Icons.email, size: 12, color: Colors.grey),
                            SizedBox(width: 3),
                            Text(
                              'krasta1258@gmail.com',
                              style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.onNextCustomer != null) {
                        widget.onNextCustomer!();
                      } else {
                        Navigator.of(context).popUntil((route) => route.settings.name == '/cashier' || route.isFirst);
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                    label: const Text('NEXT CUSTOMER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReceiptOptionsDialog(widget.sale),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('RECEIPT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptOptionsDialog(SaleRecord sale) {
    final isDebt = sale.balance > 0.01;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print, color: Colors.blue),
              title: const Text('Print Physical Receipt'),
              onTap: () {
                Navigator.pop(context);
                ReceiptService.printReceipt(sale);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Share Digital Receipt (PDF)'),
              onTap: () {
                Navigator.pop(context);
                ReceiptService.shareReceipt(sale);
              },
            ),
            ListTile(
              leading: Icon(Icons.sms, color: isDebt ? Colors.grey : Colors.orange),
              title: const Text('Send SMS Confirmation'),
              subtitle: isDebt 
                  ? const Text('Debt reminder must be sent from Debt Tracker', style: TextStyle(fontSize: 11, color: Colors.orange)) 
                  : null,
              enabled: !isDebt,
              onTap: isDebt ? null : () async {
                String? targetPhone = sale.customerPhone;
                if (targetPhone == null || targetPhone.isEmpty) {
                  targetPhone = await PhonePromptDialog.show(context);
                }

                if (targetPhone != null && targetPhone.isNotEmpty) {
                  final success = await SmsService.sendReceiptSms(sale, customPhone: targetPhone);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'SMS Sent' : 'SMS Failed'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _receiptPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, 
              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
