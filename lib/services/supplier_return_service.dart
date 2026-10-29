import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_return_model.dart';
import '../core/supabase_config.dart';
import 'user_provider.dart';
import 'product_service.dart';

class SupabaseSupplierReturnService {
  final _client = SupabaseConfig.client;

  Stream<List<SupplierReturnRecord>> watchSupplierReturns(String branchCode) {
    try {
      var query = _client.from('supplier_returns').stream(primaryKey: ['id']);
      if (branchCode.isNotEmpty) {
        query = query.eq('branch_code', branchCode);
      }
      return query
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => SupplierReturnRecord.fromJson(Map<String, dynamic>.from(json))).toList())
          .handleError((e, st) {
            debugPrint('Supplier Returns Stream Error: $e');
            return <SupplierReturnRecord>[];
          });
    } catch (e) {
      debugPrint('Supplier Returns Stream Init Error: $e');
      return Stream.value([]);
    }
  }

  Future<void> processSupplierReturn(SupplierReturnRecord returnRecord, [String? branchCode]) async {
    try {
      final payload = returnRecord.toJson();
      if (branchCode != null) payload['branch_code'] = branchCode;

      // 1. Record Supplier Return in Supabase
      try {
        await _client.from('supplier_returns').insert(payload);
      } catch (e) {
        debugPrint('Warning inserting supplier_returns: $e');
      }

      // 2. Deduct Returned Batch Quantities from Warehouse Stock
      for (final item in returnRecord.items) {
        final double qtyToDeduct = item.quantityReturned;

        try {
          final current = await _client.from('products').select('warehouse_quantity').eq('id', item.productId).maybeSingle();
          final currentWQty = (current?['warehouse_quantity'] as num? ?? 0.0).toDouble();
          final newWQty = (currentWQty - qtyToDeduct).clamp(0.0, double.infinity);

          await _client.from('products').update({
            'warehouse_quantity': newWQty,
            'last_stock_update': DateTime.now().toIso8601String(),
          }).eq('id', item.productId);
        } catch (e) {
          debugPrint('Error deducting warehouse_quantity for supplier return: $e');
        }

        // Deduct from meat_batches
        try {
          final batchMatch = await _client.from('meat_batches').select('id, current_weight').eq('batch_number', item.batchNumber).maybeSingle();
          if (batchMatch != null && batchMatch['id'] != null) {
            final String bId = batchMatch['id'].toString();
            final bQty = (batchMatch['current_weight'] as num? ?? 0.0).toDouble();
            final newBQty = (bQty - qtyToDeduct).clamp(0.0, double.infinity);
            await _client.from('meat_batches').update({'current_weight': newBQty}).eq('id', bId);
          }
        } catch (e) {
          debugPrint('Error updating batch weight: $e');
        }
      }
    } catch (e) {
      debugPrint('Error processing supplier return: $e');
      rethrow;
    }
  }
}

final supabaseSupplierReturnServiceProvider = Provider<SupabaseSupplierReturnService>((ref) {
  return SupabaseSupplierReturnService();
});

class SupplierReturnNotifier extends StateNotifier<AsyncValue<List<SupplierReturnRecord>>> {
  final SupabaseSupplierReturnService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  SupplierReturnNotifier(this._service, this.ref) : super(const AsyncValue.loading()) {
    _startSubscription();
  }

  void _startSubscription() {
    _subscription?.cancel();
    final user = ref.read(currentUserProvider);
    final branchCode = user?.branchCode ?? '';

    _subscription = _service.watchSupplierReturns(branchCode).listen(
      (returns) => state = AsyncValue.data(returns),
      onError: (e, st) => debugPrint('Supplier Returns Stream Error: $e'),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> submitSupplierReturn(SupplierReturnRecord returnRecord) async {
    final user = ref.read(currentUserProvider);
    await _service.processSupplierReturn(returnRecord, user?.branchCode);
    
    // Refresh product stock
    ref.read(productsFutureProvider.notifier).loadProducts();
  }
}

final supplierReturnProvider = StateNotifierProvider<SupplierReturnNotifier, AsyncValue<List<SupplierReturnRecord>>>((ref) {
  final service = ref.watch(supabaseSupplierReturnServiceProvider);
  return SupplierReturnNotifier(service, ref);
});
