import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/customer_model.dart';
import 'user_provider.dart';
import 'offline_sync_service.dart';

class CustomerNotifier extends StateNotifier<List<Customer>> {
  final Ref ref;

  CustomerNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    _loadFromCache();

    ref.listen(currentUserProvider, (previous, next) {
      if (next?.branchCode != previous?.branchCode) {
        loadCustomers();
      }
    });
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.customersBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.customersBoxName);
        final customers = box.values
            .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = customers;
      }
    } catch (e) {
      debugPrint('CustomerNotifier _loadFromCache error: $e');
    }
  }

  Future<void> loadCustomers() async {
    _loadFromCache();
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
        final box = Hive.box<Map>(OfflineSyncService.customersBoxName);
        await box.put(customer.id, customer.toJson());
      }
      state = [...state, customer];
      await OfflineSyncService.addToQueue('CUSTOMER', customer.toJson());
    } catch (e) {
      debugPrint('addCustomer error: $e');
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.customersBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.customersBoxName);
        await box.put(customer.id, customer.toJson());
      }
      state = [
        for (final c in state)
          if (c.id == customer.id) customer else c
      ];
      await OfflineSyncService.addToQueue('CUSTOMER', customer.toJson());
    } catch (e) {
      debugPrint('updateCustomer error: $e');
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.customersBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.customersBoxName);
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
