import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_return_model.dart';

class SupplierReturnNotifier extends StateNotifier<AsyncValue<List<SupplierReturnRecord>>> {
  SupplierReturnNotifier() : super(const AsyncValue.data([]));

  Future<void> submitSupplierReturn(SupplierReturnRecord record) async {
    state = AsyncValue.data([record, ...(state.value ?? [])]);
  }
}

final supplierReturnProvider =
    StateNotifierProvider<SupplierReturnNotifier, AsyncValue<List<SupplierReturnRecord>>>((ref) {
  return SupplierReturnNotifier();
});

class SupplierReturnService {
  Stream<List<SupplierReturnRecord>> watchSupplierReturns(
      String branchCode) async* {
    yield [];
  }
}

final supplierReturnServiceProvider = Provider<SupplierReturnService>((ref) {
  return SupplierReturnService();
});

final supplierReturnsProvider =
    StreamProvider.family<List<SupplierReturnRecord>, String>(
        (ref, branchCode) {
  return ref
      .watch(supplierReturnServiceProvider)
      .watchSupplierReturns(branchCode);
});
