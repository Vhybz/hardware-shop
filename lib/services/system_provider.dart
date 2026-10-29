import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'user_provider.dart';
import 'offline_sync_service.dart';
import '../models/system_models.dart';

class SystemService {
  Future<List<StockHistory>> getAllStockHistory(String branchCode) async {
    return [];
  }
}

final systemServiceProvider = Provider<SystemService>((ref) {
  return SystemService();
});

final auditLogProvider =
    StateNotifierProvider<AuditNotifier, List<AuditLog>>((ref) {
  return AuditNotifier(ref);
});

class AuditNotifier extends StateNotifier<List<AuditLog>> {
  final Ref ref;

  AuditNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    _loadFromCache();

    ref.listen(currentUserProvider, (previous, next) {
      if (next?.branchCode != previous?.branchCode) {
        refreshLogs();
      }
    });
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.auditBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.auditBoxName);
        final List<AuditLog> cached = box.values
            .map((json) => AuditLog.fromJson(Map<String, dynamic>.from(json)))
            .toList();
        state = cached;
      }
    } catch (e) {
      debugPrint('Audit Engine Cache Error: $e');
    }
  }

  Future<void> refreshLogs() async {
    _loadFromCache();
  }
}

final notificationsFutureProvider =
    FutureProvider<List<SystemNotification>>((ref) async {
  return [];
});

final customerPaymentsProvider =
    FutureProvider.family<List<CustomerPayment>, String>((ref, customerId) async {
  return [];
});

final stockHistoryProvider =
    FutureProvider.family<List<StockHistory>, String>((ref, productId) async {
  return [];
});
