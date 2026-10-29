import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../services/product_service.dart';
import '../../models/product.dart';
import '../../models/warehouse_models.dart';
import '../../services/warehouse_service.dart';
import '../../services/report_service.dart';

class WarehouseGoodsScreen extends ConsumerStatefulWidget {
  const WarehouseGoodsScreen({super.key});

  @override
  ConsumerState<WarehouseGoodsScreen> createState() => _WarehouseGoodsScreenState();
}

class _WarehouseGoodsScreenState extends ConsumerState<WarehouseGoodsScreen> {
  String _searchQuery = '';
  String _filterCategory = 'All';

  void _showEditBatchDialog(BuildContext context, WarehouseBatch batch, Product? product) {
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);

    final batchNumController = TextEditingController(text: batch.batchNumber);
    final supplierController = TextEditingController(text: batch.source?.name ?? 'Supplier Warehouse');
    final locationController = TextEditingController(text: batch.shelfLocation ?? 'Section A / Shelf 1');
    
    double initialQty = batch.quantity;
    final qtyController = TextEditingController(text: initialQty % 1 == 0 ? initialQty.toInt().toString() : initialQty.toStringAsFixed(1));
    final pcsPerBoxController = TextEditingController(text: (product != null && product.pcsPerBox > 0 ? product.pcsPerBox : 12.0).toInt().toString());

