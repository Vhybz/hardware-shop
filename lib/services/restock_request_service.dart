import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/restock_request_model.dart';

class RestockRequestNotifier
    extends StateNotifier<AsyncValue<List<ProductRestockRequest>>> {
  RestockRequestNotifier() : super(const AsyncValue.data([]));

  Future<void> addRequest(ProductRestockRequest req) async {
    state = AsyncValue.data([req, ...(state.value ?? [])]);
  }
}

final restockRequestsProvider = StateNotifierProvider.family<
    RestockRequestNotifier,
    AsyncValue<List<ProductRestockRequest>>,
    String>((ref, branchCode) {
  return RestockRequestNotifier();
});

class RestockRequestService {
  Stream<List<ProductRestockRequest>> watchRequests(String branchCode) async* {
    yield [];
  }
}

final restockRequestServiceProvider = Provider<RestockRequestService>((ref) {
  return RestockRequestService();
});
