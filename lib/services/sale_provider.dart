import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/sale_model.dart';
import '../models/customer_model.dart';
import '../core/uuid_utils.dart';
import 'customer_provider.dart';
import 'supabase_sale_service.dart';
import 'user_provider.dart';
import 'product_service.dart';
import 'offline_sync_service.dart';
import 'audit_service.dart';
import 'sms_service.dart';

class SaleHistoryNotifier extends StateNotifier<List<SaleRecord>> {
  final SupabaseSaleService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  SaleHistoryNotifier(this._service, this.ref) : super([]) {
    _init();
  }

  void _init() {
    _loadFromCache();
    
    // Watch current user and restart subscription if branch changes
    ref.listen(currentUserProvider, (previous, next) {
      if (next?.branchCode != previous?.branchCode) {
        loadSales();
      }
    });

    loadSales();
  }

  void _loadFromCache() {
    try {
      final box = Hive.box(OfflineSyncService.salesBoxName);
      final List<SaleRecord> cached = [];
      if (box.isNotEmpty) {
        cached.addAll(box.values
            .map((json) => SaleRecord.fromJson(Map<String, dynamic>.from(json))));
      }

      // Merge pending local sales from queue
      final pendingRaw = OfflineSyncService.getPendingItems('SALE');
      final Map<String, SaleRecord> map = {};
      for (final s in cached) {
        map[s.id] = s;
      }
      for (final raw in pendingRaw) {
        final s = SaleRecord.fromJson(raw);
        map[s.id] = s;
      }

      final list = map.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (list.isNotEmpty) {
        state = list;
        debugPrint('Sale Engine: ${list.length} records loaded from local cache & queue.');
      }
    } catch (e) {
      debugPrint('Sale Engine Cache Error: $e');
    }
  }

  void _saveToCache(List<SaleRecord> sales) {
    try {
      final box = Hive.box(OfflineSyncService.salesBoxName);
      box.clear();
      // Keep only last 100 sales offline to save space
      final toCache = sales.take(100).toList();
      for (var s in toCache) {
        box.put(s.id, s.toJson());
      }
    } catch (e) {
      debugPrint('Sale Engine Save Error: $e');
    }
  }

