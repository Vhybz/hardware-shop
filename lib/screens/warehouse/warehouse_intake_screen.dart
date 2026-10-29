import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../widgets/camera_barcode_scanner_dialog.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../models/product.dart';
import '../../models/warehouse_models.dart';
import '../../services/product_service.dart';
import '../../services/user_provider.dart';
import '../../services/warehouse_service.dart';
import '../../services/report_service.dart';
import 'warehouse_shell.dart';

class WarehouseIntakeScreen extends ConsumerStatefulWidget {
  const WarehouseIntakeScreen({super.key});

  @override
  ConsumerState<WarehouseIntakeScreen> createState() => _WarehouseIntakeScreenState();
}

class _WarehouseIntakeScreenState extends ConsumerState<WarehouseIntakeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _intakeNumberController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _expectedProductCountController = TextEditingController();
  final TextEditingController _expectedTargetQtyController = TextEditingController();

  DateTime _intakeDate = DateTime.now();
  final List<IntakeItem> _intakeItems = [];

  // Current Item Form Fields
  Product? _selectedProduct;
  String _selectedUnitType = 'Boxes'; // DEFAULT IS BOXES AT WAREHOUSE INTAKE
  final TextEditingController _pcsPerBoxController = TextEditingController(text: '12');
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _itemCostPriceController = TextEditingController();
  final TextEditingController _itemActualCostController = TextEditingController();
  final TextEditingController _itemRetailPriceController = TextEditingController();
  final TextEditingController _itemWholesalePriceController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  DateTime? _itemExpiryDate;
  ProductCondition _itemCondition = ProductCondition.good;

  final FocusNode _qtyFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final randomStr = (1000 + DateTime.now().millisecond % 9000).toString();
    _intakeNumberController.text = 'INT-${DateFormat('yyyyMMdd').format(DateTime.now())}-$randomStr';
  }

  @override
  void dispose() {
    _intakeNumberController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    _expectedProductCountController.dispose();
    _expectedTargetQtyController.dispose();
    _pcsPerBoxController.dispose();
    _qtyController.dispose();
    _itemCostPriceController.dispose();
    _itemActualCostController.dispose();
    _itemRetailPriceController.dispose();
    _itemWholesalePriceController.dispose();
    _qtyFocusNode.dispose();
    _batchController.dispose();
    _locationController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  void _scanBarcodeToSelectProduct(BuildContext context, TextEditingController autocompleteController, List<Product> products) {
    CameraBarcodeScannerDialog.show(
      context,
      title: 'Scan Product Barcode for Intake',
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

        setState(() {
          _selectedProduct = matched;
          autocompleteController.text = '${matched.name} [SKU: ${matched.sku ?? matched.id.substring(0, 8)}]';
          if (matched.brand != null) _brandController.text = matched.brand!;
          if (matched.warehouseLocation != null) _locationController.text = matched.warehouseLocation!;
          _pcsPerBoxController.text = (matched.pcsPerBox > 0 ? matched.pcsPerBox : 12.0).toInt().toString();
          _itemCostPriceController.text = matched.costPrice > 0 ? matched.costPrice.toStringAsFixed(2) : '';
        });
        _qtyFocusNode.requestFocus();
        return 'Selected: ${matched.name}';
      },
    );
  }

  void _addItemToIntake() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product first.'), backgroundColor: Colors.red),
      );
      return;
    }

    final double qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid received quantity (> 0).'), backgroundColor: Colors.red),
      );
      return;
    }

    final double rawPcsPerBox = double.tryParse(_pcsPerBoxController.text.trim()) ?? 0.0;
    final double pcsPerBox = rawPcsPerBox > 0 
        ? rawPcsPerBox 
        : ((_selectedProduct?.pcsPerBox ?? 0) > 0 ? _selectedProduct!.pcsPerBox : 12.0);
    final double pcsPerPack = (_selectedProduct?.pcsPerPack ?? 0) > 0 ? _selectedProduct!.pcsPerPack : 12.0;

    double totalPcs = qty;
    if (_selectedUnitType == 'Boxes') {
      totalPcs = qty * pcsPerBox;
    } else if (_selectedUnitType == 'Packs') {
      totalPcs = qty * pcsPerPack;
    }

    final double userEnteredUnitCost = double.tryParse(_itemCostPriceController.text.trim()) ?? _selectedProduct!.costPrice;
    final double userEnteredRetail = double.tryParse(_itemRetailPriceController.text.trim()) ?? _selectedProduct!.retailPrice;
    final double userEnteredWholesale = double.tryParse(_itemWholesalePriceController.text.trim()) ?? _selectedProduct!.wholesalePrice;

    if (_selectedProduct != null) {
      bool productNeedsUpdate = false;
      var updatedProduct = _selectedProduct!;
      if (pcsPerBox > 0 && updatedProduct.pcsPerBox != pcsPerBox) {
        updatedProduct = updatedProduct.copyWith(pcsPerBox: pcsPerBox);
        productNeedsUpdate = true;
      }
      if (userEnteredUnitCost > 0 && updatedProduct.costPrice != userEnteredUnitCost) {
        updatedProduct = updatedProduct.copyWith(costPrice: userEnteredUnitCost);
        productNeedsUpdate = true;
      }
      if (userEnteredRetail > 0 && updatedProduct.retailPrice != userEnteredRetail) {
        updatedProduct = updatedProduct.copyWith(retailPrice: userEnteredRetail);
        productNeedsUpdate = true;
      }
      if (userEnteredWholesale > 0 && updatedProduct.wholesalePrice != userEnteredWholesale) {
        updatedProduct = updatedProduct.copyWith(wholesalePrice: userEnteredWholesale);
        productNeedsUpdate = true;
      }
      if (productNeedsUpdate) {
        _selectedProduct = updatedProduct;
        ref.read(productsFutureProvider.notifier).updateProduct(updatedProduct);
      }
    }

    final batch = _batchController.text.trim().isEmpty 
        ? 'BATCH-${DateFormat('yyyyMM').format(DateTime.now())}' 
        : _batchController.text.trim();

    final double calculatedExpectedCost = userEnteredUnitCost * totalPcs;
    final double enteredActualCost = double.tryParse(_itemActualCostController.text.trim()) ?? calculatedExpectedCost;

    final newItem = IntakeItem(
      productId: _selectedProduct!.id,
      productName: _selectedProduct!.name,
      sku: _selectedProduct!.sku ?? _selectedProduct!.id.substring(0, 8),
      category: _selectedProduct!.category,
      brand: _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : _selectedProduct!.brand,
      quantityReceived: totalPcs,
      batchNumber: batch,
      expiryDate: _itemExpiryDate,
      condition: _itemCondition,
      warehouseLocation: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : 'Section A',
      expectedCost: calculatedExpectedCost,
      actualCost: enteredActualCost,
    );

    final String displayLabel;
    if (_selectedUnitType == 'Boxes') {
      displayLabel = '${qty % 1 == 0 ? qty.toInt() : qty} Boxes / ${totalPcs.toInt()} Pcs';
    } else if (_selectedUnitType == 'Packs') {
      displayLabel = '${qty % 1 == 0 ? qty.toInt() : qty} Packs / ${totalPcs.toInt()} Pcs';
    } else {
      displayLabel = '${totalPcs.toInt()} Pcs';
    }

    setState(() {
      _intakeItems.insert(0, newItem); // NEWLY ADDED COMES AT THE TOP OF THE LIST
      // Reset Item Fields
      _selectedProduct = null;
      _qtyController.clear();
      _itemCostPriceController.clear();
      _itemActualCostController.clear();
      _itemRetailPriceController.clear();
      _itemWholesalePriceController.clear();
      _batchController.clear();
      _locationController.clear();
      _brandController.clear();
      _itemExpiryDate = null;
      _itemCondition = ProductCondition.good;
      _selectedUnitType = 'Boxes'; // Reset to default Boxes
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newItem.productName} ($displayLabel) added at the top of intake list.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditIntakeItemDialog(int index) {
    final item = _intakeItems[index];
    final qtyCtrl = TextEditingController(text: item.quantityReceived % 1 == 0 ? item.quantityReceived.toInt().toString() : item.quantityReceived.toStringAsFixed(1));
    final batchCtrl = TextEditingController(text: item.batchNumber);
    final locCtrl = TextEditingController(text: item.warehouseLocation ?? 'Section A');
    DateTime? expDate = item.expiryDate;
    ProductCondition cond = item.condition;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Edit Intake Item: ${item.productName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Received Quantity (Pcs)',
                    prefixIcon: Icon(Icons.numbers_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: batchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Batch Number',
                    prefixIcon: Icon(Icons.qr_code_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: locCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse Location / Shelf',
                    prefixIcon: Icon(Icons.place_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: expDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setDlgState(() => expDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expiry Date',
                      prefixIcon: Icon(Icons.event_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(expDate != null ? DateFormat('yyyy-MM-dd').format(expDate!) : 'Select Expiry Date'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final double q = double.tryParse(qtyCtrl.text.trim()) ?? item.quantityReceived;
                setState(() {
                  _intakeItems[index] = IntakeItem(
                    productId: item.productId,
                    productName: item.productName,
                    sku: item.sku,
                    category: item.category,
                    brand: item.brand,
                    quantityReceived: q,
                    batchNumber: batchCtrl.text.trim().isNotEmpty ? batchCtrl.text.trim() : item.batchNumber,
                    expiryDate: expDate,
                    condition: cond,
                    warehouseLocation: locCtrl.text.trim().isNotEmpty ? locCtrl.text.trim() : item.warehouseLocation,
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated ${item.productName} in intake list.'), backgroundColor: Colors.blue),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _duplicateIntakeItem(int index) {
    final item = _intakeItems[index];
    final copy = IntakeItem(
      productId: item.productId,
      productName: item.productName,
      sku: item.sku,
      category: item.category,
      brand: item.brand,
      quantityReceived: item.quantityReceived,
      batchNumber: '${item.batchNumber}-COPY',
      expiryDate: item.expiryDate,
      condition: item.condition,
      warehouseLocation: item.warehouseLocation,
    );
    setState(() {
      _intakeItems.insert(0, copy); // Insert duplicate at the top
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Duplicated ${item.productName} to the top of intake list.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showPostIntakeSuccessDialog(WarehouseIntakeRecord intakeRecord) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.check_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Goods Intake Confirmed!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Receipt #${intakeRecord.intakeNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supplier: ${intakeRecord.supplierName}\nTotal Received: ${intakeRecord.totalQuantity.toInt()} Pcs across ${intakeRecord.items.length} product(s).',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✓ Stock added to Central Warehouse', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                  SizedBox(height: 2),
                  Text('✓ Newly added receipt is placed at the VERY TOP of Warehouse Goods', style: TextStyle(fontSize: 11, color: Colors.blue)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ReportService.generateGoodsReceivedNote(intakeRecord);
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('PRINT GRN SLIP'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(warehouseNavProvider.notifier).setScreen(WarehouseScreen.goods);
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('VIEW GOODS (AT TOP)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmIntake() async {
    if (_formKey.currentState!.validate()) {
      if (_intakeItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot confirm intake: Please add at least one product item to the intake list.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final user = ref.read(currentUserProvider);
        final double expectedTotal = _intakeItems.fold(0.0, (s, i) => s + i.expectedCost);
        final double actualTotal = _intakeItems.fold(0.0, (s, i) => s + i.actualCost);

        final intakeRecord = WarehouseIntakeRecord(
          id: UuidUtils.generate(),
          intakeNumber: _intakeNumberController.text.trim(),
          date: _intakeDate,
          supplierName: _supplierController.text.trim(),
          items: List.from(_intakeItems),
          notes: _notesController.text.trim(),
          receivedBy: user != null ? '${user.firstName} ${user.surname}' : 'Warehouse Staff',
          isConfirmed: true,
          expectedTotalCost: expectedTotal,
          actualTotalCost: actualTotal,
        );

        await ref.read(warehouseIntakeProvider.notifier).confirmIntake(intakeRecord);

        if (mounted) {
          // Reset Form
          setState(() {
            _intakeItems.clear();
            _supplierController.clear();
            _notesController.clear();
            _expectedTargetQtyController.clear();
            final randomStr = (1000 + DateTime.now().millisecond % 9000).toString();
            _intakeNumberController.text = 'INT-${DateFormat('yyyyMMdd').format(DateTime.now())}-$randomStr';
          });

          // Show Post Intake Action Dialog
          _showPostIntakeSuccessDialog(intakeRecord);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error confirming intake: $e'), backgroundColor: Colors.red),
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
    final products = ref.watch(productsFutureProvider).value ?? [];
    final intakes = ref.watch(warehouseIntakeProvider).value ?? [];
    final List<String> previousSuppliers = intakes
        .map((i) => i.supplierName.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

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
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.move_to_inbox_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Goods Intake Workflow', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('Supplier → Receive Goods → Check Goods → Record Intake → Add to Warehouse Stock', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // Intake Header Form Card
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
                  const Text('1. Intake Summary Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.m),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _intakeNumberController,
                                  decoration: const InputDecoration(
                                    labelText: 'Intake Tracking #',
                                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.m),
                              Expanded(
                                child: RawAutocomplete<String>(
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return previousSuppliers.take(5);
                                    }
                                    final query = textEditingValue.text.toLowerCase();
                                    return previousSuppliers.where((s) => s.toLowerCase().contains(query));
                                  },
                                  onSelected: (String selection) {
                                    _supplierController.text = selection;
                                  },
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                    if (controller.text != _supplierController.text && _supplierController.text.isNotEmpty && controller.text.isEmpty) {
                                      controller.text = _supplierController.text;
                                    }
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      onChanged: (val) => _supplierController.text = val,
                                      decoration: const InputDecoration(
                                        labelText: 'Supplier Name',
                                        hintText: 'e.g. L\'Oréal Ghana / Beauty Wholesale',
                                        prefixIcon: Icon(Icons.business_rounded),
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) => (_supplierController.text.trim().isEmpty && (v == null || v.trim().isEmpty)) ? 'Enter supplier name' : null,
                                    );
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(index);
                                              return ListTile(
                                                dense: true,
                                                leading: const Icon(Icons.history_rounded, size: 16, color: Colors.blue),
                                                title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                onTap: () {
                                                  onSelected(option);
                                                  _supplierController.text = option;
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
                                      initialDate: _intakeDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) setState(() => _intakeDate = picked);
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Arrival Date',
                                      prefixIcon: Icon(Icons.calendar_today_rounded),
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(DateFormat('yyyy-MM-dd').format(_intakeDate)),
                                  ),
                                ),
                              ),
                              if (isWide) const SizedBox(width: AppSpacing.m),
                              if (isWide)
                                Expanded(
                                  child: TextFormField(
                                    controller: _notesController,
                                    decoration: const InputDecoration(
                                      labelText: 'General Notes / Invoice #',
                                      prefixIcon: Icon(Icons.note_alt_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (!isWide) ...[
                            const SizedBox(height: AppSpacing.m),
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'General Notes / Invoice #',
                                prefixIcon: Icon(Icons.note_alt_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.m),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _expectedProductCountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Number of Products to Enter',
                                    hintText: 'e.g. 2 (Count of products received in shipment)',
                                    prefixIcon: Icon(Icons.format_list_numbered_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.m),
                              Expanded(
                                child: TextFormField(
                                  controller: _expectedTargetQtyController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Total Units (Optional Pcs Reference)',
                                    hintText: 'e.g. 500 Pcs total',
                                    prefixIcon: Icon(Icons.pin_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // Item Entry Form Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. Add Products to Intake List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.m),
                  _buildCountdownReferenceBanner(theme),
                  RawAutocomplete<Product>(
                    displayStringForOption: (p) => '${p.name} [SKU: ${p.sku ?? p.id.substring(0, 8)}]',
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return products.take(10);
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return products.where((p) =>
                        p.name.toLowerCase().contains(query) ||
                        p.category.toLowerCase().contains(query) ||
                        (p.sku != null && p.sku!.toLowerCase().contains(query))
                      );
                    },
                    onSelected: (p) {
                      setState(() {
                        _selectedProduct = p;
                        if (p.brand != null) _brandController.text = p.brand!;
                        if (p.warehouseLocation != null) _locationController.text = p.warehouseLocation!;
                        _pcsPerBoxController.text = (p.pcsPerBox > 0 ? p.pcsPerBox : 12.0).toInt().toString();
                        _itemCostPriceController.text = p.costPrice > 0 ? p.costPrice.toStringAsFixed(2) : '';
                      });
                    },
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
                              setState(() {
                                _selectedProduct = matched;
                                controller.text = '${matched.name} [SKU: ${matched.sku ?? matched.id.substring(0, 8)}]';
                                if (matched.brand != null) _brandController.text = matched.brand!;
                                if (matched.warehouseLocation != null) _locationController.text = matched.warehouseLocation!;
                                _pcsPerBoxController.text = (matched.pcsPerBox > 0 ? matched.pcsPerBox : 12.0).toInt().toString();
                                _itemCostPriceController.text = matched.costPrice > 0 ? matched.costPrice.toStringAsFixed(2) : '';
                              });
                              _qtyFocusNode.requestFocus();
                            } else {
                              onFieldSubmitted();
                            }
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Search Product Name or SKU / Scan Barcode',
                          hintText: 'Scan barcode or type name (e.g. CeraVe, Lotion...)',
                          prefixIcon: const Icon(Icons.qr_code_scanner),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                tooltip: 'Scan Barcode with Camera',
                                onPressed: () => _scanBarcodeToSelectProduct(context, controller, products),
                              ),
                              if (controller.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    controller.clear();
                                    setState(() => _selectedProduct = null);
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
                            constraints: const BoxConstraints(maxHeight: 250, maxWidth: 500),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final p = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${p.category} • WHS Stock: ${p.stockControlWarehouseDisplay}'),
                                  onTap: () => onSelected(p),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_selectedProduct != null) ...[
                    const SizedBox(height: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, color: Colors.blue, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected: ${_selectedProduct!.name} | WHS Stock: ${_selectedProduct!.stockControlWarehouseDisplay} | POS Store Stock: ${_selectedProduct!.posStockDisplay}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Divider(height: 8),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text('Packaging Options:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              FilterChip(
                                selected: _selectedProduct!.hasBoxes,
                                label: Text(
                                  _selectedProduct!.hasBoxes ? 'Boxes Enabled ✓' : 'Enable Boxes',
                                  style: TextStyle(fontSize: 11, color: _selectedProduct!.hasBoxes ? Colors.green.shade900 : Colors.grey.shade800),
                                ),
                                avatar: Icon(
                                  _selectedProduct!.hasBoxes ? Icons.inventory_2_rounded : Icons.add_box_outlined,
                                  size: 14,
                                  color: _selectedProduct!.hasBoxes ? Colors.green.shade800 : Colors.grey,
                                ),
                                selectedColor: Colors.green.withValues(alpha: 0.2),
                                onSelected: (bool selected) {
                                  final updatedProduct = _selectedProduct!.copyWith(hasBoxes: selected);
                                  setState(() {
                                    _selectedProduct = updatedProduct;
                                    if (selected) {
                                      _selectedUnitType = 'Boxes';
                                    } else if (_selectedUnitType == 'Boxes') {
                                      _selectedUnitType = 'Pieces';
                                    }
                                  });
                                  ref.read(productsFutureProvider.notifier).updateProduct(updatedProduct);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Boxes option ${selected ? "enabled" : "disabled"} for ${_selectedProduct!.name}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                              FilterChip(
                                selected: _selectedProduct!.hasPacks,
                                label: Text(
                                  _selectedProduct!.hasPacks ? 'Packs Enabled ✓' : 'Enable Packs',
                                  style: TextStyle(fontSize: 11, color: _selectedProduct!.hasPacks ? Colors.blue.shade900 : Colors.grey.shade800),
                                ),
                                avatar: Icon(
                                  _selectedProduct!.hasPacks ? Icons.all_inbox_rounded : Icons.add_box_outlined,
                                  size: 14,
                                  color: _selectedProduct!.hasPacks ? Colors.blue.shade800 : Colors.grey,
                                ),
                                selectedColor: Colors.blue.withValues(alpha: 0.2),
                                onSelected: (bool selected) {
                                  final updatedProduct = _selectedProduct!.copyWith(hasPacks: selected);
                                  setState(() {
                                    _selectedProduct = updatedProduct;
                                    if (selected) {
                                      _selectedUnitType = 'Packs';
                                    } else if (_selectedUnitType == 'Packs') {
                                      _selectedUnitType = 'Pieces';
                                    }
                                  });
                                  ref.read(productsFutureProvider.notifier).updateProduct(updatedProduct);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Packs option ${selected ? "enabled" : "disabled"} for ${_selectedProduct!.name}'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (!_selectedProduct!.hasBoxes && !_selectedProduct!.hasPacks) ...[
                            const SizedBox(height: 4),
                            Text(
                              '💡 Boxes/Packs are disabled for this product in Stock Control. Click above to enable them here.',
                              style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.m),
                  Builder(
                    builder: (context) {
                      final hasBoxesOption = _selectedProduct == null || _selectedProduct!.hasBoxes;
                      final hasPacksOption = _selectedProduct != null && _selectedProduct!.hasPacks;

                      // Ensure selected unit type is valid
                      if (_selectedUnitType == 'Boxes' && !hasBoxesOption) {
                        _selectedUnitType = 'Pieces';
                      } else if (_selectedUnitType == 'Packs' && !hasPacksOption) {
                        _selectedUnitType = 'Pieces';
                      }

                      final dropdownItems = [
                        if (hasBoxesOption)
                          const DropdownMenuItem(value: 'Boxes', child: Text('Boxes (Cartons)')),
                        if (hasPacksOption)
                          const DropdownMenuItem(value: 'Packs', child: Text('Packs')),
                        const DropdownMenuItem(value: 'Pieces', child: Text('Pieces (Pcs)')),
                      ];

                      return LayoutBuilder(
                        builder: (context, rowConstraints) {
                          final isNarrow = rowConstraints.maxWidth < 600;
                          return isNarrow
                              ? Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            initialValue: _selectedUnitType,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Add As',
                                              prefixIcon: Icon(Icons.inventory_2_outlined),
                                              border: OutlineInputBorder(),
                                            ),
                                            items: dropdownItems,
                                            onChanged: (val) {
                                              if (val != null) setState(() => _selectedUnitType = val);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.s),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _qtyController,
                                            focusNode: _qtyFocusNode,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                            onChanged: (_) => setState(() {}),
                                            decoration: InputDecoration(
                                              labelText: _selectedUnitType == 'Boxes'
                                                  ? 'Qty Recv (Boxes)'
                                                  : (_selectedUnitType == 'Packs' ? 'Qty Recv (Packs)' : 'Qty Recv (Pcs)'),
                                              prefixIcon: const Icon(Icons.numbers_rounded),
                                              border: const OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_selectedUnitType == 'Boxes') ...[
                                      const SizedBox(height: AppSpacing.s),
                                      TextFormField(
                                        controller: _pcsPerBoxController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                        decoration: const InputDecoration(
                                          labelText: 'Pcs per Box',
                                          hintText: 'e.g. 50',
                                          prefixIcon: Icon(Icons.grid_view_rounded),
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (val) {
                                          final double? parsed = double.tryParse(val.trim());
                                          if (parsed != null && parsed > 0 && _selectedProduct != null) {
                                            final updatedProduct = _selectedProduct!.copyWith(pcsPerBox: parsed);
                                            setState(() {
                                              _selectedProduct = updatedProduct;
                                            });
                                            ref.read(productsFutureProvider.notifier).updateProduct(updatedProduct);
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _selectedUnitType,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Add As',
                                          prefixIcon: Icon(Icons.inventory_2_outlined),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: dropdownItems,
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedUnitType = val);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.m),
                                    if (_selectedUnitType == 'Boxes') ...[
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: _pcsPerBoxController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                          decoration: const InputDecoration(
                                            labelText: 'Pcs / Box',
                                            hintText: 'e.g. 50',
                                            prefixIcon: Icon(Icons.grid_view_rounded),
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            final double? parsed = double.tryParse(val.trim());
                                            if (parsed != null && parsed > 0 && _selectedProduct != null) {
                                              final updatedProduct = _selectedProduct!.copyWith(pcsPerBox: parsed);
                                              setState(() {
                                                _selectedProduct = updatedProduct;
                                              });
                                              ref.read(productsFutureProvider.notifier).updateProduct(updatedProduct);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.m),
                                    ],
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _qtyController,
                                        focusNode: _qtyFocusNode,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          labelText: _selectedUnitType == 'Boxes'
                                              ? 'Qty Received (Boxes)'
                                              : (_selectedUnitType == 'Packs' ? 'Qty Received (Packs)' : 'Qty Received (Pcs)'),
                                          prefixIcon: const Icon(Icons.numbers_rounded),
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                    },
                  );
                },
              ),
              _buildItemQuantityPreview(),
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _itemCostPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Unit Cost Price (GHS / Pc)',
                        hintText: 'Updates product master cost price',
                        prefixIcon: Icon(Icons.sell_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: TextFormField(
                      controller: _itemActualCostController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Actual Total Cost on Receipt (GHS)',
                        hintText: 'Auto-calculated if empty',
                        prefixIcon: Icon(Icons.receipt_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedProduct != null) ...[
                Builder(
                  builder: (context) {
                    final double oldCost = _selectedProduct!.costPrice;
                    final double newCost = double.tryParse(_itemCostPriceController.text.trim()) ?? oldCost;
                    final bool costChanged = newCost > 0 && (newCost - oldCost).abs() > 0.01;

                    if (!costChanged) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(top: AppSpacing.s),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                newCost > oldCost ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                color: newCost > oldCost ? Colors.red.shade800 : Colors.green.shade800,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cost Price ${newCost > oldCost ? "Increased" : "Decreased"}: GHS ${oldCost.toStringAsFixed(2)} → GHS ${newCost.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '💡 Optional: Would you like to adjust selling prices too? Current selling prices are shown as placeholders below.',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _itemRetailPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  decoration: InputDecoration(
                                    labelText: 'New Retail Price (GHS)',
                                    hintText: 'Current: GHS ${_selectedProduct!.retailPrice.toStringAsFixed(2)}',
                                    prefixIcon: const Icon(Icons.storefront_outlined),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _itemWholesalePriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                                  decoration: InputDecoration(
                                    labelText: 'New Wholesale Price (GHS)',
                                    hintText: 'Current: GHS ${_selectedProduct!.wholesalePrice.toStringAsFixed(2)}',
                                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
                  const SizedBox(height: AppSpacing.m),
                  LayoutBuilder(
                    builder: (context, rowConstraints) {
                      final isNarrow = rowConstraints.maxWidth < 600;
                      return isNarrow
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _batchController,
                                        decoration: const InputDecoration(
                                          labelText: 'Batch Number',
                                          hintText: 'e.g. BATCH-2026-A',
                                          prefixIcon: Icon(Icons.qr_code_rounded),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _locationController,
                                        decoration: const InputDecoration(
                                          labelText: 'Location',
                                          hintText: 'e.g. Aisle 2-B',
                                          prefixIcon: Icon(Icons.place_outlined),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s),
                                TextFormField(
                                  controller: _brandController,
                                  decoration: const InputDecoration(
                                    labelText: 'Brand / Manufacturer',
                                    hintText: 'e.g. Anua / CeraVe',
                                    prefixIcon: Icon(Icons.branding_watermark_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _batchController,
                                    decoration: const InputDecoration(
                                      labelText: 'Batch Number',
                                      hintText: 'e.g. BATCH-2026-A',
                                      prefixIcon: Icon(Icons.qr_code_rounded),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.m),
                                Expanded(
                                  child: TextFormField(
                                    controller: _locationController,
                                    decoration: const InputDecoration(
                                      labelText: 'Warehouse Location',
                                      hintText: 'e.g. Aisle 2-B / Shelf 4',
                                      prefixIcon: Icon(Icons.place_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.m),
                                Expanded(
                                  child: TextFormField(
                                    controller: _brandController,
                                    decoration: const InputDecoration(
                                      labelText: 'Brand / Manufacturer',
                                      hintText: 'e.g. Anua / CeraVe',
                                      prefixIcon: Icon(Icons.branding_watermark_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _itemExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) setState(() => _itemExpiryDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date',
                              prefixIcon: Icon(Icons.event_outlined),
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_itemExpiryDate != null 
                              ? DateFormat('yyyy-MM-dd').format(_itemExpiryDate!) 
                              : 'Select Expiry Date'),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: DropdownButtonFormField<ProductCondition>(
                          initialValue: _itemCondition,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Item Condition',
                            prefixIcon: Icon(Icons.health_and_safety_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: ProductCondition.values.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c.name.toUpperCase(), overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (c) => setState(() => _itemCondition = c!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _addItemToIntake,
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: const Text('ADD PRODUCT TO INTAKE LIST', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.l),

            // Multi-item Table Review Card
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
                      final totalPcs = _intakeItems.fold(0.0, (s, i) => s + i.quantityReceived).toInt();

                      final badge = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '${_intakeItems.length} Products • Total: $totalPcs Pcs',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade900),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('3. Review Intake Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            badge,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Expanded(
                            child: Text('3. Review Intake Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          badge,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  if (_intakeItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'No product items added yet. Select a product above and click "ADD PRODUCT TO INTAKE LIST".',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else ...[
                    _buildCostSummaryBanner(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 48,
                        columns: const [
                          DataColumn(label: Text('Product / SKU', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Qty Received', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Expected Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actual Cost', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Batch #', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Condition', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _intakeItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final isNewlyAdded = idx == 0;

                          return DataRow(
                            color: isNewlyAdded ? WidgetStateProperty.all(Colors.green.withValues(alpha: 0.05)) : null,
                            cells: [
                              DataCell(Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      if (isNewlyAdded) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('JUST ADDED ✓', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text('SKU: ${item.sku}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              )),
                              DataCell(Text(item.category)),
                              DataCell(Text('${item.quantityReceived.toInt()} Pcs', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                              DataCell(Text('GHS ${item.expectedCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.blue))),
                              DataCell(Text('GHS ${item.actualCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo))),
                              DataCell(Text(item.batchNumber)),
                              DataCell(Text(item.expiryDate != null ? DateFormat('yyyy-MM-dd').format(item.expiryDate!) : 'N/A')),
                              DataCell(Text(item.condition.name.toUpperCase(), style: TextStyle(color: item.condition == ProductCondition.good ? Colors.green : Colors.red))),
                              DataCell(Text(item.warehouseLocation ?? 'Section A')),
                              DataCell(Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                    tooltip: 'Edit Item',
                                    onPressed: () => _showEditIntakeItemDialog(idx),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, color: Colors.indigo, size: 18),
                                    tooltip: 'Duplicate to Top',
                                    onPressed: () => _duplicateIntakeItem(idx),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    tooltip: 'Remove Item',
                                    onPressed: () => setState(() => _intakeItems.removeAt(idx)),
                                  ),
                                ],
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Final Confirmation Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _confirmIntake,
                icon: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _isSubmitting ? 'CONFIRMING INTAKE...' : 'CONFIRM INTAKE & ADD TO WAREHOUSE STOCK',
                  style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownReferenceBanner(ThemeData theme) {
    final int expectedProducts = int.tryParse(_expectedProductCountController.text.trim()) ?? 0;
    final double targetPcs = double.tryParse(_expectedTargetQtyController.text.trim()) ?? 0.0;
    final int totalAddedProducts = _intakeItems.length;
    final double totalAddedPcs = _intakeItems.fold(0.0, (s, i) => s + i.quantityReceived);

    if (expectedProducts <= 0 && targetPcs <= 0) {
      return const SizedBox.shrink();
    }

    final int remainingProducts = expectedProducts - totalAddedProducts;
    final double remainingPcs = targetPcs - totalAddedPcs;

    final bool productsComplete = expectedProducts > 0 && remainingProducts <= 0;
    final bool pcsComplete = targetPcs > 0 && remainingPcs <= 0;
    final bool isOverProducts = expectedProducts > 0 && totalAddedProducts > expectedProducts;

    final Color statusColor = isOverProducts 
        ? Colors.orange 
        : ((productsComplete || pcsComplete) ? Colors.green : Colors.blue);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                (productsComplete || pcsComplete) 
                  ? Icons.check_circle_rounded 
                  : (isOverProducts ? Icons.warning_amber_rounded : Icons.timer_outlined),
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shipment Product Countdown Reference',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: statusColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (expectedProducts > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOverProducts 
                      ? '+${totalAddedProducts - expectedProducts} Extra Product(s)' 
                      : (productsComplete ? 'All $expectedProducts Products Added' : '${remainingProducts < 0 ? 0 : remainingProducts} Product(s) Left'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (expectedProducts > 0)
                Expanded(
                  child: Text('Products Entered: $totalAddedProducts / $expectedProducts', 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (targetPcs > 0)
                Text('Total Units: ${totalAddedPcs.toInt()} / ${targetPcs.toInt()} Pcs', 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            expectedProducts > 0
              ? (isOverProducts 
                  ? 'Exceeded expected product count by ${totalAddedProducts - expectedProducts} product(s)' 
                  : (productsComplete ? 'All $expectedProducts expected products entered! No product left to enter.' : 'Countdown: ${remainingProducts < 0 ? 0 : remainingProducts} product(s) left to enter'))
              : (pcsComplete ? 'All expected unit quantities accounted for!' : 'Countdown: ${remainingPcs.toInt()} Pcs left to add'),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
          ),
          if (expectedProducts > 0) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (totalAddedProducts / expectedProducts).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: statusColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemQuantityPreview() {
    final int expectedProducts = int.tryParse(_expectedProductCountController.text.trim()) ?? 0;
    final double targetPcs = double.tryParse(_expectedTargetQtyController.text.trim()) ?? 0.0;
    final int totalAddedProducts = _intakeItems.length;
    final double totalAddedPcs = _intakeItems.fold(0.0, (s, i) => s + i.quantityReceived);
    final double inputQty = double.tryParse(_qtyController.text.trim()) ?? 0.0;

    if (expectedProducts <= 0 && targetPcs <= 0) return const SizedBox.shrink();

    final double rawPcsPerBox = double.tryParse(_pcsPerBoxController.text.trim()) ?? 0.0;
    final double pcsPerBox = rawPcsPerBox > 0 
        ? rawPcsPerBox 
        : ((_selectedProduct?.pcsPerBox ?? 0) > 0 ? _selectedProduct!.pcsPerBox : 12.0);
    final double currentInputPcs = _selectedUnitType == 'Boxes' ? (inputQty * pcsPerBox) : inputQty;
    
    final int remainingProductsAfter = expectedProducts > 0 ? (expectedProducts - (totalAddedProducts + 1)) : 0;

    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: Colors.blue.shade800),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              expectedProducts > 0
                ? 'Adding Product #${totalAddedProducts + 1} (${_selectedProduct?.name ?? "Selected Product"}) → ${remainingProductsAfter < 0 ? 0 : remainingProductsAfter} product(s) remaining to enter after this'
                : 'Adding ${currentInputPcs.toInt()} Pcs → ${(targetPcs - totalAddedPcs - currentInputPcs).clamp(0.0, double.infinity).toInt()} Pcs remaining to add',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostSummaryBanner() {
    final double expectedTotal = _intakeItems.fold(0.0, (s, i) => s + i.expectedCost);
    final double actualTotal = _intakeItems.fold(0.0, (s, i) => s + i.actualCost);
    final double variance = actualTotal - expectedTotal;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EXPECTED COST (COST PRICE × QTY)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('GHS ${expectedTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ACTUAL RECEIPT COST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text('GHS ${actualTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('COST VARIANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: variance <= 0 ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  variance == 0
                      ? 'GHS 0.00 (EXACT)'
                      : (variance < 0 ? 'SAVED GHS ${(-variance).toStringAsFixed(2)}' : '+GHS ${variance.toStringAsFixed(2)}'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
