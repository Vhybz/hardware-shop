import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transfer_models.dart';
import 'offline_sync_service.dart';

class TransferNotifier extends StateNotifier<List<StockTransfer>> {
  final Ref ref;

  TransferNotifier(this.ref) : super([]) {
    _loadFromCache();
  }

  Future<void> loadTransfers() async {
    _loadFromCache();
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.transfersBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.transfersBoxName);
        final list = box.values
            .map((e) => StockTransfer.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = list;
      }
    } catch (_) {}
  }

  Future<void> markAsReceived(String id) async {
    final updated = state.map((t) {
      if (t.id == id) {
        return t.copyWith(status: TransferStatus.received);
      }
      return t;
    }).toList();
    state = updated;
  }

  Future<void> addTransfer(StockTransfer transfer) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.transfersBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.transfersBoxName);
        await box.put(transfer.id, transfer.toJson());
      }
      state = [transfer, ...state];
      await OfflineSyncService.addToQueue('TRANSFER', transfer.toJson());
    } catch (_) {}
  }
}

final transferProvider =
    StateNotifierProvider<TransferNotifier, List<StockTransfer>>((ref) {
  return TransferNotifier(ref);
});

final pendingIncomingTransfersProvider = Provider<List<StockTransfer>>((ref) {
  final transfers = ref.watch(transferProvider);
  return transfers.where((t) => t.status == TransferStatus.pending).toList();
});
