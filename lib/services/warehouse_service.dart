import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/warehouse_models.dart';

class WarehouseIntakeNotifier
    extends StateNotifier<AsyncValue<List<WarehouseIntakeRecord>>> {
  WarehouseIntakeNotifier()
      : super(const AsyncValue.data(<WarehouseIntakeRecord>[]));

  Future<void> confirmIntake(dynamic record) async {}
  Future<void> updateIntake(dynamic record) async {}
  Future<void> deleteIntake(dynamic record) async {}
  Future<void> loadIntakes() async {}
}

final warehouseIntakeProvider = StateNotifierProvider<WarehouseIntakeNotifier,
    AsyncValue<List<WarehouseIntakeRecord>>>((ref) {
  return WarehouseIntakeNotifier();
});

class WarehouseDispatchNotifier
    extends StateNotifier<AsyncValue<List<WarehouseDispatchRecord>>> {
  WarehouseDispatchNotifier()
      : super(const AsyncValue.data(<WarehouseDispatchRecord>[]));

  Future<void> confirmDispatch(dynamic record) async {}
}

final warehouseDispatchProvider = StateNotifierProvider<
    WarehouseDispatchNotifier,
    AsyncValue<List<WarehouseDispatchRecord>>>((ref) {
  return WarehouseDispatchNotifier();
});

class WarehouseBatchNotifier
    extends StateNotifier<AsyncValue<List<WarehouseBatch>>> {
  WarehouseBatchNotifier() : super(const AsyncValue.data([]));

  Future<void> deleteBatch(String productId) async {}
}

final warehouseBatchProvider = StateNotifierProvider<WarehouseBatchNotifier,
    AsyncValue<List<WarehouseBatch>>>((ref) {
  return WarehouseBatchNotifier();
});

final productPendingWeightProvider =
    Provider.family<double, String>((ref, productName) {
  return 0.0;
});

class ShipmentLogNotifier
    extends StateNotifier<AsyncValue<List<ShipmentLog>>> {
  final Ref ref;

  ShipmentLogNotifier(this.ref) : super(const AsyncValue.data([]));

  Future<void> addLog(dynamic record) async {}
}

final shipmentLogProvider = StateNotifierProvider<ShipmentLogNotifier,
    AsyncValue<List<ShipmentLog>>>((ref) {
  return ShipmentLogNotifier(ref);
});

final warehouseServiceProvider = Provider((ref) => null);
