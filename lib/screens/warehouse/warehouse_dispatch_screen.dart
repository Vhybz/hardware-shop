import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../widgets/camera_barcode_scanner_dialog.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../services/product_service.dart';
import '../../services/branch_provider.dart';
import '../../models/branch_model.dart';
import '../../models/product.dart';
import '../../models/warehouse_models.dart';
import '../../services/user_provider.dart';
import '../../services/warehouse_service.dart';

class WarehouseDispatchScreen extends ConsumerStatefulWidget {
  const WarehouseDispatchScreen({super.key});

  @override
  ConsumerState<WarehouseDispatchScreen> createState() => _WarehouseDispatchScreenState();
}

class _WarehouseDispatchScreenState extends ConsumerState<WarehouseDispatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dispatchNumberController = TextEditingController();
  final TextEditingController _destinationStoreController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _dispatchDate = DateTime.now();
  final List<DispatchItem> _dispatchItems = [];

  // Item Form Fields
  Product? _selectedProduct;
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _pcsPerBoxController = TextEditingController(text: '12');
  final ScrollController _replenishmentScrollController = ScrollController();
  String _selectedUnit = 'Boxes'; // Default to Boxes as requested
  WarehouseBatch? _fefoSuggestedBatch;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final randomStr = (1000 + DateTime.now().millisecond % 9000).toString();
    _dispatchNumberController.text = 'DSP-${DateFormat('yyyyMMdd').format(DateTime.now())}-$randomStr';
    _destinationStoreController.text = '';
  }

  @override
  void dispose() {
    _dispatchNumberController.dispose();
    _destinationStoreController.dispose();
    _notesController.dispose();
    _qtyController.dispose();
    _pcsPerBoxController.dispose();
    _replenishmentScrollController.dispose();
    super.dispose();
  }

  void _scrollReplenishment(double offset) {
    if (!_replenishmentScrollController.hasClients) return;
    _replenishmentScrollController.animateTo(
      (_replenishmentScrollController.offset + offset).clamp(
        0.0,
        _replenishmentScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// FEFO (First Expired, First Out) Batch Selection Logic
  WarehouseBatch? _findFEFOBatch(Product product, List<WarehouseBatch> allBatches) {
    // Filter batches for this product name/category that are in stock
    final productBatches = allBatches.where((b) => 
      b.productName.toLowerCase() == product.name.toLowerCase() &&
      b.quantity > 0
    ).toList();

    if (productBatches.isEmpty) return null;

    // Sort by Expiry Date ascending (earliest expiring first)
    productBatches.sort((a, b) {
      if (a.expiryDate == null && b.expiryDate == null) return 0;
      if (a.expiryDate == null) return 1; // Put no expiry date at end
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });

    return productBatches.first;
  }

  void _onProductSelected(Product? product, List<WarehouseBatch> batches) {
    setState(() {
      _selectedProduct = product;
      if (product != null) {
        _fefoSuggestedBatch = _findFEFOBatch(product, batches);
        // Pre-fill suggested replenishment quantity
        final neededPcs = (product.minStoreStock - product.stockQuantity).clamp(1.0, double.infinity);
        final maxPossiblePcs = product.warehouseQuantity;
        final suggestedPcs = neededPcs <= maxPossiblePcs ? neededPcs : maxPossiblePcs;
        final double pcsPerBox = double.tryParse(_pcsPerBoxController.text.trim()) ?? 12.0;

        if (_selectedUnit == 'Boxes') {
          final suggestedBoxes = (suggestedPcs / pcsPerBox).ceil();
          _qtyController.text = suggestedBoxes > 0 ? suggestedBoxes.toString() : '1';
        } else {
          _qtyController.text = suggestedPcs > 0 ? suggestedPcs.toInt().toString() : '1';
        }
      } else {
        _fefoSuggestedBatch = null;
        _qtyController.clear();
      }
    });
  }

  void _scanBarcodeToSelectProduct(BuildContext context, TextEditingController autocompleteController, List<Product> products, List<WarehouseBatch> batches) {
    CameraBarcodeScannerDialog.show(
      context,
      title: 'Scan Barcode to Dispatch',
      onScanned: (String raw) {
        final clean = raw.trim().toLowerCase();
        final matched = products.where((p) => !p.isDeleted).where((p) {
          final skuMatch = p.sku != null && p.sku!.toLowerCase() == clean;
          final idMatch = p.id.toLowerCase() == clean;
          final nameMatch = p.name.toLowerCase() == clean;
          return skuMatch || idMatch || nameMatch;
        }).firstOrNull;

        if (matched == null) {
          return 'No product found for barcode "$raw"';
        }

        autocompleteController.text = '${matched.name} (${matched.category}) [WHS: ${matched.stockControlWarehouseDisplay}]';
        _onProductSelected(matched, batches);
        return 'Selected: ${matched.name}';
      },
    );
  }

  void _addItemToDispatch() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product first.'), backgroundColor: Colors.red),
      );
      return;
    }

    final double inputQty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (inputQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid dispatch quantity (> 0).'), backgroundColor: Colors.red),
      );
      return;
    }

    final double pcsPerPack = _selectedProduct!.pcsPerPack > 0 ? _selectedProduct!.pcsPerPack : 12.0;
    final double packsPerBox = _selectedProduct!.packsPerBox > 0 ? _selectedProduct!.packsPerBox : 10.0;
    final double pcsPerBoxVal = pcsPerPack * packsPerBox;

    double totalPcs = inputQty;
    if (_selectedUnit == 'Packs') {
      totalPcs = inputQty * pcsPerPack;
    } else if (_selectedUnit == 'Boxes') {
      totalPcs = inputQty * pcsPerBoxVal;
    }

    if (totalPcs > _selectedProduct!.warehouseQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot dispatch ${inputQty.toInt()} $_selectedUnit (${totalPcs.toInt()} Pcs): Exceeds available Warehouse Stock (${_selectedProduct!.warehouseQuantity.toInt()} Pcs available).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newItem = DispatchItem(
      productId: _selectedProduct!.id,
      productName: _selectedProduct!.name,
      sku: _selectedProduct!.sku ?? _selectedProduct!.id.substring(0, 8),
      quantityDispatched: totalPcs,
      batchNumber: _fefoSuggestedBatch?.batchNumber ?? 'STD-BATCH',
      expiryDate: _fefoSuggestedBatch?.expiryDate,
    );

    setState(() {
      _dispatchItems.add(newItem);
      // Reset Item Fields
      _selectedProduct = null;
      _fefoSuggestedBatch = null;
      _qtyController.clear();
    });

    final label = _selectedUnit == 'Boxes' 
        ? '${inputQty.toInt()} Boxes (${totalPcs.toInt()} Pcs)' 
        : '${totalPcs.toInt()} Pcs';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${newItem.productName} ($label) added to dispatch list.'), backgroundColor: Colors.green),
    );
  }

  Future<void> _confirmDispatch() async {
    if (_formKey.currentState!.validate()) {
      if (_dispatchItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot confirm dispatch: Please add at least one product item to the dispatch list.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final user = ref.read(currentUserProvider);
        final dispatchRecord = WarehouseDispatchRecord(
          id: UuidUtils.generate(),
          dispatchNumber: _dispatchNumberController.text.trim(),
          date: _dispatchDate,
          destinationStore: _destinationStoreController.text.trim(),
          items: List.from(_dispatchItems),
          notes: _notesController.text.trim(),
          dispatchedBy: user != null ? '${user.firstName} ${user.surname}' : 'Warehouse Staff',
          isConfirmed: true,
        );

        await ref.read(warehouseDispatchProvider.notifier).confirmDispatch(dispatchRecord);

        // Refresh products list so stock numbers update instantly in UI
        await ref.read(productsFutureProvider.notifier).loadProducts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dispatch ${dispatchRecord.dispatchNumber} confirmed! Warehouse stock deducted & Store stock updated.'),
              backgroundColor: AppColors.accentGreen,
            ),
          );

          // Reset Form
          setState(() {
            _dispatchItems.clear();
            _notesController.clear();
            final randomStr = (1000 + DateTime.now().millisecond % 9000).toString();
            _dispatchNumberController.text = 'DSP-${DateFormat('yyyyMMdd').format(DateTime.now())}-$randomStr';
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error confirming dispatch: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Product> products = ref.watch(productsFutureProvider).value ?? <Product>[];
    final List<WarehouseBatch> batches = ref.watch(warehouseBatchProvider).value ?? <WarehouseBatch>[];
    final List<Branch> branches = ref.watch(branchesProvider).value ?? <Branch>[];

    final storeOptions = <String>[];
    if (branches.isNotEmpty) {
      for (final b in branches) {
        final label = b.location.isNotEmpty ? '${b.name} (${b.location})' : b.name;
        if (!storeOptions.contains(label)) {
          storeOptions.add(label);
        }
      }
    } else {
      final user = ref.watch(currentUserProvider);
      final defaultStore = user?.branchCode ?? 'Main Store';
      if (!storeOptions.contains(defaultStore)) {
        storeOptions.add(defaultStore);
      }
    }

    if (_destinationStoreController.text.isNotEmpty && !storeOptions.contains(_destinationStoreController.text)) {
      storeOptions.add(_destinationStoreController.text);
    }
    if (_destinationStoreController.text.isEmpty || !storeOptions.contains(_destinationStoreController.text)) {
      if (storeOptions.isNotEmpty) {
        _destinationStoreController.text = storeOptions.first;
      }
    }

    final lowStoreStockProducts = products.where((Product p) => p.needsDispatch).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.accentGreen,
                    child: Icon(Icons.local_shipping_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Store Replenishment Dispatch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Low Store Stock → Create Dispatch → FEFO Batch Selection → Deduct Warehouse → Increase Store Stock', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // Low Store Stock Replenishment Alert Banner
            if (lowStoreStockProducts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A1C08) : Colors.amber.shade50.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade500, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Store Replenishment Needed (${lowStoreStockProducts.length} ${lowStoreStockProducts.length == 1 ? "Product" : "Products"} Low in Shop)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tap any product below to pre-select it for dispatch:',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                          ),
                        ),
                        if (lowStoreStockProducts.length > 1) ...[
                          InkWell(
                            onTap: () => _scrollReplenishment(-250),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade200.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chevron_left_rounded, size: 18, color: Colors.amber.shade900),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => _scrollReplenishment(250),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade200.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chevron_right_rounded, size: 18, color: Colors.amber.shade900),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Swipe →',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      controller: _replenishmentScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: lowStoreStockProducts.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ActionChip(
                              avatar: const Icon(Icons.add_rounded, size: 16, color: Colors.amber),
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    p.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.amber.shade100 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.amber.shade900.withValues(alpha: 0.5) : Colors.amber.shade200.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Shop: ${p.posStockDisplay} • WHS: ${p.stockControlWarehouseDisplay}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.amber.shade100 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: isDark ? const Color(0xFF382A10) : Colors.amber.shade100.withValues(alpha: 0.9),
                              side: BorderSide(color: isDark ? Colors.amber.shade700 : Colors.amber.shade400, width: 1),
                              elevation: 0,
                              onPressed: () => _onProductSelected(p, batches),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.l),
            ],

            // Dispatch Header Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Dispatch Tracking Header', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dispatchNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Dispatch #',
                            prefixIcon: Icon(Icons.confirmation_number_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: storeOptions.contains(_destinationStoreController.text)
                              ? _destinationStoreController.text
                              : storeOptions.first,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Destination Store',
                            prefixIcon: Icon(Icons.storefront_rounded),
                            border: OutlineInputBorder(),
                          ),
                          items: storeOptions.map((store) {
                            final branch = branches.where((b) => b.name == store).firstOrNull;
                            final displayLabel = (branch != null && branch.location.isNotEmpty)
                                ? '${branch.name} (${branch.location})'
                                : store;
                            return DropdownMenuItem<String>(
                              value: store,
                              child: Text(
                                displayLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _destinationStoreController.text = val;
                              });
                            }
                          },
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Select destination store' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dispatchDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setState(() => _dispatchDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Dispatch Date',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('yyyy-MM-dd').format(_dispatchDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Dispatch Notes / Requisition Ref',
                            prefixIcon: Icon(Icons.note_alt_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // Item Selection & FEFO Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: AppColors.accentGreen.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. Select Product & Pick Quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.m),
                  RawAutocomplete<Product>(
                    displayStringForOption: (p) => '${p.name} (${p.category}) [WHS: ${p.stockControlWarehouseDisplay}]',
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return products.take(15);
                      }
                      final query = textEditingValue.text.toLowerCase().trim();
                      return products.where((p) =>
                        p.name.toLowerCase().contains(query) ||
                        p.category.toLowerCase().contains(query) ||
                        (p.sku != null && p.sku!.toLowerCase().contains(query)) ||
                        (p.brand != null && p.brand!.toLowerCase().contains(query))
                      );
                    },
                    onSelected: (p) => _onProductSelected(p, batches),
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onFieldSubmitted: (v) {
                          final query = v.trim().toLowerCase();
                          if (query.isNotEmpty) {
                            final matched = products.where((p) => !p.isDeleted).where((p) {
                              final skuMatch = p.sku != null && p.sku!.toLowerCase() == query;
                              final idMatch = p.id.toLowerCase() == query;
                              final nameMatch = p.name.toLowerCase() == query;
                              return skuMatch || idMatch || nameMatch;
                            }).firstOrNull;

                            if (matched != null) {
                              controller.text = '${matched.name} (${matched.category}) [WHS: ${matched.stockControlWarehouseDisplay}]';
                              _onProductSelected(matched, batches);
                            } else {
                              onFieldSubmitted();
                            }
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Search Product to Dispatch by Name, Category, or SKU',
                          hintText: 'Scan barcode or type name e.g. Anua, CeraVe, Lotion...',
                          prefixIcon: const Icon(Icons.qr_code_scanner),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                tooltip: 'Scan Barcode with Camera',
                                onPressed: () => _scanBarcodeToSelectProduct(context, controller, products, batches),
                              ),
                              if (controller.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear), 
                                  onPressed: () {
                                    controller.clear();
                                    _onProductSelected(null, batches);
                                  },
                                ),
                            ],
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 600),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final p = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${p.category} • WHS Stock: ${p.stockControlWarehouseDisplay} | Shop: ${p.posStockDisplay}'),
                                  trailing: Icon(
                                    p.needsDispatch ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                                    color: p.needsDispatch ? Colors.amber : Colors.blue,
                                    size: 18,
                                  ),
                                  onTap: () {
                                    onSelected(p);
                                    _onProductSelected(p, batches);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  if (_selectedProduct != null) ...[
                    const SizedBox(height: AppSpacing.m),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(AppRadius.s),
                        border: Border.all(color: Colors.blue.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Stock Overview for ${_selectedProduct!.name}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Warehouse Stock: ${_selectedProduct!.stockControlWarehouseDisplay}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Branch POS Stock: ${_selectedProduct!.posStockDisplay}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade800, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Min POS Threshold: ${_selectedProduct!.minStoreStock.toInt()} Pcs',
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),

                          // FEFO Intake Source Passport
                          if (_fefoSuggestedBatch != null) ...[
                            const Divider(height: 20),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2638) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2_rounded, color: Colors.blue, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Intake Source Batch: ${_fefoSuggestedBatch!.batchNumber}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade700,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${_fefoSuggestedBatch!.quantity.toInt()} Pcs in Batch',
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      _intakeDetailChip(Icons.business_rounded, 'Supplier', _fefoSuggestedBatch!.source?.name ?? 'Supplier Warehouse'),
                                      _intakeDetailChip(Icons.calendar_today_rounded, 'Received Date', DateFormat('yyyy-MM-dd').format(_fefoSuggestedBatch!.createdAt)),
                                      _intakeDetailChip(
                                        Icons.event_outlined, 
                                        'Expiry Date', 
                                        _fefoSuggestedBatch!.expiryDate != null ? DateFormat('yyyy-MM-dd').format(_fefoSuggestedBatch!.expiryDate!) : 'No Expiry Set'
                                      ),
                                      _intakeDetailChip(Icons.place_outlined, 'Warehouse Location', _fefoSuggestedBatch!.shelfLocation ?? 'Section A'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.m),
                  LayoutBuilder(
                    builder: (context, inputConstraints) {
                      final isNarrow = inputConstraints.maxWidth < 600;
                      return isNarrow
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _qtyController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                        decoration: InputDecoration(
                                          labelText: _selectedUnit == 'Boxes' ? 'Dispatch Qty (Boxes)' : 'Dispatch Qty (Pcs)',
                                          hintText: _selectedUnit == 'Boxes' ? 'e.g. 2' : 'e.g. 24',
                                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _selectedUnit,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Unit',
                                          prefixIcon: Icon(Icons.unarchive_rounded),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'Pcs', child: Text('1. Pcs', overflow: TextOverflow.ellipsis)),
                                          DropdownMenuItem(value: 'Packs', child: Text('2. Packs', overflow: TextOverflow.ellipsis)),
                                          DropdownMenuItem(value: 'Boxes', child: Text('3. Boxes', overflow: TextOverflow.ellipsis)),
                                        ],
                                        onChanged: (u) {
                                          if (u != null) {
                                            setState(() => _selectedUnit = u);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedUnit == 'Boxes') ...[
                                  const SizedBox(height: AppSpacing.s),
                                  TextFormField(
                                    controller: _pcsPerBoxController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                    decoration: const InputDecoration(
                                      labelText: 'Pcs per Box',
                                      prefixIcon: Icon(Icons.apps_rounded),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _qtyController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                    decoration: InputDecoration(
                                      labelText: _selectedUnit == 'Boxes' ? 'Dispatch Quantity (Boxes)' : 'Dispatch Quantity (Pcs)',
                                      hintText: _selectedUnit == 'Boxes' ? 'e.g. 2 Boxes' : 'e.g. 24 Pcs',
                                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.m),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedUnit,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Dispatch Unit',
                                      prefixIcon: Icon(Icons.unarchive_rounded),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'Pcs', child: Text('1. Pcs (Individual)')),
                                      DropdownMenuItem(value: 'Packs', child: Text('2. Packs')),
                                      DropdownMenuItem(value: 'Boxes', child: Text('3. Boxes (Default)')),
                                    ],
                                    onChanged: (u) {
                                      if (u != null) {
                                        setState(() => _selectedUnit = u);
                                      }
                                    },
                                  ),
                                ),
                                if (_selectedUnit == 'Boxes') ...[
                                  const SizedBox(width: AppSpacing.m),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: _pcsPerBoxController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                      decoration: const InputDecoration(
                                        labelText: 'Pcs / Box',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _addItemToDispatch,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('ADD TO DISPATCH LIST', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // Multi-item Review Table
            Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, rowConstraints) {
                      final isNarrow = rowConstraints.maxWidth < 460;
                      final totalPcs = _dispatchItems.fold(0.0, (s, i) => s + i.quantityDispatched).toInt();

                      final badge = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          '${_dispatchItems.length} Products • Total: $totalPcs Pcs',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green.shade900),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('3. Review Dispatch Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            badge,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Expanded(
                            child: Text('3. Review Dispatch Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          badge,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  if (_dispatchItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No products added to dispatch list yet. Select a product above and click "ADD TO DISPATCH LIST".',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 48,
                        columns: const [
                          DataColumn(label: Text('Product / SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Quantity Dispatched', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Batch #', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Remove', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _dispatchItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          return DataRow(
                            cells: [
                              DataCell(Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('SKU: ${item.sku}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              )),
                              DataCell(Text('${item.quantityDispatched.toInt()} Pcs', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                              DataCell(Text(item.batchNumber ?? 'STD-BATCH')),
                              DataCell(Text(item.expiryDate != null ? DateFormat('yyyy-MM-dd').format(item.expiryDate!) : 'N/A')),
                              DataCell(IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => setState(() => _dispatchItems.removeAt(idx)),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Final Confirmation Button
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _confirmDispatch,
              icon: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _isSubmitting ? 'CONFIRMING DISPATCH...' : 'CONFIRM DISPATCH (DEDUCT WAREHOUSE & ADD TO BRANCH POS)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
                elevation: 4,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intakeDetailChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.blue.shade700),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
