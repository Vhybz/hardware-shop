import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale_return_model.dart';
import '../models/sale_model.dart';
import '../models/product.dart';
import '../core/supabase_config.dart';
import 'user_provider.dart';
import 'sms_service.dart';
import 'product_service.dart';

class SupabaseSaleReturnService {
  final _client = SupabaseConfig.client;

  Stream<List<SaleReturnRecord>> watchReturns(String branchCode) {
    try {
      var query = _client.from('sale_returns').stream(primaryKey: ['id']);
      if (branchCode.isNotEmpty) {
        query = query.eq('branch_code', branchCode);
      }
      return query
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => SaleReturnRecord.fromJson(Map<String, dynamic>.from(json))).toList())
          .handleError((e, st) {
            debugPrint('Sale Returns Stream Error: $e');
            return <SaleReturnRecord>[];
          });
    } catch (e) {
      debugPrint('Sale Returns Stream Init Error: $e');
      return Stream.value([]);
    }
  }

  Future<void> processReturn(SaleReturnRecord returnRecord, SaleRecord originalSale, [String? branchCode]) async {
    try {
      final payload = returnRecord.toJson();
      if (branchCode != null) payload['branch_code'] = branchCode;

      // 1. Record Return Transaction in Supabase
      try {
        await _client.from('sale_returns').insert(payload);
      } catch (e) {
        debugPrint('Warning inserting sale_return: $e');
      }

      // 2. Adjust Product Inventory / Stock in parallel using atomic RPC
      final List<Future<void>> stockTasks = [];

      for (final item in returnRecord.items) {
        final double qtyToRestore = item.quantityReturned;

        if (item.returnToStock) {
          stockTasks.add(() async {
            try {
              await _client.rpc('increment_stock', params: {
                'p_id': item.product.id,
                'p_amount': qtyToRestore,
              });
            } catch (e) {
              debugPrint('Error restoring stock for ${item.product.name}: $e');
            }
          }());
        } else {
          stockTasks.add(() async {
            try {
              await _client.from('butcher_waste').insert({
                'id': returnRecord.id,
                'product_name': item.product.name,
                'meat_type': item.product.name,
                'weight': qtyToRestore,
                'reason': 'Returned Damaged/Defective: ${item.reason.name}',
                'loss_amount': item.totalRefund,
                'created_at': DateTime.now().toIso8601String(),
                'branch_code': branchCode,
              });
            } catch (e) {
              debugPrint('Error logging waste for ${item.product.name}: $e');
            }
          }());
        }
      }

      if (returnRecord.isProductSwap && returnRecord.replacementProductId != null) {
        stockTasks.add(() async {
          try {
            await _client.rpc('increment_stock', params: {
              'p_id': returnRecord.replacementProductId!,
              'p_amount': -(returnRecord.replacementQuantity ?? 1.0),
            });
          } catch (e) {
            debugPrint('Error deducting stock for replacement product: $e');
          }
        }());
      }

      await Future.wait(stockTasks);

      // 3. Update original sale with edited/swapped items under the SAME receipt ID
      try {
        final List<SaleItem> updatedSaleItems = [];
        final Map<String, double> returnedQtyMap = {};
        for (final ret in returnRecord.items) {
          returnedQtyMap[ret.product.id] = (returnedQtyMap[ret.product.id] ?? 0.0) + ret.quantityReturned;
        }

        for (final originalItem in originalSale.items) {
          final double retQty = returnedQtyMap[originalItem.product.id] ?? 0.0;
          final double remainingQty = originalItem.quantity - retQty;
          if (remainingQty > 0) {
            updatedSaleItems.add(
              SaleItem(
                product: originalItem.product,
                quantity: remainingQty,
                priceAtSale: originalItem.priceAtSale,
                originalPrice: originalItem.originalPrice,
                selectedUnit: originalItem.selectedUnit,
              ),
            );
          }
        }

        // Add swapped replacement product to original sale items
        if (returnRecord.isProductSwap && returnRecord.replacementProductId != null) {
          final repProductRes = await _client.from('products').select().eq('id', returnRecord.replacementProductId!).maybeSingle();
          if (repProductRes != null) {
            final repProduct = Product.fromJson(repProductRes);
            updatedSaleItems.add(
              SaleItem(
                product: repProduct,
                quantity: returnRecord.replacementQuantity ?? 1.0,
                priceAtSale: repProduct.retailPrice,
                originalPrice: repProduct.retailPrice,
                selectedUnit: repProduct.unit,
              ),
            );
          }
        }

        final double newTotalAmount = updatedSaleItems.fold(0.0, (s, i) => s + i.total);
        final String newStatus = updatedSaleItems.isEmpty ? 'reversed' : 'rectified';

        await _client.from('sales').update({
          'items': updatedSaleItems.map((e) => e.toJson()).toList(),
          'total_amount': newTotalAmount,
          'status': newStatus,
        }).eq('id', originalSale.id);
      } catch (e) {
        debugPrint('Error updating original sale receipt items: $e');
      }

      // 4. Send Return SMS to Customer
      if (returnRecord.customerPhone != null && returnRecord.customerPhone!.isNotEmpty) {
        try {
          await SmsService.sendReturnReceiptSms(
            name: returnRecord.customerName ?? 'Valued Customer',
            phone: returnRecord.customerPhone!,
            returnNumber: returnRecord.returnNumber,
            originalInvoice: originalSale.id,
            refundAmount: returnRecord.totalRefundAmount,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error processing sale return: $e');
      rethrow;
    }
  }
}

final supabaseSaleReturnServiceProvider = Provider<SupabaseSaleReturnService>((ref) {
  return SupabaseSaleReturnService();
});

class SaleReturnNotifier extends StateNotifier<AsyncValue<List<SaleReturnRecord>>> {
  final SupabaseSaleReturnService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  SaleReturnNotifier(this._service, this.ref) : super(const AsyncValue.loading()) {
    _startSubscription();
  }

  void _startSubscription() {
    _subscription?.cancel();
    final user = ref.read(currentUserProvider);
    final branchCode = user?.branchCode ?? '';

    _subscription = _service.watchReturns(branchCode).listen(
      (returns) => state = AsyncValue.data(returns),
      onError: (e, st) => debugPrint('Sale Returns Stream Error: $e'),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> submitReturn(SaleReturnRecord returnRecord, SaleRecord originalSale) async {
    final user = ref.read(currentUserProvider);
    final allUsers = ref.read(userProvider);
    await _service.processReturn(returnRecord, originalSale, user?.branchCode);
    
    // Refresh product stock list across the app asynchronously
    unawaited(ref.read(productsFutureProvider.notifier).loadProducts());

    // Send SMS Alert to all admins in NON-BLOCKING background task (sub-50ms execution!)
    unawaited(() async {
      try {
        final String cashierName = user != null ? '${user.firstName} ${user.surname}'.trim() : 'Staff';
        final String branchName = user?.branchCode ?? 'HQ';
        final String itemReasons = returnRecord.items.map((i) => i.reason.name).toSet().join(', ');

        await SmsService.sendRefundAlertToAdmins(
          receiptId: originalSale.id,
          returnNumber: returnRecord.returnNumber,
          amount: returnRecord.totalRefundAmount,
          refundMethod: returnRecord.refundMethod,
          processedBy: cashierName,
          branch: branchName,
          allUsers: allUsers,
          reason: itemReasons.isNotEmpty ? itemReasons : 'Customer Item Return/Refund',
          isFullReversal: false,
        );
      } catch (e) {
        debugPrint('Error sending admin refund alert SMS: $e');
      }
    }());
  }
}

final saleReturnProvider = StateNotifierProvider<SaleReturnNotifier, AsyncValue<List<SaleReturnRecord>>>((ref) {
  final service = ref.watch(supabaseSaleReturnServiceProvider);
  return SaleReturnNotifier(service, ref);
});