    String selectedUnit = 'Pcs';
    DateTime? expiryDate = batch.expiryDate;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          scrollable: true,
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.edit_note_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Intaked Good: ${batch.productName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Batch #${batch.batchNumber}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s + 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Category: ${batch.category}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                            ),
                            Text(
                              'Received: ${DateFormat('yyyy-MM-dd').format(batch.createdAt)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        if (product != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Associated Catalog Product: ${product.name} (Shop POS Stock: ${product.stockQuantity.toInt()} Pcs)',
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: batchNumController,
                    decoration: const InputDecoration(
                      labelText: 'Batch Number',
                      prefixIcon: Icon(Icons.qr_code_rounded, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: qtyController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: InputDecoration(
                            labelText: selectedUnit == 'Boxes' ? 'Qty (Boxes)' : 'Qty ($selectedUnit)',
                            prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedUnit,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Pcs', child: Text('1. PCS', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Packs', child: Text('2. PACKS', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'Boxes', child: Text('3. BOXES', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (u) => setModalState(() => selectedUnit = u!),
                        ),
                      ),
                      if (selectedUnit == 'Boxes') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: pcsPerBoxController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: const InputDecoration(
                              labelText: 'Pcs/Box',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier / Source Name',
                      prefixIcon: Icon(Icons.business_rounded, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Warehouse Aisle / Shelf Location',
                      prefixIcon: Icon(Icons.place_outlined, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setModalState(() => expiryDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Batch Expiry Date',
                        prefixIcon: Icon(Icons.event_outlined, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      child: Text(
                        expiryDate != null 
                            ? DateFormat('yyyy-MM-dd').format(expiryDate!) 
                            : 'Select Expiry Date',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (formKey.currentState!.validate()) {
                  setModalState(() => isSaving = true);

                  try {
                    final double rawQty = double.tryParse(qtyController.text.trim()) ?? 0.0;
                    final double pcsPerPackVal = product != null ? product.pcsPerPack : 12.0;
                    final double packsPerBoxVal = product != null ? product.packsPerBox : 10.0;

                    double totalPcs = rawQty;
                    if (selectedUnit == 'Packs') {
                      totalPcs = rawQty * pcsPerPackVal;
                    } else if (selectedUnit == 'Boxes') {
                      totalPcs = rawQty * (pcsPerPackVal * packsPerBoxVal);
                    }

                    final updatedBatch = WarehouseBatch(
                      id: batch.id,
                      batchNumber: batchNumController.text.trim(),
                      productName: batch.productName,
                      category: batch.category,
                      quantity: totalPcs,
                      expiryDate: expiryDate,
                      shelfLocation: locationController.text.trim(),
                      source: BatchSource(
                        name: supplierController.text.trim(),
                        location: locationController.text.trim(),
                        owner: 'Adom Mmoroso ENT.',
                      ),
                      createdAt: batch.createdAt,
                    );

                    if (product != null) {
                      await ref.read(productsFutureProvider.notifier).updateStock(product.id, totalPcs);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Updated ${batch.productName} (Batch #${updatedBatch.batchNumber}) successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving changes: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    setModalState(() => isSaving = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SAVE CHANGES'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditReceiptDialog(BuildContext context, WarehouseIntakeRecord intake) {
    final formKey = GlobalKey<FormState>();
    final intakeNumController = TextEditingController(text: intake.intakeNumber);
    final supplierController = TextEditingController(text: intake.supplierName);
    final receivedByController = TextEditingController(text: intake.receivedBy ?? 'Staff');
    final notesController = TextEditingController(text: intake.notes ?? '');
    DateTime selectedDate = intake.date;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          scrollable: true,
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.receipt_long_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Intake Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Ref #${intake.intakeNumber}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: intakeNumController,
                    decoration: const InputDecoration(
                      labelText: 'Receipt / Tag Number',
                      prefixIcon: Icon(Icons.tag_rounded, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier / Source Name',
                      prefixIcon: Icon(Icons.business_rounded, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: receivedByController,
                    decoration: const InputDecoration(
                      labelText: 'Received By (Staff)',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks',
                      prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setModalState(() => selectedDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Intake Date',
                        prefixIcon: Icon(Icons.event_outlined, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(selectedDate),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (formKey.currentState!.validate()) {
                  setModalState(() => isSaving = true);
                  try {
                    final updatedRecord = WarehouseIntakeRecord(
                      id: intake.id,
                      intakeNumber: intakeNumController.text.trim(),
                      date: selectedDate,
                      supplierName: supplierController.text.trim(),
                      items: intake.items,
                      notes: notesController.text.trim(),
                      receivedBy: receivedByController.text.trim(),
                      isConfirmed: intake.isConfirmed,
                      rawQuantity: intake.rawQuantity,
                    );

                    await ref.read(warehouseIntakeProvider.notifier).updateIntake(updatedRecord);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Receipt #${updatedRecord.intakeNumber} updated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating receipt: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    setModalState(() => isSaving = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('SAVE CHANGES'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteReceiptDialog(BuildContext context, WarehouseIntakeRecord intake) {
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.delete_forever_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.m),
              const Expanded(
                child: Text('Delete Intake Receipt?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete intake receipt #${intake.intakeNumber} from "${intake.supplierName}"?',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently remove the receipt record and its ${intake.items.length} included item(s) from intake history.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isDeleting ? null : () async {
                setModalState(() => isDeleting = true);
                try {
                  await ref.read(warehouseIntakeProvider.notifier).deleteIntake(intake);

                  if (intake.id.startsWith('intake_')) {
                    for (final item in intake.items) {
                      await ref.read(warehouseBatchProvider.notifier).deleteBatch(item.productId);
                    }
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Intake receipt #${intake.intakeNumber} deleted successfully.'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting receipt: $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  setModalState(() => isDeleting = false);
                }
              },
              icon: isDeleting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text(isDeleting ? 'DELETING...' : 'DELETE RECEIPT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final intakesAsync = ref.watch(warehouseIntakeProvider);
    final batchesAsync = ref.watch(warehouseBatchProvider);
    final productsAsync = ref.watch(productsFutureProvider);

    final List<WarehouseIntakeRecord> rawIntakes = intakesAsync.value ?? <WarehouseIntakeRecord>[];
    final List<WarehouseBatch> batches = batchesAsync.value ?? <WarehouseBatch>[];
    final List<Product> products = productsAsync.value ?? <Product>[];

    // Build all Intake Receipt Groups (combining rawIntakes and standalone batches)
    List<WarehouseIntakeRecord> allIntakes = List.from(rawIntakes);

    final registeredBatchNumbers = rawIntakes
        .expand((i) => i.items.map((item) => item.batchNumber.toLowerCase()))
        .toSet();

    final standaloneBatches = batches
        .where((b) => !registeredBatchNumbers.contains(b.batchNumber.toLowerCase()))
        .toList();

    final Map<String, List<WarehouseBatch>> standaloneGroups = {};
    for (var b in standaloneBatches) {
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(b.createdAt);
      final key = '${b.batchNumber.isNotEmpty ? b.batchNumber : "BATCH"}_$dateStr';
      standaloneGroups.putIfAbsent(key, () => []).add(b);
    }

    standaloneGroups.forEach((batchNum, bList) {
      final first = bList.first;
      allIntakes.add(
        WarehouseIntakeRecord(
          id: 'intake_${first.id}',
          intakeNumber: batchNum.startsWith('INT-') ? batchNum : 'INT-${batchNum.toUpperCase()}',
          date: first.createdAt,
          supplierName: first.source?.name ?? 'Supplier Warehouse',
          receivedBy: 'Warehouse Staff',
          notes: 'Intaked Warehouse Stock Batch',
          items: bList.map((b) => IntakeItem(
            productId: b.id,
            productName: b.productName,
            sku: b.id.length > 8 ? b.id.substring(0, 8) : b.id,
            category: b.category,
            quantityReceived: b.quantity,
            batchNumber: b.batchNumber,
            expiryDate: b.expiryDate,
            warehouseLocation: b.shelfLocation,
          )).toList(),
        ),
      );
    });

    // Sort intake receipts by date descending (Newest receipts first - newly added at top)
    allIntakes.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return b.intakeNumber.compareTo(a.intakeNumber);
    });

    // Filter Logic per Intake Receipt
    final filteredIntakes = allIntakes.where((intake) {
      final query = _searchQuery.toLowerCase().trim();
      final matchesQuery = query.isEmpty ||
          intake.intakeNumber.toLowerCase().contains(query) ||
          intake.supplierName.toLowerCase().contains(query) ||
          (intake.receivedBy != null && intake.receivedBy!.toLowerCase().contains(query)) ||
          intake.items.any((item) =>
              item.productName.toLowerCase().contains(query) ||
              item.batchNumber.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query) ||
              (item.warehouseLocation != null && item.warehouseLocation!.toLowerCase().contains(query)));

      if (!matchesQuery) return false;

      if (_filterCategory == 'All') return true;
      if (_filterCategory == 'Newly Added') {
        final hoursDiff = DateTime.now().difference(intake.date).inHours;
        return hoursDiff < 48; // receipts from last 48 hours / newly added
      }
      if (_filterCategory == 'Low Stock') {
        return intake.items.any((item) {
          final prod = products.where((p) => p.name.toLowerCase() == item.productName.toLowerCase()).firstOrNull;
          return prod != null && prod.needsDispatch;
        });
      }
      if (_filterCategory == 'Expiring Soon') {
        return intake.items.any((item) {
          if (item.expiryDate == null) return false;
          final days = item.expiryDate!.difference(DateTime.now()).inDays;
          return days >= 0 && days <= 30;
        });
      }
      return intake.items.any((item) => item.category == _filterCategory);
    }).toList();

    final totalQuantityPcs = batches.fold(0.0, (s, b) => s + b.quantity);
    final totalBoxes = totalQuantityPcs / 120.0;
    final expiringSoonCount = batches.where((b) {
      if (b.expiryDate == null) return false;
      final days = b.expiryDate!.difference(DateTime.now()).inDays;
      return days >= 0 && days <= 30;
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner & Summary KPI Row
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
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.receipt_long_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Warehouse Goods & Intake Receipts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('Goods are grouped per intake receipt. Expand any receipt card to view and manage all its intaked products.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.print_rounded, color: Colors.blue),
                      tooltip: 'Print Warehouse Reports',
                      onSelected: (val) {
                        if (val == 'low_stock') {
                          ReportService.generateWarehouseLowStockReport(products);
                        } else if (val == 'valuation') {
                          ReportService.generateWarehouseValuationReport(products);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'low_stock',
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Print Low Stock & Replenishment Report'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'valuation',
                          child: Row(
                            children: [
                              Icon(Icons.request_quote_outlined, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Print Full Warehouse Valuation Ledger'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.l),
                LayoutBuilder(
                  builder: (context, kpiConstraints) {
                    final isMobileKpi = kpiConstraints.maxWidth < 600;
                    return isMobileKpi
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  _summaryStatCard('Intake Receipts', '${allIntakes.length}', Icons.receipt_long_outlined, Colors.indigo, isDark),
                                  const SizedBox(width: AppSpacing.s),
                                  _summaryStatCard('Expiring Soon', '$expiringSoonCount Batches', Icons.event_busy_rounded, Colors.orange, isDark),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s),
                              Row(
                                children: [
                                  _summaryStatCard('Total Stock Units', '${totalQuantityPcs.toInt()} Pcs (${totalBoxes.toStringAsFixed(1)} Boxes)', Icons.inventory_2_outlined, Colors.green, isDark),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              _summaryStatCard('Intake Receipts', '${allIntakes.length}', Icons.receipt_long_outlined, Colors.indigo, isDark),
                              const SizedBox(width: AppSpacing.m),
                              _summaryStatCard('Total Stock Units', '${totalQuantityPcs.toInt()} Pcs (${totalBoxes.toStringAsFixed(1)} Boxes)', Icons.inventory_2_outlined, Colors.green, isDark),
                              const SizedBox(width: AppSpacing.m),
                              _summaryStatCard('Expiring Soon', '$expiringSoonCount Batches', Icons.event_busy_rounded, Colors.orange, isDark),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          // Search & Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by Receipt #, Product Name, Supplier, or Aisle...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _searchQuery = ''))
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.m),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Newly Added', 'Low Stock', 'Building Materials', 'Steel & Rebar', 'Plumbing & PVC', 'Electricals', 'Paints & Finishes', 'Tools & Fasteners'].map((cat) {
                final isSelected = _filterCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : theme.colorScheme.onSurface)),
                    selected: isSelected,
                    selectedColor: Colors.blue.shade700,
                    onSelected: (selected) => setState(() => _filterCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          // Receipt Cards List
          if (filteredIntakes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: theme.dividerColor),
              ),
              child: const Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No intake receipts match your search query or filter.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredIntakes.length,
              itemBuilder: (context, index) {
                final intake = filteredIntakes[index];

                return _IntakeReceiptCard(
                  intake: intake,
                  batches: batches,
                  products: products,
                  isDark: isDark,
                  onEditBatch: (batch, product) => _showEditBatchDialog(context, batch, product),
                  onEditReceipt: (receipt) => _showEditReceiptDialog(context, receipt),
                  onDeleteReceipt: (receipt) => _showDeleteReceiptDialog(context, receipt),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _summaryStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.s),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntakeReceiptCard extends StatefulWidget {
  final WarehouseIntakeRecord intake;
  final List<WarehouseBatch> batches;
  final List<Product> products;
  final bool isDark;
  final Function(WarehouseBatch batch, Product? product) onEditBatch;
  final Function(WarehouseIntakeRecord intake) onEditReceipt;
  final Function(WarehouseIntakeRecord intake) onDeleteReceipt;

  const _IntakeReceiptCard({
    required this.intake,
    required this.batches,
    required this.products,
    required this.isDark,
    required this.onEditBatch,
    required this.onEditReceipt,
    required this.onDeleteReceipt,
  });

  @override
  State<_IntakeReceiptCard> createState() => _IntakeReceiptCardState();
}

class _IntakeReceiptCardState extends State<_IntakeReceiptCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intake = widget.intake;
    final products = widget.products;
    final batches = widget.batches;
    final isDark = widget.isDark;

    final double totalPcs = intake.totalQuantity;
    final double totalBoxes = totalPcs / 120.0;
    final bool isNewlyAdded = DateTime.now().difference(intake.date).inHours < 48;
    final int itemLength = intake.items.length;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.m),
      elevation: isDark ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        side: BorderSide(color: isNewlyAdded ? Colors.green.shade400 : theme.dividerColor, width: isNewlyAdded ? 1.5 : 1.0),
      ),
      child: Column(
        children: [
          // COMPRESSED VIEW: Show ONLY Supplier Name, Receipt Number, Number of Individual Products & Expand Action
          if (!_isExpanded)
            InkWell(
              onTap: () => setState(() => _isExpanded = true),
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s + 2),
                child: Row(
                  children: [
                    // 1. Receipt Number
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade300, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: Colors.blue, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '#${intake.intakeNumber}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),

                    // 2. Supplier Name & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Supplier: ${intake.supplierName}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(intake.date)}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),

                    // 3. Number of Individual Products
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200, width: 0.8),
                      ),
                      child: Text(
                        '$itemLength ${itemLength == 1 ? "Product" : "Products"}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s),

                    // Expand Action
                    IconButton(
                      icon: const Icon(Icons.expand_more_rounded, color: Colors.blue),
                      tooltip: 'Expand Receipt Details',
                      onPressed: () => setState(() => _isExpanded = true),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // EXPANDED VIEW: Show EVERYTHING of that receipt
            InkWell(
              onTap: () => setState(() => _isExpanded = false),
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.receipt_long_rounded, color: Colors.blue, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      '#${intake.intakeNumber}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CONFIRMED',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                              if (isNewlyAdded)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEWLY ADDED ✓',
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.print_outlined, color: Colors.indigo, size: 20),
                          tooltip: 'Print Goods Received Note (GRN)',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => ReportService.generateGoodsReceivedNote(intake),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 20),
                          tooltip: 'Edit Receipt Details',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => widget.onEditReceipt(intake),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          tooltip: 'Delete Receipt',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => widget.onDeleteReceipt(intake),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => setState(() => _isExpanded = false),
                          icon: const Icon(Icons.expand_less_rounded, color: Colors.blue, size: 16),
                          label: const Text(
                            'Collapse',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Supplier: ${intake.supplierName}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Total: ${totalPcs.toInt()} Pcs (${totalBoxes.toStringAsFixed(1)} Bx)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(intake.date)} • Received By: ${intake.receivedBy ?? "Staff"}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (intake.notes != null && intake.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Notes: ${intake.notes}',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Expanded Product Breakdown View
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              color: isDark ? const Color(0xFF182030) : Colors.blue.shade50.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Intake Products (${intake.items.length} Items Included on Receipt)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ref: ${intake.intakeNumber}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 44,
                      columns: const [
                        DataColumn(label: Text('Product Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text('Batch #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text('Receipt Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text('WHS Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text('Shop POS Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text('Expiry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                      rows: intake.items.map((item) {
                        final product = products.where((p) => p.name.toLowerCase() == item.productName.toLowerCase() || p.id == item.productId).firstOrNull;
                        final batchMatch = batches.where((b) => b.batchNumber.toLowerCase() == item.batchNumber.toLowerCase() && b.productName.toLowerCase() == item.productName.toLowerCase()).firstOrNull;

                        final batchToEdit = batchMatch ?? WarehouseBatch(
                          id: item.productId,
                          batchNumber: item.batchNumber,
                          productName: item.productName,
                          category: item.category,
                          quantity: item.quantityReceived,
                          expiryDate: item.expiryDate,
                          shelfLocation: item.warehouseLocation,
                          source: BatchSource(name: intake.supplierName, location: item.warehouseLocation ?? 'HQ', owner: 'Adom Mmoroso ENT.'),
                          createdAt: intake.date,
                        );

                        final double pcsPerPack = (product != null && product.pcsPerPack > 0) ? product.pcsPerPack : 12.0;
                        final double packsPerBox = (product != null && product.packsPerBox > 0) ? product.packsPerBox : 10.0;
                        final double totalPcsPerBox = pcsPerPack * packsPerBox;
                        final double boxes = item.quantityReceived / totalPcsPerBox;

                        final bool isExpiringSoon = item.expiryDate != null && item.expiryDate!.difference(DateTime.now()).inDays <= 30;

                        return DataRow(cells: [
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              if (item.brand != null && item.brand!.isNotEmpty)
                                Text('Brand: ${item.brand}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          )),
                          DataCell(Text(item.category, style: const TextStyle(fontSize: 11))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('#${item.batchNumber}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                          )),
                          DataCell(Text('${item.quantityReceived.toInt()} Pcs (${boxes.toStringAsFixed(1)} Bx)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green))),
                          DataCell(Text('${(product?.warehouseQuantity ?? item.quantityReceived).toInt()} Pcs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${(product?.stockQuantity ?? 0.0).toInt()} Pcs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: (product != null && product.needsDispatch) ? Colors.red : Colors.purple)),
                              if (product != null && product.needsDispatch) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red.shade300, width: 0.8)),
                                  child: const Text('LOW SHOP', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red)),
                                ),
                              ],
                            ],
                          )),
                          DataCell(Text(item.warehouseLocation ?? 'Aisle A', style: const TextStyle(fontSize: 11))),
                          DataCell(Text(
                            item.expiryDate != null ? DateFormat('yyyy-MM-dd').format(item.expiryDate!) : 'N/A',
                            style: TextStyle(fontSize: 11, fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal, color: isExpiringSoon ? Colors.orange : Colors.grey),
                          )),
                          DataCell(OutlinedButton.icon(
                            onPressed: () => widget.onEditBatch(batchToEdit, product),
                            icon: const Icon(Icons.edit_outlined, size: 12),
                            label: const Text('Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
