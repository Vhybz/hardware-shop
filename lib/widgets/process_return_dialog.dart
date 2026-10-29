import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/uuid_utils.dart';
import '../models/sale_model.dart';
import '../models/sale_return_model.dart';
import '../models/product.dart';
import '../services/sale_return_service.dart';
import '../services/report_service.dart';
import '../services/user_provider.dart';
import '../services/product_service.dart';
import 'camera_barcode_scanner_dialog.dart';

class ProcessReturnDialog extends ConsumerStatefulWidget {
  final SaleRecord originalSale;

  const ProcessReturnDialog({super.key, required this.originalSale});

  static Future<bool?> show(BuildContext context, SaleRecord sale) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ProcessReturnDialog(originalSale: sale),
    );
  }

  @override
  ConsumerState<ProcessReturnDialog> createState() => _ProcessReturnDialogState();
}

class _ProcessReturnDialogState extends ConsumerState<ProcessReturnDialog> {
  late Map<int, double> _returnQuantities;
  late Map<int, ReturnReason> _returnReasons;
  late Map<int, bool> _returnToStockMap;
  late Map<int, bool> _itemSelectedMap;

  // Swap vs Direct Refund Options
  bool _isProductSwap = true; // Default: Product Swap
  Product? _replacementProduct;
  double _replacementQty = 1.0;
  final TextEditingController _swapAutocompleteController = TextEditingController();

  String _refundMethod = 'cash';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _returnQuantities = {};
    _returnReasons = {};
    _returnToStockMap = {};
    _itemSelectedMap = {};

