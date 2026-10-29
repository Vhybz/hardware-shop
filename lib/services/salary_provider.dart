import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/salary_model.dart';

class SalaryNotifier extends StateNotifier<List<SalaryRecord>> {
  SalaryNotifier() : super([]);

  Future<void> loadAll() async {}

  Future<void> addPayment(SalaryRecord record) async {
    state = [record, ...state];
  }

  Future<void> updatePayment(SalaryRecord updated) async {
    state = [
      for (final r in state)
        if (r.id == updated.id) updated else r
    ];
  }

  Future<void> deletePayment(String id) async {
    state = state.where((r) => r.id != id).toList();
  }

  List<SalaryRecord> getPaymentsForUser(String userId) {
    return state.where((p) => p.userId == userId).toList();
  }
}

final salaryHistoryProvider =
    StateNotifierProvider<SalaryNotifier, List<SalaryRecord>>((ref) {
  return SalaryNotifier();
});
