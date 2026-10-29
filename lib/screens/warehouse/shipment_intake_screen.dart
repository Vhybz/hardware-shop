import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/uuid_utils.dart';
import '../../models/warehouse_models.dart';
import '../../services/warehouse_service.dart';

class ShipmentIntakeScreen extends ConsumerStatefulWidget {
  const ShipmentIntakeScreen({super.key});

  @override
  ConsumerState<ShipmentIntakeScreen> createState() => _ShipmentIntakeScreenState();
}

class _ShipmentIntakeScreenState extends ConsumerState<ShipmentIntakeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _costController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitShipment() {
    if (_formKey.currentState?.validate() ?? false) {
      final newShipment = ShipmentLog(
        id: UuidUtils.generate(),
        tagNumber: 'SHIP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        supplierName: _supplierController.text.trim(),
        invoiceNumber: _invoiceController.text.trim().isEmpty ? null : _invoiceController.text.trim(),
        arrivalDate: DateTime.now(),
        shipmentCost: double.tryParse(_costController.text.trim()),
        totalItemsReceived: double.tryParse(_quantityController.text.trim()) ?? 0,
        status: ShipmentStatus.receiving,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      ref.read(shipmentLogProvider.notifier).addLog(newShipment);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shipment Intake Recorded Successfully!'), backgroundColor: Colors.green),
      );

      _supplierController.clear();
      _invoiceController.clear();
      _costController.clear();
      _quantityController.clear();
      _notesController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shipmentsAsync = ref.watch(shipmentLogProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Supplier Shipment Intake', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Record hardware and material shipments arriving from suppliers into the Central Warehouse.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: AppSpacing.l),

          // Form Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _supplierController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier / Brand Name',
                        hintText: 'e.g. L\'Oréal Ghana, Maybelline Distributor',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter supplier name' : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _invoiceController,
                            decoration: const InputDecoration(
                              labelText: 'Supplier Invoice #',
                              hintText: 'e.g. INV-2024-998',
                              prefixIcon: Icon(Icons.receipt_long_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Shipment Total Cost (GHS)',
                              prefixIcon: Icon(Icons.payments_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Units/Boxes Received',
                        prefixIcon: Icon(Icons.inventory_2_rounded),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter received quantity' : null,
                    ),
                    const SizedBox(height: AppSpacing.m),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes / Batch Info',
                        hintText: 'e.g., Box 3 slightly dented, driver: Kwame',
                        prefixIcon: Icon(Icons.note_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _submitShipment,
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('RECORD SHIPMENT INTAKE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Recent Intake Logs
          Text('Recent Received Shipments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.m),

          shipmentsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: Text('No shipments recorded yet.')),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final item = logs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.local_shipping_rounded),
                      ),
                      title: Text(item.supplierName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Tracking: ${item.tagNumber} • Units: ${item.totalItemsReceived.toInt()}'),
                      trailing: Chip(
                        label: Text(item.status.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading shipments: $e'),
          ),
        ],
      ),
    );
  }
}

// Legacy Aliases
typedef AnimalIntakeScreen = ShipmentIntakeScreen;
typedef SlaughterLogScreen = ShipmentIntakeScreen;
