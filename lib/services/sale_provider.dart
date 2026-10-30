import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/sale_model.dart';
import 'user_provider.dart';
import 'product_service.dart';
import 'offline_sync_service.dart';
import 'laravel_api_service.dart';

class SaleHistoryNotifier extends StateNotifier<List<SaleRecord>> {
  final Ref ref;

  SaleHistoryNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    _loadFromCache();

    ref.listen(currentUserProvider, (previous, next) {
      if (next?.branchCode != previous?.branchCode) {
        loadSales();
      }
    });

    loadSales();
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.salesBoxName)) {
        final box = Hive.box(OfflineSyncService.salesBoxName);
        final List<SaleRecord> cached = [];
        if (box.isNotEmpty) {
          cached.addAll(box.values.map(
              (json) => SaleRecord.fromJson(Map<String, dynamic>.from(json))));
        }

        final list = cached..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = list;
      }
    } catch (e) {
      debugPrint('Sale Engine Cache Error: $e');
    }
  }

  Future<void> loadSales() async {
    _loadFromCache();
  }

  Future<void> addSale(SaleRecord sale) async {
    await recordSale(sale);
  }

  Future<void> updateSale(SaleRecord sale) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.salesBoxName)) {
        final box = Hive.box(OfflineSyncService.salesBoxName);
        await box.put(sale.id, sale.toJson());
      }
      state = [
        for (final s in state)
          if (s.id == sale.id) sale else s
      ];
    } catch (e) {
      debugPrint('updateSale error: $e');
    }
  }

  Future<void> deleteSales(List<String> ids) async {
    state = state.where((s) => !ids.contains(s.id)).toList();
  }

  Future<void> reverseSale(String id) async {
    final s = state.where((item) => item.id == id).firstOrNull;
    if (s != null) {
      final updated = s.copyWith(status: SaleStatus.reversed);
      await updateSale(updated);
    }
  }

  Future<void> verifySale(String id,
      {String? bankReceiptUrl, String? bankReceiptId}) async {
    final s = state.where((item) => item.id == id).firstOrNull;
    if (s != null) {
      final updated = s.copyWith(status: SaleStatus.completed);
      await updateSale(updated);
    }
  }

  Future<void> purgeAllRecords() async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.salesBoxName)) {
        await Hive.box(OfflineSyncService.salesBoxName).clear();
      }
      state = [];
    } catch (e) {
      debugPrint('purgeAllRecords error: $e');
    }
  }

  Future<void> recordSale(SaleRecord sale) async {
    try {
      // 1. Instant local persistence & state update (0ms)
      if (Hive.isBoxOpen(OfflineSyncService.salesBoxName)) {
        final box = Hive.box(OfflineSyncService.salesBoxName);
        await box.put(sale.id, sale.toJson());
      }
      state = [sale, ...state];

      // 2. Decrement local stock instantly (0ms)
      for (final item in sale.items) {
        ref
            .read(productsFutureProvider.notifier)
            .updateStock(item.product.id, -item.quantity);
      }

      // 3. Asynchronous background cloud sync (0ms blocking time)
      unawaited(() async {
        try {
          final success = await LaravelApiService.submitSale(sale.toJson());
          if (!success) {
            await OfflineSyncService.addToQueue('SALE', sale.toJson());
          }
        } catch (e) {
          debugPrint('submitSale API error, queueing offline: $e');
          await OfflineSyncService.addToQueue('SALE', sale.toJson());
        }
      }());
    } catch (e) {
      debugPrint('recordSale error: $e');
    }
  }
}

final saleHistoryProvider =
    StateNotifierProvider<SaleHistoryNotifier, List<SaleRecord>>((ref) {
  return SaleHistoryNotifier(ref);
});
