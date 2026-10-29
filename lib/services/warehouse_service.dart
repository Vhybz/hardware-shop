import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/warehouse_models.dart';
import 'supabase_warehouse_service.dart';
import 'user_provider.dart';

class ShipmentLogNotifier extends StateNotifier<AsyncValue<List<ShipmentLog>>> {
  final SupabaseWarehouseService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  ShipmentLogNotifier(this._service, this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    ref.listen(currentUserProvider, (previous, next) {
      if (next?.branchCode != previous?.branchCode) {
        _startSubscription();
      }
    });
    _startSubscription();
  }

  void _startSubscription() {
    _subscription?.cancel();
    final user = ref.read(currentUserProvider);
    if (user?.branchCode != null) {
      _subscription = _service.watchShipmentLogs(user!.branchCode!).listen(
        (logs) => state = AsyncValue.data(logs),
        onError: (e, st) {
          debugPrint('Shipment Logs Stream Error: $e');
        },
        cancelOnError: false,
      );
    } else {
      state = const AsyncValue.data([]);
    }
  }

  Future<void> loadLogs({bool silent = false}) async {
    _startSubscription();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> addLog(ShipmentLog log) async {
    try {
      final user = ref.read(currentUserProvider);
      await _service.addShipmentLog(log, user?.branchCode);
      await loadLogs();
    } catch (e) {
      debugPrint('Error adding shipment log: $e');
    }
  }

  Future<void> updateStatus(String id, ShipmentStatus status) async {
    try {
      await _service.updateShipmentStatus(id, status.name);
      await loadLogs();
    } catch (e) {
      debugPrint('Error updating shipment status: $e');
    }
  }
}

final shipmentLogProvider = StateNotifierProvider<ShipmentLogNotifier, AsyncValue<List<ShipmentLog>>>((ref) {
  final service = ref.watch(supabaseWarehouseServiceProvider);
  return ShipmentLogNotifier(service, ref);
});

// Legacy Alias Providers
typedef SlaughterLogNotifier = ShipmentLogNotifier;
final slaughterLogProvider = shipmentLogProvider;

class WarehouseBatchNotifier extends StateNotifier<AsyncValue<List<WarehouseBatch>>> {
  final SupabaseWarehouseService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  WarehouseBatchNotifier(this._service, this.ref) : super(const AsyncValue.loading()) {
    _startSubscription();
  }