  void _initStream() {
    final user = ref.read(currentUserProvider);
    final branchCode = user?.branchCode ?? '';

    _subscription?.cancel();
    _subscription = _service.getSalesStream(branchCode).listen((cloudSales) {
      final pendingRaw = OfflineSyncService.getPendingItems('SALE');
      final pendingSales = pendingRaw.map((json) => SaleRecord.fromJson(json)).toList();

      final Map<String, SaleRecord> mergedMap = {};
      for (final s in cloudSales) {
        mergedMap[s.id] = s;
      }
      for (final s in pendingSales) {
        mergedMap[s.id] = s;
      }
      for (final s in state) {
        if (!mergedMap.containsKey(s.id)) {
          mergedMap[s.id] = s;
        }
      }

      final mergedList = mergedMap.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      state = mergedList;
      _saveToCache(mergedList);
    }, onError: (e) {
      debugPrint('Sale Stream Error (Offline?): Using cached data.');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> loadSales() async {
    final user = ref.read(currentUserProvider);
    final branchCode = user?.branchCode ?? '';

    // 1. Instant REST fetch over HTTPS
    try {
      final cloudSales = await _service.getSales(branchCode);
      final pendingRaw = OfflineSyncService.getPendingItems('SALE');
      final pendingSales = pendingRaw.map((json) => SaleRecord.fromJson(json)).toList();

      final Map<String, SaleRecord> mergedMap = {};
      for (final s in cloudSales) {
        mergedMap[s.id] = s;
      }
      for (final s in pendingSales) {
        mergedMap[s.id] = s;
      }
      for (final s in state) {
        if (!mergedMap.containsKey(s.id)) {
          mergedMap[s.id] = s;
        }
      }

      final mergedList = mergedMap.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mergedList.isNotEmpty || state.isEmpty) {
        state = mergedList;
        _saveToCache(mergedList);
      }
    } catch (e) {
      debugPrint('Sale REST Load Warning: $e');
    }

    // 2. Realtime WebSocket Stream
    _initStream();
  }

  Future<void> addSale(SaleRecord sale) async {
    final user = ref.read(currentUserProvider);
    final saleWithBranch = sale.copyWith(branchCode: user?.branchCode);

    // 1. INSTANT OPTIMISTIC WRITE (< 5ms)
    // Update local sales state & persistent Hive cache immediately
    state = [saleWithBranch, ...state];
    _saveToCache(state);

    // 2. INSTANT LOCAL STOCK DEDUCTION (< 1ms)
    if (saleWithBranch.isVerified) {
      final productNotifier = ref.read(productsFutureProvider.notifier);
      for (final item in saleWithBranch.items) {
        if (!item.product.isUnlimited) {
          productNotifier.updateStockLocally(
            item.product.id, 
            -item.quantityInPieces,
          );
        }
      }
    }

    // 3. Auto-Register Debtor if missing (non-blocking)
    _ensureCustomerRegistered(saleWithBranch);

    // 4. NON-BLOCKING BACKGROUND CLOUD PUSH
    _pushSaleToCloudInBackground(saleWithBranch);
  }

  Future<void> _pushSaleToCloudInBackground(SaleRecord saleWithBranch) async {
    try {
      // Audit log
      AuditService.log(
        ref: ref,
        action: 'SALE_CREATED',
        entityType: 'SALE',
        entityId: saleWithBranch.id,
        newData: saleWithBranch.toJson(),
      );

      if (!OfflineSyncService.isForcedOffline) {
        final connectivity = await Connectivity().checkConnectivity();
        if (!connectivity.contains(ConnectivityResult.none)) {
          // Push sale
          await _service.saveSale(saleWithBranch);

          // Sync stock changes
          if (saleWithBranch.isVerified) {
            final productNotifier = ref.read(productsFutureProvider.notifier);
            for (final item in saleWithBranch.items) {
              if (!item.product.isUnlimited) {
                await productNotifier.syncStockToCloud(
                  item.product.id, 
                  -item.quantityInPieces,
                );
              }
            }
          }
          return;
        }
      }
      throw Exception('Offline');
    } catch (e) {
      debugPrint('Background Sale Sync Warning (Queuing locally): $e');
      await OfflineSyncService.addToQueue(
        actionType: 'SALE', 
        data: saleWithBranch.toJson(),
      );
    }
  }

  Future<void> verifySale(String saleId, {String? bankReceiptUrl, String? bankReceiptId}) async {
    try {
      final sale = state.firstWhere((s) => s.id == saleId);
      if (sale.isVerified) return;

      final updatedSale = sale.copyWith(
        isVerified: true, 
        status: SaleStatus.completed,
        bankReceiptUrl: bankReceiptUrl ?? sale.bankReceiptUrl,
        bankReceiptId: bankReceiptId ?? sale.bankReceiptId,
      );
      
      // Audit Log
      await AuditService.log(
        ref: ref,
        action: 'SALE_VERIFIED',
        entityType: 'SALE',
        entityId: sale.id,
        newData: updatedSale.toJson(),
      );

      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await _service.saveSale(updatedSale);
      } else {
        await OfflineSyncService.addToQueue(
          actionType: 'SALE',
          data: updatedSale.toJson(),
        );
        state = [for (final s in state) if (s.id == saleId) updatedSale else s];
      }

      for (final item in sale.items) {
        if (!item.product.isUnlimited) {
          await ref.read(productsFutureProvider.notifier).updateStock(
            item.product.id, 
            -item.quantityInPieces, 
            reason: 'SALE', 
            referenceId: sale.id,
          );
        }
      }
    } catch (e) {
      debugPrint('Verify Sale Error: $e');
    }
  }

  Future<void> updateSale(SaleRecord updatedSale) async {
    try {
      final oldSale = state.where((s) => s.id == updatedSale.id).firstOrNull;
      if (oldSale == null) return;

      // 1. Reconciliation Logic for Stock
      // Process items in the updated sale
      for (final newItem in updatedSale.items) {
        if (newItem.product.isUnlimited) continue;
        
        final oldItem = oldSale.items.where((i) => i.product.id == newItem.product.id).firstOrNull;
        if (oldItem != null) {
          final diff = oldItem.quantityInPieces - newItem.quantityInPieces;
          if (diff != 0) {
             await ref.read(productsFutureProvider.notifier).updateStock(
               newItem.product.id, 
               diff, 
               reason: 'SALE_RECTIFIED', 
               referenceId: updatedSale.id,
             );
          }
        } else {
          // New product added to existing receipt: subtract full quantity
          await ref.read(productsFutureProvider.notifier).updateStock(
            newItem.product.id, 
            -newItem.quantityInPieces, 
            reason: 'SALE_RECTIFIED', 
            referenceId: updatedSale.id,
          );
        }
      }
      
      // Check for removed products: add their full quantity back to stock
      for (final oldItem in oldSale.items) {
        if (oldItem.product.isUnlimited) continue;
        final stillExists = updatedSale.items.any((i) => i.product.id == oldItem.product.id);
        if (!stillExists) {
           await ref.read(productsFutureProvider.notifier).updateStock(
             oldItem.product.id, 
             oldItem.quantityInPieces, 
             reason: 'SALE_RECTIFIED', 
             referenceId: updatedSale.id,
           );
        }
      }

      // 2. Audit Log
      await AuditService.log(
        ref: ref,
        action: 'SALE_RECTIFIED',
        entityType: 'SALE',
        entityId: updatedSale.id,
        oldData: oldSale.toJson(),
        newData: updatedSale.toJson(),
      );

      // 3. Database Update
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await _service.updateSale(updatedSale);
      } else {
        await OfflineSyncService.addToQueue(
          actionType: 'SALE',
          data: updatedSale.toJson(),
        );
      }

      // 4. State Update
      state = [for (final s in state) if (s.id == updatedSale.id) updatedSale else s];
      _saveToCache(state);
      
      // Auto-Register Debtor if update created a debt
      _ensureCustomerRegistered(updatedSale);
    } catch (e) {
      debugPrint('Update Sale Error: $e');
    }
  }

