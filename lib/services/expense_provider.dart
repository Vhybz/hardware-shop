import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/expense_model.dart';
import 'offline_sync_service.dart';

class ExpenseState {
  final List<ExpenseRecord> records;
  final List<String> categories;

  ExpenseState({required this.records, required this.categories});

  ExpenseState copyWith(
      {List<ExpenseRecord>? records, List<String>? categories}) {
    return ExpenseState(
      records: records ?? this.records,
      categories: categories ?? this.categories,
    );
  }
}

class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final Ref ref;

  ExpenseNotifier(this.ref)
      : super(ExpenseState(
          records: [],
          categories: [
            'Utilities',
            'Rent',
            'Salaries',
            'Transport',
            'Maintenance',
            'Miscellaneous',
            'CEO Withdrawal'
          ],
        )) {
    _init();
  }

  void _init() {
    _loadFromCache();
  }

  Future<void> loadExpenses() async {
    _loadFromCache();
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.expensesBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.expensesBoxName);
        final records = box.values
            .map((e) => ExpenseRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        state = state.copyWith(records: records);
      }
    } catch (e) {
      debugPrint('ExpenseNotifier _loadFromCache error: $e');
    }
  }

  Future<void> addExpense(ExpenseRecord expense) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.expensesBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.expensesBoxName);
        await box.put(expense.id, expense.toJson());
      }
      state = state.copyWith(records: [...state.records, expense]);
      await OfflineSyncService.addToQueue('EXPENSE', expense.toJson());
    } catch (e) {
      debugPrint('addExpense error: $e');
    }
  }

  Future<void> updateExpense(ExpenseRecord expense) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.expensesBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.expensesBoxName);
        await box.put(expense.id, expense.toJson());
      }
      final updated = state.records
          .map((r) => r.id == expense.id ? expense : r)
          .toList();
      state = state.copyWith(records: updated);
    } catch (e) {
      debugPrint('updateExpense error: $e');
    }
  }

  Future<void> recordCEOWithdrawal({
    double? amount,
    String? reason,
    ExpenseRecord? expense,
    double? currentTillBalance,
    double? totalRemainingAfter,
  }) async {
    final exp = expense ??
        ExpenseRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          branchCode: 'MAIN',
          title: reason ?? 'CEO Withdrawal',
          category: 'CEO Withdrawal',
          amount: amount ?? 0.0,
          date: DateTime.now(),
        );
    await addExpense(exp);
  }

  Future<void> purgeCashoutRecords() async {}

  void addCategory(String category) {
    if (!state.categories.contains(category)) {
      state = state.copyWith(categories: [...state.categories, category]);
    }
  }

  Future<String?> uploadReceipt(Uint8List bytes, String fileName) async {
    return null;
  }

  Future<void> purgeAllRecords() async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.expensesBoxName)) {
        await Hive.box(OfflineSyncService.expensesBoxName).clear();
      }
      state = state.copyWith(records: []);
    } catch (e) {
      debugPrint('purgeAllRecords error: $e');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.expensesBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.expensesBoxName);
        await box.delete(id);
      }
      state = state.copyWith(
          records: state.records.where((r) => r.id != id).toList());
      await OfflineSyncService.addToQueue('DELETE_EXPENSE', {'id': id});
    } catch (e) {
      debugPrint('deleteExpense error: $e');
    }
  }
}

final expenseProvider =
    StateNotifierProvider<ExpenseNotifier, ExpenseState>((ref) {
  return ExpenseNotifier(ref);
});