    for (int i = 0; i < widget.originalSale.items.length; i++) {
      final item = widget.originalSale.items[i];
      _returnQuantities[i] = item.quantity;
      _returnReasons[i] = ReturnReason.changedMind;
      _returnToStockMap[i] = true;
      _itemSelectedMap[i] = true; // Pre-select items by default
    }
  }

  @override
  void dispose() {
    _swapAutocompleteController.dispose();
    super.dispose();
  }

  void _selectAllForFullReturn() {
    setState(() {
      final bool allSelected = _itemSelectedMap.values.every((v) => v == true);
      for (int i = 0; i < widget.originalSale.items.length; i++) {
        _itemSelectedMap[i] = !allSelected;
        _returnQuantities[i] = widget.originalSale.items[i].quantity;
      }
    });
  }

  void _scanBarcodeToSelectReturnedItem() {
    CameraBarcodeScannerDialog.show(
      context,
      title: 'Scan Barcode of Returned Product',
      onScanned: (String raw) {
        final clean = raw.trim().toLowerCase();
        for (int i = 0; i < widget.originalSale.items.length; i++) {
          final item = widget.originalSale.items[i];
          final skuMatch = item.product.sku != null && item.product.sku!.toLowerCase() == clean;
          final idMatch = item.product.id.toLowerCase() == clean;
          final nameMatch = item.product.name.toLowerCase() == clean;
          if (skuMatch || idMatch || nameMatch) {
            setState(() {
              _itemSelectedMap[i] = true;
            });
            return 'Selected for Return: ${item.product.name}';
          }
        }
        return 'No item matching "$raw" found on this receipt.';
      },
    );
  }

  void _scanBarcodeToSelectSwappedProduct(List<Product> products) {
    CameraBarcodeScannerDialog.show(
      context,
      title: 'Scan Barcode of Swapped / Replacement Product',
      onScanned: (String raw) {
        final clean = raw.trim().toLowerCase();
        final matched = products.where((p) => !p.isDeleted).where((p) {
          final skuMatch = p.sku != null && p.sku!.toLowerCase() == clean;
          final idMatch = p.id.toLowerCase() == clean;
          final nameMatch = p.name.toLowerCase() == clean;
          return skuMatch || idMatch || nameMatch;
        }).firstOrNull;

        if (matched == null) {
          return 'No product matching "$raw" found in catalog.';
        }

        setState(() {
          _replacementProduct = matched;
          _swapAutocompleteController.text = '${matched.name} [SKU: ${matched.sku ?? matched.id.substring(0, 8)}]';
        });
        return 'Selected Replacement: ${matched.name}';
      },
    );
  }

  double get _calculatedReturnedCredit {
    double total = 0.0;
    for (int i = 0; i < widget.originalSale.items.length; i++) {
      if (_itemSelectedMap[i] == true) {
        final item = widget.originalSale.items[i];
        final qty = _returnQuantities[i] ?? 0.0;
        total += qty * item.priceAtSale;
      }
    }
    return total;
  }

  double get _calculatedReplacementCost {
    if (!_isProductSwap || _replacementProduct == null) return 0.0;
    return _replacementProduct!.retailPrice * _replacementQty;
  }

  /// Positive = Refund Due to Customer; Negative = Top-Up Due from Customer
  double get _calculatedNetBalance {
    return _calculatedReturnedCredit - _calculatedReplacementCost;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final products = ref.watch(productsFutureProvider).value ?? [];
    final sale = widget.originalSale;
    final returnedCredit = _calculatedReturnedCredit;
    final replacementCost = _calculatedReplacementCost;
    final netBalance = _calculatedNetBalance;
    final selectedCount = _itemSelectedMap.values.where((v) => v == true).length;

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      title: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.red,
            child: Icon(Icons.assignment_return_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Product Return & Swap Manager', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(
                  'Original Invoice #${sale.id.startsWith('INV-') ? sale.id : (sale.id.length > 8 ? sale.id.substring(sale.id.length - 8).toUpperCase() : sale.id)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 680,
        height: MediaQuery.of(context).size.height * 0.75,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer: ${sale.customerName ?? "Walk-in Customer"}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Original Total: GHS ${sale.totalAmount.toStringAsFixed(2)} • Cashier: ${sale.cashierName}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.red),
                          tooltip: 'Scan Barcode of Returned Product',
                          onPressed: _scanBarcodeToSelectReturnedItem,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _selectAllForFullReturn,
                        icon: const Icon(Icons.select_all_rounded, size: 14),
                        label: Text(
                          selectedCount == sale.items.length ? 'UNSELECT ALL' : 'FULL RETURN (SELECT ALL)',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.m),

              const Text('1. Select Item(s) Being Returned (To Add Back to Stock)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),

              // Item List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sale.items.length,
                itemBuilder: (context, idx) {
                  final item = sale.items[idx];
                  final isSelected = _itemSelectedMap[idx] ?? false;
                  final double returnQty = _returnQuantities[idx] ?? item.quantity;
                  final maxQty = item.quantity;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isSelected ? Colors.red.withValues(alpha: 0.05) : theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isSelected ? Colors.red : theme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: Colors.red,
                                onChanged: (v) => setState(() => _itemSelectedMap[idx] = v ?? false),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Sold Qty: ${maxQty % 1 == 0 ? maxQty.toInt() : maxQty} ${item.selectedUnit ?? item.product.unit} @ GHS ${item.priceAtSale.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('Return Qty: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: returnQty > 1 ? () => setState(() => _returnQuantities[idx] = returnQty - 1) : null,
                                              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.remove, size: 16, color: Colors.red)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              child: Text('${returnQty % 1 == 0 ? returnQty.toInt() : returnQty.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                                            ),
                                            InkWell(
                                              onTap: returnQty < maxQty ? () => setState(() => _returnQuantities[idx] = returnQty + 1) : null,
                                              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Icon(Icons.add, size: 16, color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Refund: GHS ${(returnQty * item.priceAtSale).toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                DropdownButtonFormField<ReturnReason>(
                                  initialValue: _returnReasons[idx],
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Return Reason',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  items: ReturnReason.values.map((r) {
                                    String label;
                                    switch (r) {
                                      case ReturnReason.changedMind: label = 'Customer Changed Mind'; break;
                                      case ReturnReason.defective: label = 'Defective Product'; break;
                                      case ReturnReason.expired: label = 'Expired Product'; break;
                                      case ReturnReason.damaged: label = 'Damaged Packaging'; break;
                                      case ReturnReason.wrongItem: label = 'Wrong Item Sold'; break;
                                    }
                                    return DropdownMenuItem(value: r, child: Text(label, overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: (r) => setState(() => _returnReasons[idx] = r!),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<bool>(
                                  initialValue: _returnToStockMap[idx],
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Stock Action',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  items: const [
                                    DropdownMenuItem(value: true, child: Text('Add Back to Shop Stock ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: false, child: Text('Log as Loss / Damage ❌', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) => setState(() => _returnToStockMap[idx] = val!),
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

              const SizedBox(height: AppSpacing.m),

              // 2. Select Return Action Type (Product Swap vs Refund)
              const Text('2. Return Action Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    selected: _isProductSwap,
                    avatar: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('🔄 Product Swap / Exchange', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    selectedColor: Colors.blue.withValues(alpha: 0.25),
                    labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                    onSelected: (val) {
                      if (val) setState(() => _isProductSwap = true);
                    },
                  ),
                  ChoiceChip(
                    selected: !_isProductSwap,
                    avatar: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('💵 Direct Cash/MoMo Refund', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    selectedColor: Colors.red.withValues(alpha: 0.25),
                    labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                    onSelected: (val) {
                      if (val) setState(() => _isProductSwap = false);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Product Swap Section
              if (_isProductSwap) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Replacement Product (To Deduct from Stock):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                      const SizedBox(height: 8),
                      RawAutocomplete<Product>(
                        displayStringForOption: (p) => '${p.name} [SKU: ${p.sku ?? p.id.substring(0, 8)}]',
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return products.take(8);
                          final query = textEditingValue.text.toLowerCase();
                          return products.where((p) => !p.isDeleted).where((p) =>
                            p.name.toLowerCase().contains(query) ||
                            p.category.toLowerCase().contains(query) ||
                            (p.sku != null && p.sku!.toLowerCase().contains(query))
                          );
                        },
                        onSelected: (p) => setState(() => _replacementProduct = p),
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Search or Scan Replacement Product',
                              hintText: 'Type name or scan barcode...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.camera_alt_outlined, color: Colors.blue),
                                tooltip: 'Scan Replacement Product Barcode',
                                onPressed: () => _scanBarcodeToSelectSwappedProduct(products),
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
                                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 450),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final p = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('GHS ${p.retailPrice.toStringAsFixed(2)} • Stock: ${p.posStockDisplay}'),
                                      onTap: () => onSelected(p),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_replacementProduct != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected: ${_replacementProduct!.name}\nPrice: GHS ${_replacementProduct!.retailPrice.toStringAsFixed(2)} / ${_replacementProduct!.unit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                            ),
                            Row(
                              children: [
                                const Text('Qty: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: _replacementQty > 1 ? () => setState(() => _replacementQty--) : null,
                                        child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.remove, size: 16, color: Colors.blue)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text('${_replacementQty.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                                      ),
                                      InkWell(
                                        onTap: () => setState(() => _replacementQty++),
                                        child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.add, size: 16, color: Colors.blue)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Refund Method (For Remaining Balance or Full Refund)
              DropdownButtonFormField<String>(
                initialValue: _refundMethod,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _isProductSwap ? 'Method for Remaining Balance' : 'Refund Payment Method',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash (Till Reconciliation)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'mobileMoney', child: Text('Mobile Money Transfer', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'store_credit', child: Text('Store Credit / Debt Reduction', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _refundMethod = val);
                },
              ),

              const SizedBox(height: 16),

              // Total & Balance Calculation Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: netBalance < 0 ? Colors.orange.shade800 : Colors.indigo.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Returned Item Credit:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('GHS ${returnedCredit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    if (_isProductSwap && _replacementProduct != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Swapped (${_replacementProduct!.name}):',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('GHS ${replacementCost.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                    const Divider(color: Colors.white30, height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            netBalance > 0
                                ? (_isProductSwap ? 'REMAINING REFUND DUE:' : 'TOTAL CASH REFUND DUE:')
                                : (netBalance < 0 ? 'TOP-UP REQUIRED:' : 'EVEN SWAP:'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'GHS ${netBalance.abs().toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _handleProcessReturn,
          icon: _isProcessing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.assignment_return_rounded, size: 18),
          label: Text(_isProcessing ? 'PROCESSING...' : (_isProductSwap ? 'CONFIRM PRODUCT SWAP' : 'CONFIRM & ISSUE REFUND')),
          style: ElevatedButton.styleFrom(
            backgroundColor: netBalance < 0 ? Colors.orange.shade800 : Colors.indigo.shade800,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _handleProcessReturn() async {
    final sale = widget.originalSale;
    final returnedCredit = _calculatedReturnedCredit;
    final replacementCost = _calculatedReplacementCost;
    final netBalance = _calculatedNetBalance;

    if (returnedCredit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item to return.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isProductSwap) {
      if (_replacementProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please search or scan a replacement product to complete the swap.'), backgroundColor: Colors.orange),
        );
        return;
      }

      final double availableStock = _replacementProduct!.stockQuantity;
      if (availableStock <= 0 || _replacementQty > availableStock) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.red),
                SizedBox(width: 10),
                Text('Swapped Product Out of Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              '⚠️ CANNOT SWAP: ${_replacementProduct!.name} is currently out of stock or has insufficient quantity (Available: ${availableStock.toInt()} Pcs, Requested: ${_replacementQty.toInt()} Pcs).\n\nPlease select an available replacement product or restock first.',
              style: const TextStyle(fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK, CHOOSE ANOTHER PRODUCT'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final user = ref.read(currentUserProvider);
      final List<ReturnedItem> returnedItemsList = [];

      for (int i = 0; i < sale.items.length; i++) {
        if (_itemSelectedMap[i] == true) {
          final item = sale.items[i];
          final qty = _returnQuantities[i] ?? item.quantity;
          returnedItemsList.add(
            ReturnedItem(
              product: item.product,
              quantityReturned: qty,
              priceAtSale: item.priceAtSale,
              selectedUnit: item.selectedUnit,
              reason: _returnReasons[i] ?? ReturnReason.changedMind,
              returnToStock: _returnToStockMap[i] ?? true,
            ),
          );
        }
      }

      final returnRecord = SaleReturnRecord(
        id: UuidUtils.generate(),
        returnNumber: 'RET-${sale.id.replaceAll('RET-', '')}', // Retains the exact same original receipt number
        originalSaleId: sale.id,
        customerName: sale.customerName,
        customerPhone: sale.customerPhone,
        items: returnedItemsList,
        totalRefundAmount: netBalance, // positive = refund to customer; negative = topup from customer
        refundMethod: _refundMethod,
        processedBy: user?.name ?? 'Staff',
        createdAt: DateTime.now(),
        replacementProductId: _isProductSwap ? _replacementProduct?.id : null,
        replacementProductName: _isProductSwap ? _replacementProduct?.name : null,
        replacementQuantity: _isProductSwap ? _replacementQty : null,
        replacementTotalCost: _isProductSwap ? replacementCost : null,
      );

      // Submit return to backend & adjust stock
      await ref.read(saleReturnProvider.notifier).submitReturn(returnRecord, sale);

      if (mounted) {
        Navigator.pop(context, true);

        // Print Return Slip PDF
        ReportService.generateReturnSlip(returnRecord);

        final String summaryMsg = netBalance > 0
            ? 'Return #${returnRecord.returnNumber} processed! Remaining balance GHS ${netBalance.toStringAsFixed(2)} refunded.'
            : (netBalance < 0 
                ? 'Product Swap #${returnRecord.returnNumber} completed! Top-up GHS ${(-netBalance).toStringAsFixed(2)} collected.'
                : 'Even Product Swap #${returnRecord.returnNumber} completed successfully!');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(summaryMsg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing return/swap: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
