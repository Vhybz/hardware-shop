import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';

class WarehouseProcessingScreen extends ConsumerWidget {
  const WarehouseProcessingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stock Processing & Barcode Tagging', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Unbox material shipments, assign batch numbers, track stock, and print barcode price tags.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: AppSpacing.l),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 60, color: Colors.blue),
                  const SizedBox(height: AppSpacing.m),
                  const Text('Select an incoming shipment to unbox and tag barcodes.', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.l),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.document_scanner_rounded),
                    label: const Text('Scan Package Barcode'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Legacy Aliases
typedef MeatProcessingScreen = WarehouseProcessingScreen;
typedef BatchManagementScreen = WarehouseProcessingScreen;