  void _startSubscription() {
    _subscription?.cancel();
    final user = ref.read(currentUserProvider);
    if (user?.branchCode != null) {
      _subscription = _service.watchWarehouseBatches(user!.branchCode!).listen(
        (batches) => state = AsyncValue.data(batches),
        onError: (e, st) => debugPrint('Warehouse Batches Stream Error: $e'),
        cancelOnError: false,
      );
    } else {
      state = const AsyncValue.data([]);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> addBatch(WarehouseBatch batch) async {
    try {
      final user = ref.read(currentUserProvider);
      await _service.addWarehouseBatch(batch, user?.branchCode);
    } catch (e) {
      debugPrint('Error adding warehouse batch: $e');
    }
  }

  Future<void> deleteBatch(String batchId) async {
    try {
      await _service.deleteBatch(batchId);
      _startSubscription();
    } catch (e) {
      debugPrint('Error deleting batch: $e');
    }
  }

  Future<void> deleteBatchesByNumber(String batchNumber) async {
    try {
      await _service.deleteBatchesByNumber(batchNumber);
      _startSubscription();
    } catch (e) {
      debugPrint('Error deleting batches by number: $e');
    }
  }
}

final warehouseBatchProvider = StateNotifierProvider<WarehouseBatchNotifier, AsyncValue<List<WarehouseBatch>>>((ref) {
  final service = ref.watch(supabaseWarehouseServiceProvider);
  return WarehouseBatchNotifier(service, ref);
});

// Legacy Alias Provider
typedef MeatBatchNotifier = WarehouseBatchNotifier;
final meatBatchProvider = warehouseBatchProvider;

class WarehouseIntakeNotifier extends StateNotifier<AsyncValue<List<WarehouseIntakeRecord>>> {
  final SupabaseWarehouseService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  WarehouseIntakeNotifier(this._service, this.ref) : super(const AsyncValue.loading()) {
    _startSubscription();
  }

  void _startSubscription() {
    _subscription?.cancel();
    final user = ref.read(currentUserProvider);
    final branchCode = user?.branchCode ?? '';

    loadIntakes(); // Fetch initial intake snapshot via REST API immediately

    _subscription = _service.watchIntakes(branchCode).listen(
      (intakes) {
        if (intakes.isNotEmpty || !state.hasValue) {
          state = AsyncValue.data(intakes);
        }
      },
      onError: (e, st) => debugPrint('Intakes Stream Error: $e'),
      cancelOnError: false,
    );
  }

  Future<void> loadIntakes() async {
    try {
      final user = ref.read(currentUserProvider);
      final intakes = await _service.getIntakes(user?.branchCode);
      state = AsyncValue.data(intakes);
    } catch (e) {
      debugPrint('Error loading intakes: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> confirmIntake(WarehouseIntakeRecord intake) async {
    try {
      final user = ref.read(currentUserProvider);
      if (state.hasValue) {
        final currentList = state.value ?? [];
        final filtered = currentList.where((i) => i.id != intake.id && i.intakeNumber != intake.intakeNumber).toList();
        state = AsyncValue.data([intake, ...filtered]);
      }
      await _service.confirmIntake(intake, user?.branchCode);
      _startSubscription();
    } catch (e) {
      debugPrint('Error confirming intake: $e');
      rethrow;
    }
  }

  Future<void> updateIntake(WarehouseIntakeRecord intake) async {
    try {
      await _service.updateIntake(intake);
      if (state.hasValue) {
        final currentList = state.value ?? [];
        state = AsyncValue.data(
          currentList.map((i) => (i.id == intake.id || i.intakeNumber == intake.intakeNumber) ? intake : i).toList(),
        );
      }
      _startSubscription();
    } catch (e) {
      debugPrint('Error updating intake: $e');
      rethrow;
    }
  }

  Future<void> deleteIntake(WarehouseIntakeRecord intake) async {
    try {
      await _service.deleteIntake(intake);
      if (state.hasValue) {
        final currentList = state.value ?? [];
        state = AsyncValue.data(
          currentList.where((i) => i.id != intake.id && i.intakeNumber != intake.intakeNumber).toList(),
        );
      }
      _startSubscription();
    } catch (e) {
      debugPrint('Error deleting intake: $e');
      rethrow;
    }
  }
}

final warehouseIntakeProvider = StateNotifierProvider<WarehouseIntakeNotifier, AsyncValue<List<WarehouseIntakeRecord>>>((ref) {
  final service = ref.watch(supabaseWarehouseServiceProvider);
  return WarehouseIntakeNotifier(service, ref);
});

class WarehouseDispatchNotifier extends StateNotifier<AsyncValue<List<WarehouseDispatchRecord>>> {
  final SupabaseWarehouseService _service;
  final Ref ref;
  StreamSubscription? _subscription;

  WarehouseDispatchNotifier(this._service, this.ref) : super(const AsyncValue.loading()) {
    _startSubscription();
  }

  void _startSubscription() {
    _subscription?.cancel();
    final user = ref.read(currentUserProvider);
    if (user?.branchCode != null) {
      _subscription = _service.watchDispatches(user!.branchCode!).listen(
        (dispatches) => state = AsyncValue.data(dispatches),
        onError: (e, st) => debugPrint('Dispatches Stream Error: $e'),
        cancelOnError: false,
      );
    } else {
      state = const AsyncValue.data([]);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> confirmDispatch(WarehouseDispatchRecord dispatch) async {
    try {
      final user = ref.read(currentUserProvider);
      await _service.confirmDispatch(dispatch, user?.branchCode);
      _startSubscription();
    } catch (e) {
      debugPrint('Error confirming dispatch: $e');
      rethrow;
    }
  }
}

final warehouseDispatchProvider = StateNotifierProvider<WarehouseDispatchNotifier, AsyncValue<List<WarehouseDispatchRecord>>>((ref) {
  final service = ref.watch(supabaseWarehouseServiceProvider);
  return WarehouseDispatchNotifier(service, ref);
});
