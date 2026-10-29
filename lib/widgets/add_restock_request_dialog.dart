import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/uuid_utils.dart';
import '../models/customer_model.dart';
import '../models/product.dart';
import '../models/restock_request_model.dart';
import '../services/customer_provider.dart';
import '../services/product_service.dart';
import '../services/restock_request_service.dart';

class AddRestockRequestDialog extends ConsumerStatefulWidget {
  final Product? preselectedProduct;
  final Customer? preselectedCustomer;

  const AddRestockRequestDialog({
    super.key,
    this.preselectedProduct,
    this.preselectedCustomer,
  });

  static Future<bool?> show(BuildContext context, {Product? product, Customer? customer}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AddRestockRequestDialog(
        preselectedProduct: product,
        preselectedCustomer: customer,
      ),
    );
  }

  @override
  ConsumerState<AddRestockRequestDialog> createState() => _AddRestockRequestDialogState();
}

class _AddRestockRequestDialogState extends ConsumerState<AddRestockRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  Customer? _selectedCustomer;
  Product? _selectedProduct;
  final TextEditingController _variantNotesController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.preselectedProduct;
    _selectedCustomer = widget.preselectedCustomer;
    if (_selectedCustomer != null) {
      _nameController.text = _selectedCustomer!.name;
      _phoneController.text = _selectedCustomer!.phone;
    }
  }

  @override
  void dispose() {
    _variantNotesController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerProvider);
    final products = ref.watch(productsFutureProvider).value ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      title: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.orange,
            child: Icon(Icons.notifications_active_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.m),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log Customer Product Restock Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Automated SMS will notify customer when item arrives in warehouse', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Customer Auto-complete / Selector
              RawAutocomplete<Customer>(
                initialValue: _selectedCustomer != null ? TextEditingValue(text: '${_selectedCustomer!.name} (${_selectedCustomer!.phone})') : null,
                displayStringForOption: (c) => '${c.name} (${c.phone})',
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return customers.take(8);
                  final query = textEditingValue.text.toLowerCase();
                  return customers.where((c) => c.name.toLowerCase().contains(query) || c.phone.contains(query));
                },
                onSelected: (c) {
                  setState(() {
                    _selectedCustomer = c;
                    _nameController.text = c.name;
                    _phoneController.text = c.phone;
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Search Customer Name or Phone',
                      prefixIcon: Icon(Icons.person_search_rounded),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      if (_selectedCustomer != null && val != '${_selectedCustomer!.name} (${_selectedCustomer!.phone})') {
                        setState(() => _selectedCustomer = null);
                      }
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 450),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final c = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(c.phone),
                              onTap: () => onSelected(c),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              if (_selectedCustomer == null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // Product Auto-complete / Selector
              RawAutocomplete<Product>(
                initialValue: _selectedProduct != null ? TextEditingValue(text: _selectedProduct!.name) : null,
                displayStringForOption: (p) => p.name,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return products.take(8);
                  final query = textEditingValue.text.toLowerCase();
                  return products.where((p) => p.name.toLowerCase().contains(query) || p.category.toLowerCase().contains(query));
                },
                onSelected: (p) {
                  setState(() => _selectedProduct = p);
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Select Out-of-Stock Product',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (_selectedProduct == null && (v == null || v.trim().isEmpty)) ? 'Select a product' : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200, maxWidth: 450),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final p = options.elementAt(index);
                            final isZeroStock = p.warehouseQuantity <= 0 && p.stockQuantity <= 0;
                            return ListTile(
                              dense: true,
                              title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, color: isZeroStock ? Colors.red : null)),
                              subtitle: Text('${p.category} • WHS Stock: ${p.warehouseQuantity.toInt()} Pcs ${isZeroStock ? "(OUT OF STOCK)" : ""}'),
                              onTap: () => onSelected(p),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Variant / Specific Size / Packaging Notes
              TextFormField(
                controller: _variantNotesController,
                decoration: const InputDecoration(
                  labelText: 'Specific Variant / Size / Shade / Notes (Optional)',
                  hintText: 'e.g. 500ml Bottle, Shade Light Beige 02, Boxes required',
                  prefixIcon: Icon(Icons.tune_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : () async {
            if (_formKey.currentState!.validate()) {
              setState(() => _isSaving = true);
              try {
                final req = ProductRestockRequest(
                  id: UuidUtils.generate(),
                  customerId: _selectedCustomer?.id ?? UuidUtils.generate(),
                  customerName: _nameController.text.trim(),
                  customerPhone: _phoneController.text.trim(),
                  productId: _selectedProduct?.id ?? UuidUtils.generate(),
                  productName: _selectedProduct?.name ?? _variantNotesController.text.trim(),
                  productSku: _selectedProduct?.sku,
                  variantOrNotes: _variantNotesController.text.trim().isNotEmpty ? _variantNotesController.text.trim() : null,
                  status: 'pending',
                  createdAt: DateTime.now(),
                );

                await ref.read(restockRequestsProvider.notifier).addRequest(req);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Restock request for ${req.customerName} logged! Automated SMS will trigger upon warehouse intake.'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving request: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            }
          },
          icon: _isSaving 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.notifications_active_rounded, size: 18),
          label: const Text('LOG RESTOCK REQUEST'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade800,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