  void _ensureCustomerRegistered(SaleRecord sale) {
    if (sale.balance > 0.01 && sale.customerPhone != null) {
      final customers = ref.read(customerProvider);
      final exists = customers.any((c) => c.phone == sale.customerPhone);
      
      if (!exists) {
        final newCustomer = Customer(
          id: UuidUtils.generate(),
          branchCode: sale.branchCode,
          name: sale.customerName ?? 'Walk-in Debtor',
          phone: sale.customerPhone!,
          phone2: null,
          location: 'Auto-added from Debt Sale',
        );
        // addCustomer is optimistic and non-blocking
        ref.read(customerProvider.notifier).addCustomer(newCustomer);
      }
    }
  }

  Future<void> reverseSale(String saleId) async {
    try {
      final sale = state.firstWhere((s) => s.id == saleId);
      
      // 1. Audit Log (Source of truth tracking)
      await AuditService.log(
        ref: ref,
        action: 'SALE_REVERSED',
        entityType: 'SALE',
        entityId: saleId,
        newData: {'id': saleId, 'status': 'reversed', 'reason': 'ADMIN_REVERSE'},
      );

      // 2. Restore Stock
      for (final item in sale.items) {
        if (!item.product.isUnlimited) {
          // Add back the quantity sold
          await ref.read(productsFutureProvider.notifier).updateStock(
            item.product.id, 
            item.quantityInPieces, 
            reason: 'SALE_REVERSED', 
            referenceId: saleId,
          );
        }
      }

      // 3. Update status to Reversed (Do not delete)
      final reversedSale = sale.copyWith(status: SaleStatus.reversed);
      
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await _service.updateSale(reversedSale);
      } else {
        await OfflineSyncService.addToQueue(
          actionType: 'SALE',
          data: reversedSale.toJson(),
        );
      }

      // 4. Update local state
      state = [
        for (final s in state)
          if (s.id == saleId) reversedSale else s
      ];
      _saveToCache(state);

      // 5. Deduct Loyalty Points if customer exists
      if (sale.customerPhone != null) {
        try {
          final customers = ref.read(customerProvider);
          final customer = customers.where((c) => c.phone == sale.customerPhone).firstOrNull;
          if (customer != null) {
            await ref.read(customerProvider.notifier).deductLoyaltyPoints(customer.id, sale.totalAmount);
          }
        } catch (_) {}
      }

      // 6. Send SMS Alert to all admins about the sale reversal
      try {
        final currentUser = ref.read(currentUserProvider);
        final allUsers = ref.read(userProvider);
        final String adminName = currentUser != null ? '${currentUser.firstName} ${currentUser.surname}'.trim() : 'Admin';
        final String branchName = currentUser?.branchCode ?? sale.branchCode ?? 'HQ';
        final String refundMethod = sale.payments.isNotEmpty
            ? sale.payments.map((p) => p.method.name).join(', ')
            : 'cash';

        await SmsService.sendRefundAlertToAdmins(
          receiptId: sale.id,
          amount: sale.totalAmount,
          refundMethod: refundMethod,
          processedBy: adminName,
          branch: branchName,
          allUsers: allUsers,
          reason: 'Full Sale Reversal by Admin',
          isFullReversal: true,
        );
      } catch (e) {
        debugPrint('Error sending admin reversal alert SMS: $e');
      }

    } catch (e) {
      debugPrint('Reverse Sale Error: $e');
      rethrow;
    }
  }

  Future<void> deleteSales(List<String> ids) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        await _service.deleteSales(ids);
      } else {
        for (final id in ids) {
          await OfflineSyncService.addToQueue(
            actionType: 'DELETE_SALE',
            data: {'id': id},
          );
        }
        state = state.where((s) => !ids.contains(s.id)).toList();
      }
    } catch (e) {
      debugPrint('Delete Sales Error: $e');
    }
  }

  Future<void> purgeAllRecords() async {
    try {
      final ids = state.map((s) => s.id).toList();
      for (final id in ids) {
        await OfflineSyncService.addToQueue(
          actionType: 'DELETE_SALE',
          data: {'id': id},
        );
      }
      state = [];
    } catch (e) {
      debugPrint('Purge Sales Error: $e');
    }
  }
}

final saleServiceProvider = Provider<SupabaseSaleService>((ref) {
  return SupabaseSaleService();
});

final saleHistoryProvider = StateNotifierProvider<SaleHistoryNotifier, List<SaleRecord>>((ref) {
  return SaleHistoryNotifier(ref.watch(saleServiceProvider), ref);
});
