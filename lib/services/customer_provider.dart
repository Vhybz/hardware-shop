import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/customer_model.dart';
import 'user_provider.dart';
import 'offline_sync_service.dart';
import 'laravel_api_service.dart';

class CustomerNotifier extends StateNotifier<List<Customer>> {
  final Ref ref;

  CustomerNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    _loadFromCache();

    final user = ref.read(currentUserProvider);
    final bCode = user?.branchCode ?? 'MAIN';
    fetchRemoteCustomers(bCode);

    ref.listen(currentUserProvider, (previous, next) {
      final bCode = next?.branchCode ?? 'MAIN';
      if (bCode != previous?.branchCode) {
        _loadFromCache();
        fetchRemoteCustomers(bCode);
      }
    });
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.customersBoxName)) {
        final box = Hive.box(OfflineSyncService.customersBoxName);
        final customers = box.values
            .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = customers;
      }
    } catch (e) {
      debugPrint('CustomerNotifier _loadFromCache error: $e');
    }
  }

  Future<void> fetchRemoteCustomers([String branchCode = 'MAIN']) async {
    try {
      final remoteList = await LaravelApiService.fetchCustomers(branchCode);
      if (remoteList.isNotEmpty) {
        final List<Customer> remoteCustomers = remoteList
            .map((c) => Customer.fromJson(Map<String, dynamic>.from(c)))
            .toList();

        final Map<String, Customer> map = {};
        for (final c in state) {
          map[c.id] = c;
        }
        for (final c in remoteCustomers) {
          map[c.id] = c;
        }

        state = map.values.toList();
        if (Hive.isBoxOpen(OfflineSyncService.customersBoxName)) {
          final box = Hive.box(OfflineSyncService.customersBoxName);
          for (final c in state) {
            await box.put(c.id, c.toJson());
          }
        }
      }
    } catch (e) {
      debugPrint('CustomerNotifier fetchRemoteCustomers error: $e');
    }
  }

  Future<void> loadCustomers() async {
    _loadFromCache();
    final user = ref.read(currentUserProvider);
    await fetchRemoteCustomers(user?.branchCode ?? 'MAIN');
  }

  Future<void> toggleFavorite(String id) async {}

  Future<void> toggleSpecial(String id) async {}

  Future<void> approveCustomer(dynamic customer, {dynamic creditLimit, dynamic priceTier}) async {
    if (customer is Customer) {
      await addCustomer(customer);
    }
  }

  Future<void> rejectCustomer(String id) async {
    await deleteCustomer(id);
  }

  Future<void> addCustomer(Customer customer) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.customersBoxName)) {
        final box = Hive.box(OfflineSyncService.customersBoxName);
        await box.put(customer.id, customer.toJson());
      }
      state = [...state.where((c) => c.id != customer.id), customer];
      unawaited(LaravelApiService.submitCustomer(customer.toJson()));
      await OfflineSyncService.addToQueue('CUSTOMER', customer.toJson());
    } catch (e) {
      debugPrint('addCustomer error: $e');
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.customersBoxName)) {
        final box = Hive.box(OfflineSyncService.customersBoxName);
        await box.put(customer.id, customer.toJson());
      }
      state = [
        for (final c in state)
          if (c.id == customer.id) customer else c
      ];
      unawaited(LaravelApiService.submitCustomer(customer.toJson()));
      await OfflineSyncService.addToQueue('CUSTOMER', customer.toJson());
    } catch (e) {
      debugPrint('updateCustomer error: $e');
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.customersBoxName)) {
        final box = Hive.box(OfflineSyncService.customersBoxName);
        await box.delete(id);
      }
      state = state.where((c) => c.id != id).toList();
      await OfflineSyncService.addToQueue('DELETE_CUSTOMER', {'id': id});
    } catch (e) {
      debugPrint('deleteCustomer error: $e');
    }
  }
}

final customerProvider =
    StateNotifierProvider<CustomerNotifier, List<Customer>>((ref) {
  return CustomerNotifier(ref);
});
