import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restock_request_model.dart';
import '../models/warehouse_models.dart';
import '../core/supabase_config.dart';
import 'user_provider.dart';
import 'sms_service.dart';
import 'branch_provider.dart';

class SupabaseRestockRequestService {
  final _client = SupabaseConfig.client;

  Stream<List<ProductRestockRequest>> watchRequests(String branchCode) {
    try {
      var query = _client.from('product_restock_requests').stream(primaryKey: ['id']);
      if (branchCode.isNotEmpty) {
        query = query.eq('branch_code', branchCode);
      }
      return query
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => ProductRestockRequest.fromJson(Map<String, dynamic>.from(json))).toList())
          .handleError((e, st) {
            debugPrint('Restock Requests Stream Error: $e');
            return <ProductRestockRequest>[];
          });
    } catch (e) {
      debugPrint('Restock Request Stream Init Error: $e');
      return Stream.value([]);
    }
  }

  Future<void> addRestockRequest(ProductRestockRequest request) async {
    try {
      await _client.from('product_restock_requests').insert(request.toJson());
    } catch (e) {
      debugPrint('Error inserting restock request: $e');
      rethrow;
    }
  }

  Future<void> markNotified(String requestId) async {
    try {
      await _client.from('product_restock_requests').update({
        'status': 'notified',
        'notified_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    } catch (e) {
      debugPrint('Error updating restock request status: $e');
    }
  }

  Future<void> checkAndNotifyRestockedProducts(WarehouseIntakeRecord intakeRecord, String branchCode, String? branchName) async {
    try {
      // 1. Fetch pending requests
      final response = await _client
          .from('product_restock_requests')
          .select()
          .eq('status', 'pending');

      final List<ProductRestockRequest> pendingRequests = (response as List)
          .map((j) => ProductRestockRequest.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      if (pendingRequests.isEmpty) return;

      // 2. Match against intaked products
      for (final item in intakeRecord.items) {
        final matches = pendingRequests.where((r) =>
          r.productId == item.productId ||
          r.productName.toLowerCase() == item.productName.toLowerCase()
        ).toList();

        for (final req in matches) {
          debugPrint('Restock Match Found! Notifying customer ${req.customerName} (${req.customerPhone}) for ${req.productName}');

          // Send Restock SMS
          final ok = await SmsService.sendRestockAlertSms(
            name: req.customerName,
            phone: req.customerPhone,
            productName: req.productName,
            sizeOrNote: req.variantOrNotes,
            shopName: branchName ?? 'Adom Mmoroso ENT.',
          );

          if (ok) {
            await markNotified(req.id);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking restock notifications: $e');
    }
  }
}

final supabaseRestockRequestServiceProvider = Provider<SupabaseRestockRequestService>((ref) {
  return SupabaseRestockRequestService();
});

class RestockRequestsNotifier extends StateNotifier<AsyncValue<List<ProductRestockRequest>>> {
  final SupabaseRestockRequestService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  RestockRequestsNotifier(this._service, this.ref) : super(const AsyncValue.loading()) {
    _startSubscription();
  }

  void _startSubscription() {
    _subscription?.cancel();
    final user = ref.read(currentUserProvider);
    final branchCode = user?.branchCode ?? '';

    _subscription = _service.watchRequests(branchCode).listen(
      (requests) => state = AsyncValue.data(requests),
      onError: (e, st) => debugPrint('Restock Requests Stream Error: $e'),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> addRequest(ProductRestockRequest request) async {
    final user = ref.read(currentUserProvider);
    final reqWithBranch = request.copyWith(branchCode: user?.branchCode);
    await _service.addRestockRequest(reqWithBranch);
  }

  Future<void> checkIntakeRestocks(WarehouseIntakeRecord intakeRecord) async {
    final user = ref.read(currentUserProvider);
    final branch = ref.read(currentBranchProvider);
    await _service.checkAndNotifyRestockedProducts(
      intakeRecord,
      user?.branchCode ?? '',
      branch?.name,
    );
  }
}

final restockRequestsProvider = StateNotifierProvider<RestockRequestsNotifier, AsyncValue<List<ProductRestockRequest>>>((ref) {
  final service = ref.watch(supabaseRestockRequestServiceProvider);
  return RestockRequestsNotifier(service, ref);
});
