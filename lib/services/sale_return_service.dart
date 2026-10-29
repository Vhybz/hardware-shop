import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale_return_model.dart';
import '../models/sale_model.dart';

class SaleReturnNotifier extends StateNotifier<AsyncValue<List<SaleReturnRecord>>> {
  SaleReturnNotifier() : super(const AsyncValue.data([]));

  Future<void> submitReturn(SaleReturnRecord record, [SaleRecord? sale]) async {
    state = AsyncValue.data([record, ...(state.value ?? [])]);
  }
}

final saleReturnProvider =
    StateNotifierProvider<SaleReturnNotifier, AsyncValue<List<SaleReturnRecord>>>((ref) {
  return SaleReturnNotifier();
});

class SaleReturnService {
  Stream<List<SaleReturnRecord>> watchReturns(String branchCode) async* {
    yield [];
  }
}

final saleReturnServiceProvider = Provider<SaleReturnService>((ref) {
  return SaleReturnService();
});

final saleReturnsProvider =
    StreamProvider.family<List<SaleReturnRecord>, String>((ref, branchCode) {
  return ref.watch(saleReturnServiceProvider).watchReturns(branchCode);
});
