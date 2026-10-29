import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../models/sale_model.dart';
import '../../models/warehouse_models.dart';
import '../../models/supplier_return_model.dart';
import '../../services/sale_provider.dart';
import '../../services/warehouse_service.dart';
import '../../services/supplier_return_service.dart';
import '../../services/sale_return_service.dart';
import '../../services/report_service.dart';
import '../../services/user_provider.dart';
import '../../services/menu_service.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/role_pop_scope.dart';
import '../../widgets/process_return_dialog.dart';

class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key});

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Customer Return Search
  final TextEditingController _customerReceiptController = TextEditingController();
  SaleRecord? _searchedSale;
  String _historyFilterQuery = '';

  // Supplier Return Search
  final TextEditingController _supplierIntakeController = TextEditingController();
  WarehouseIntakeRecord? _searchedIntake;
  final Map<int, double> _supplierReturnQty = {};
  final Map<int, bool> _supplierItemSelected = {};
  String _supplierReason = 'damaged_in_transit';
  bool _isSubmittingSupplierReturn = false;
  bool _hasCheckedInitialArgs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedInitialArgs) {
      _hasCheckedInitialArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is SaleRecord) {
        setState(() {
          _searchedSale = args;
          _customerReceiptController.text = args.id;
        });
      } else if (args is String && args.isNotEmpty) {
        _customerReceiptController.text = args;
        _doSearchCustomerReceiptWithQuery(args);
      }
    }
  }

  void _doSearchCustomerReceiptWithQuery(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return;

    final sales = ref.read(saleHistoryProvider);
    final match = sales.where((s) {
      final cleanId = s.id.toLowerCase();
      final shortId = s.id.length > 8 ? s.id.substring(s.id.length - 8).toLowerCase() : cleanId;
      return cleanId == cleanQuery || shortId == cleanQuery || cleanId.contains(cleanQuery);
    }).firstOrNull;

    setState(() {
      _searchedSale = match;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerReceiptController.dispose();
    _supplierIntakeController.dispose();
    super.dispose();
  }

  void _searchCustomerReceipt() {
    final query = _customerReceiptController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    final sales = ref.read(saleHistoryProvider);
    final match = sales.where((s) {
      final cleanId = s.id.toLowerCase();
      final shortId = s.id.length > 8 ? s.id.substring(s.id.length - 8).toLowerCase() : cleanId;
      return cleanId == query || shortId == query || cleanId.contains(query);
    }).firstOrNull;

    setState(() {
      _searchedSale = match;
    });

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No receipt found matching "$query"'), backgroundColor: Colors.red),
      );
    }
  }

  void _doSearchSupplierIntake() {
    final query = _supplierIntakeController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    final intakes = ref.read(warehouseIntakeProvider).value ?? [];
    final match = intakes.where((i) {
      final numStr = i.intakeNumber.toLowerCase();
      final idStr = i.id.toLowerCase();
      return numStr == query || idStr == query || numStr.contains(query);
    }).firstOrNull;

    setState(() {
      _searchedIntake = match;
      _supplierReturnQty.clear();
      _supplierItemSelected.clear();
      if (match != null) {
        for (int idx = 0; idx < match.items.length; idx++) {
          _supplierReturnQty[idx] = match.items[idx].quantityReceived;
          _supplierItemSelected[idx] = false;
        }
      }
    });

    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No supplier intake receipt found matching "$query"'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/returns';

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: MainAppBar(
          title: 'Returns & Refunds Hub',
          onProfileTap: () => Navigator.pushNamed(context, '/profile'),
        ),
        drawer: isDesktop
            ? null
            : Drawer(
                child: AppSidebar(
                  items: ref.watch(menuItemsProvider),
                  currentRoute: currentRoute,
                  userName: user.name,
                  userRole: user.activePrimaryRole.name,
                  userId: user.id,
                  onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
                ),
              ),
        body: Row(
          children: [
            if (isDesktop)
              AppSidebar(
                items: ref.watch(menuItemsProvider),
                currentRoute: currentRoute,
                userName: user.name,
                userRole: user.activePrimaryRole.name,
                userId: user.id,
                onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
              ),
            Expanded(
              child: Column(
                children: [
                  // Tab Bar Header
                  Container(
                    color: theme.cardColor,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: ResponsiveLayout.isMobile(context),
                      tabAlignment: ResponsiveLayout.isMobile(context) ? TabAlignment.start : null,
                      labelColor: theme.colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: theme.colorScheme.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(icon: Icon(Icons.person_outline_rounded), text: 'CUSTOMER RETURNS & REFUNDS'),
                        Tab(icon: Icon(Icons.local_shipping_outlined), text: 'SUPPLIER INTAKE RETURNS'),
                      ],
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCustomerReturnsTab(theme),
                        _buildSupplierReturnsTab(theme),
                      ],
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

  Widget _buildCustomerReturnsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Receipt Input Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search Customer Invoice / Receipt ID', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Enter receipt ID (e.g. #INV-1002) to process full or partial item returns', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: AppSpacing.m),
                  if (ResponsiveLayout.isMobile(context)) ...[
                    TextField(
                      controller: _customerReceiptController,
                      onSubmitted: (_) => _searchCustomerReceipt(),
                      decoration: const InputDecoration(
                        labelText: 'Receipt ID / Invoice Number',
                        hintText: 'e.g. INV-20260329-101',
                        prefixIcon: Icon(Icons.receipt_long_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _searchCustomerReceipt,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('FIND RECEIPT', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customerReceiptController,
                            onSubmitted: (_) => _searchCustomerReceipt(),
                            decoration: const InputDecoration(
                              labelText: 'Receipt ID / Invoice Number',
                              hintText: 'e.g. INV-20260329-101',
                              prefixIcon: Icon(Icons.receipt_long_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        ElevatedButton.icon(
                          onPressed: _searchCustomerReceipt,
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('FIND RECEIPT', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          // Searched Sale Result
          if (_searchedSale != null) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Receipt #${_searchedSale!.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Customer: ${_searchedSale!.customerName ?? "Walk-in"} • Date: ${DateFormat('yyyy-MM-dd HH:mm').format(_searchedSale!.timestamp)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => ProcessReturnDialog.show(context, _searchedSale!),
                          icon: const Icon(Icons.assignment_return_rounded, size: 18),
                          label: const Text('PROCESS RETURN / REFUND'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('Purchased Product Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ..._searchedSale!.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          Expanded(child: Text('${item.product.name} [SKU: ${item.product.sku ?? item.product.id.substring(0, 8)}]', style: const TextStyle(fontSize: 12))),
                          Text('${item.quantity.toInt()} ${item.selectedUnit ?? item.product.unit}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 16),
                          Text('GHS ${item.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          _buildCustomerRefundHistorySection(theme),
        ],
      ),
    );
  }

  Widget _buildSupplierReturnsTab(ThemeData theme) {
    final intakesAsync = ref.watch(warehouseIntakeProvider);
    final intakes = intakesAsync.value ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Supplier Intake Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.blue),
                        tooltip: 'Refresh Intakes List',
                        onPressed: () {
                          ref.read(warehouseIntakeProvider.notifier).loadIntakes();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Refreshing Recent Intakes...'), duration: Duration(milliseconds: 600)),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Search or select a goods intake receipt to return damaged/incorrect products to supplier', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _supplierIntakeController,
                          onSubmitted: (_) => _doSearchSupplierIntake(),
                          decoration: const InputDecoration(
                            labelText: 'Search Intake # / Supplier Name',
                            hintText: 'e.g. INT-20260329-101',
                            prefixIcon: Icon(Icons.search_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      IconButton.filled(
                        icon: const Icon(Icons.search),
                        onPressed: _doSearchSupplierIntake,
                        tooltip: 'Search Intake',
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<WarehouseIntakeRecord>(
                          initialValue: _searchedIntake,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Or Choose from Recent Intakes',
                            prefixIcon: Icon(Icons.receipt_long_rounded),
                            border: OutlineInputBorder(),
                          ),
                          items: intakes.map((i) {
                            return DropdownMenuItem(
                              value: i,
                              child: Text('#${i.intakeNumber} - ${i.supplierName} (${DateFormat('yyyy-MM-dd').format(i.date)})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _searchedIntake = val;
                                _supplierReturnQty.clear();
                                _supplierItemSelected.clear();
                                for (int idx = 0; idx < val.items.length; idx++) {
                                  _supplierReturnQty[idx] = val.items[idx].quantityReceived;
                                  _supplierItemSelected[idx] = false;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          if (_searchedIntake != null) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Intake Receipt #${_searchedIntake!.intakeNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Supplier: ${_searchedIntake!.supplierName} • Arrival: ${DateFormat('yyyy-MM-dd HH:mm').format(_searchedIntake!.date)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Divider(height: 24),
                    const Text('Select Product(s) to Return to Supplier:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchedIntake!.items.length,
                      itemBuilder: (context, idx) {
                        final item = _searchedIntake!.items[idx];
                        final isSelected = _supplierItemSelected[idx] ?? false;
                        final double retQty = _supplierReturnQty[idx] ?? item.quantityReceived;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? Colors.orange.withValues(alpha: 0.08) : null,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: Colors.orange.shade800,
                                  onChanged: (v) => setState(() => _supplierItemSelected[idx] = v ?? false),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Batch #${item.batchNumber} • Recv: ${item.quantityReceived.toInt()} Pcs', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: retQty > 1 ? () => setState(() => _supplierReturnQty[idx] = retQty - 1) : null,
                                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, size: 16, color: Colors.orange)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text('${retQty.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                                        ),
                                        InkWell(
                                          onTap: retQty < item.quantityReceived ? () => setState(() => _supplierReturnQty[idx] = retQty + 1) : null,
                                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, size: 16, color: Colors.orange)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _supplierReason,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Return Reason',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'damaged_in_transit', child: Text('Damaged in Transit / Transport')),
                        DropdownMenuItem(value: 'wrong_product', child: Text('Wrong Product / Specification Supplied')),
                        DropdownMenuItem(value: 'expired_on_arrival', child: Text('Expired / Short Shelf Life on Arrival')),
                        DropdownMenuItem(value: 'excess_shipment', child: Text('Excess Shipment Quantity')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _supplierReason = val);
                      },
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmittingSupplierReturn ? null : _handleProcessSupplierReturn,
                        icon: _isSubmittingSupplierReturn
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.local_shipping_rounded),
                        label: Text(_isSubmittingSupplierReturn ? 'PROCESSING...' : 'CONFIRM SUPPLIER RETURN & DEDUCT STOCK', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          _buildSupplierRefundHistorySection(theme),
        ],
      ),
    );
  }

  Future<void> _handleProcessSupplierReturn() async {
    if (_searchedIntake == null) return;

    final List<SupplierReturnedItem> returnedList = [];
    double totalQty = 0.0;

    for (int i = 0; i < _searchedIntake!.items.length; i++) {
      if (_supplierItemSelected[i] == true) {
        final item = _searchedIntake!.items[i];
        final q = _supplierReturnQty[i] ?? item.quantityReceived;
        totalQty += q;
        returnedList.add(
          SupplierReturnedItem(
            productId: item.productId,
            productName: item.productName,
            sku: item.sku,
            quantityReturned: q,
            batchNumber: item.batchNumber,
            reason: _supplierReason,
          ),
        );
      }
    }

    if (returnedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item to return to supplier.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmittingSupplierReturn = true);

    try {
      final user = ref.read(currentUserProvider);
      final randomStr = (1000 + DateTime.now().millisecond % 9000).toString();
      final record = SupplierReturnRecord(
        id: UuidUtils.generate(),
        returnNumber: 'SRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-$randomStr',
        intakeNumber: _searchedIntake!.intakeNumber,
        supplierName: _searchedIntake!.supplierName,
        items: returnedList,
        totalQuantity: totalQty,
        reason: _supplierReason,
        processedBy: user?.name ?? 'Warehouse Staff',
        createdAt: DateTime.now(),
      );

      await ref.read(supplierReturnProvider.notifier).submitSupplierReturn(record);

      if (mounted) {
        // Print Supplier Return Note (SRN) PDF
        ReportService.generateSupplierReturnNote(record);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supplier Return #${record.returnNumber} confirmed! Stock deducted from warehouse.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        setState(() {
          _searchedIntake = null;
          _supplierIntakeController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing supplier return: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingSupplierReturn = false);
    }
  }

  Widget _buildCustomerRefundHistorySection(ThemeData theme) {
    final returnsAsync = ref.watch(saleReturnProvider);

    return returnsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, st) => Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error loading refund records: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (returnsList) {
        final query = _historyFilterQuery.trim().toLowerCase();
        final filteredList = returnsList.where((r) {
          if (query.isEmpty) return true;
          final matchNum = r.returnNumber.toLowerCase().contains(query);
          final matchInvoice = r.originalSaleId.toLowerCase().contains(query);
          final matchCustomer = (r.customerName ?? '').toLowerCase().contains(query);
          final matchStaff = r.processedBy.toLowerCase().contains(query);
          return matchNum || matchInvoice || matchCustomer || matchStaff;
        }).toList();

        final double totalRefundSum = returnsList.fold(0.0, (s, r) => s + r.totalRefundAmount);

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Refunds & Customer Returns Records (${returnsList.length})',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Complete ledger of all customer item returns, refunds, and product exchanges',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.blue),
                      tooltip: 'Refresh Ledger',
                      onPressed: () {
                        ref.invalidate(saleReturnProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refreshing Refund Ledger...'), duration: Duration(milliseconds: 600)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),

                // Summary Stats Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL REFUNDS PAID OUT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900)),
                            const SizedBox(height: 2),
                            Text('GHS ${totalRefundSum.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red.shade900)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL RETURN VOUCHERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                            const SizedBox(height: 2),
                            Text('${returnsList.length}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.m),

                // Search / Filter Input
                TextField(
                  onChanged: (val) => setState(() => _historyFilterQuery = val),
                  decoration: const InputDecoration(
                    labelText: 'Search Refund Records',
                    hintText: 'Filter by Return #, Invoice #, Customer, or Staff Name...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: AppSpacing.m),

                if (filteredList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        returnsList.isEmpty
                            ? 'No refund or customer return records found.'
                            : 'No records match "$_historyFilterQuery".',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final record = filteredList[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '#${record.returnNumber}',
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.red),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Invoice: #${record.originalSaleId}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text(
                                  DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Customer: ${record.customerName ?? "Walk-in Customer"}${record.customerPhone != null && record.customerPhone!.isNotEmpty ? " (${record.customerPhone})" : ""}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Processed By: ${record.processedBy} • Method: ${record.refundMethod.toUpperCase()}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Refund Total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          'GHS ${record.totalRefundAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.red),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.print_rounded, size: 20, color: Colors.blue),
                                      tooltip: 'Reprint Return Slip',
                                      onPressed: () {
                                        ReportService.generateReturnSlip(record);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (record.items.isNotEmpty) ...[
                              const Divider(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: record.items.map((item) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      '• ${item.product.name} (x${item.quantityReturned.toInt()}) - ${item.reason.name.toUpperCase()}',
                                      style: const TextStyle(fontSize: 10.5),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupplierRefundHistorySection(ThemeData theme) {
    final returnsAsync = ref.watch(supplierReturnProvider);

    return returnsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, st) => Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error loading supplier return records: $e', style: const TextStyle(color: Colors.orange)),
        ),
      ),
      data: (returnsList) {
        if (returnsList.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
              side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No supplier return records found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All items returned to suppliers/vendors will be recorded here automatically.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final double totalQtySum = returnsList.fold(0.0, (s, r) => s + r.totalQuantity);

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.orange, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supplier Return Notes Ledger (${returnsList.length})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Complete ledger of all goods returned to suppliers / vendors',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.orange),
                      tooltip: 'Refresh Ledger',
                      onPressed: () {
                        ref.invalidate(supplierReturnProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refreshing Supplier Returns...'), duration: Duration(milliseconds: 600)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.m),

                // Summary Stats Bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TOTAL UNITS RETURNED TO SUPPLIERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                            const SizedBox(height: 2),
                            Text('${totalQtySum.toInt()} Pcs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.orange.shade900)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.s),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SUPPLIER RETURN NOTES (SRN)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                            const SizedBox(height: 2),
                            Text('${returnsList.length}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.m),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: returnsList.length,
                  itemBuilder: (context, index) {
                    final record = returnsList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.s),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${record.returnNumber}',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.orange.shade900),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Intake: #${record.intakeNumber}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Supplier: ${record.supplierName}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Processed By: ${record.processedBy} • Reason: ${record.reason}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.print_rounded, size: 20, color: Colors.orange),
                                tooltip: 'Reprint Supplier Return Note (SRN)',
                                onPressed: () {
                                  ReportService.generateSupplierReturnNote(record);
                                },
                              ),
                            ],
                          ),
                          if (record.items.isNotEmpty) ...[
                            const Divider(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: record.items.map((item) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    '• ${item.productName} (x${item.quantityReturned.toInt()}) [Batch #${item.batchNumber}]',
                                    style: const TextStyle(fontSize: 10.5),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
