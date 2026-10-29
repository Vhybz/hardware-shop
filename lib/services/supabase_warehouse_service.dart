import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/warehouse_models.dart';
import '../core/supabase_config.dart';
import '../core/uuid_utils.dart';
import 'restock_request_service.dart';

class SupabaseWarehouseService {
  SupabaseClient get _client => SupabaseConfig.client;

  Stream<List<ShipmentLog>> watchShipmentLogs(String branchCode) {
    try {
      return _client
          .from('slaughter_logs')
          .stream(primaryKey: ['id'])
          .eq('branch_code', branchCode)
          .order('slaughter_time', ascending: false)
          .map((data) => data.map((json) => ShipmentLog.fromJson(json)).toList())
          .handleError((e, st) {
            debugPrint('Supabase watchShipmentLogs Stream Warning: $e');
            return <ShipmentLog>[];
          });
    } catch (e) {
      debugPrint('SupabaseWarehouseService Stream Error: $e');
      return Stream.value([]);
    }
  }

  Future<List<ShipmentLog>> getShipmentLogs(String branchCode) async {
    try {
      final data = await _client
          .from('slaughter_logs')
          .select()
          .eq('branch_code', branchCode)
          .order('slaughter_time', ascending: false);
      return (data as List).map((json) => ShipmentLog.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting shipment logs: $e');
      return [];
    }
  }

  Future<void> addShipmentLog(ShipmentLog log, [String? branchCode]) async {
    try {
      final json = log.toJson();
      if (branchCode != null) json['branch_code'] = branchCode;
      await _client.from('slaughter_logs').insert(json);
    } catch (e) {
      debugPrint('Error inserting shipment log: $e');
      rethrow;
    }
  }

  Future<void> updateShipmentStatus(String id, String status) async {
    try {
      await _client.from('slaughter_logs').update({'status': status}).eq('id', id);
    } catch (e) {
      debugPrint('Error updating shipment status: $e');
      rethrow;
    }
  }

  Stream<List<WarehouseBatch>> watchWarehouseBatches(String branchCode) {
    try {
      return _client
          .from('meat_batches')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) => data.map((json) => WarehouseBatch.fromJson(json)).toList())
          .handleError((e, st) {
            debugPrint('Supabase watchWarehouseBatches Stream Warning: $e');
            return <WarehouseBatch>[];
          });
    } catch (e) {
      debugPrint('Error watching warehouse batches: $e');
      return Stream.value([]);
    }
  }

  Future<void> addWarehouseBatch(WarehouseBatch batch, [String? branchCode]) async {
    try {
      final json = batch.toJson();
      if (branchCode != null) json['branch_code'] = branchCode;
      await _client.from('meat_batches').insert(json);
    } catch (e) {
      debugPrint('Error inserting warehouse batch: $e');
      rethrow;
    }
  }

  Future<void> updateWarehouseBatch(WarehouseBatch batch) async {
    try {
      await _client.from('meat_batches').update({
        'batch_number': batch.batchNumber,
        'meat_type': batch.productName,
        'initial_weight': batch.quantity,
        'current_weight': batch.quantity,
        'expiry_date': batch.expiryDate?.toIso8601String(),
        'shelf_location': batch.shelfLocation,
        'source_name': batch.source?.name,
      }).eq('id', batch.id);
    } catch (e) {
      debugPrint('Error updating warehouse batch: $e');
      rethrow;
    }
  }

  Future<void> updateProductWarehouseStock(String productId, double newQty) async {
    try {
      await _client.from('products').update({
        'warehouse_quantity': newQty,
        'last_stock_update': DateTime.now().toIso8601String(),
      }).eq('id', productId);
    } catch (e) {
      debugPrint('Warning: Could not update warehouse_quantity on products ($e). Falling back gracefully.');
      try {
        await _client.from('products').update({
          'last_stock_update': DateTime.now().toIso8601String(),
        }).eq('id', productId);
      } catch (_) {}
    }
  }

  // --- NEW INTENT-BASED INTAKE & DISPATCH API ---

  Future<List<WarehouseIntakeRecord>> getIntakes([String? branchCode]) async {
    try {
      var query = _client.from('slaughter_logs').select();
      if (branchCode != null && branchCode.isNotEmpty) {
        query = query.or('branch_code.eq.$branchCode,branch_code.is.null');
      }
      final response = await query.order('slaughter_time', ascending: false).limit(200);
      return (response as List).map((json) => WarehouseIntakeRecord.fromJson(Map<String, dynamic>.from(json))).toList();
    } catch (e) {
      debugPrint('Error getting intakes: $e');
      return [];
    }
  }

  Stream<List<WarehouseIntakeRecord>> watchIntakes([String? branchCode]) {
    try {
      return _client
          .from('slaughter_logs')
          .stream(primaryKey: ['id'])
          .order('slaughter_time', ascending: false)
          .map((data) => data.map((json) {
                final map = Map<String, dynamic>.from(json);
                return WarehouseIntakeRecord.fromJson(map);
              }).toList())
          .handleError((e, st) {
            debugPrint('Supabase watchIntakes Stream Warning: $e');
            return <WarehouseIntakeRecord>[];
          });
    } catch (e) {
      debugPrint('Error watching intakes: $e');
      return Stream.value([]);
    }
  }

  Future<void> confirmIntake(WarehouseIntakeRecord intake, [String? branchCode]) async {
    try {
      // 1. Record Intake Transaction in slaughter_logs
      final Map<String, dynamic> logPayload = {
        'id': intake.id,
        'branch_code': branchCode,
        'tag_number': intake.intakeNumber,
        'type': intake.supplierName,
        'quantity': intake.items.length,
        'initial_weight': intake.totalQuantity,
        'carcass_weight': intake.totalQuantity,
        'status': 'completed',
        'slaughter_time': intake.date.toIso8601String(),
        'source_farm': intake.supplierName,
        'received_by': intake.receivedBy ?? 'Warehouse Staff',
        'items': intake.items.map((e) => e.toJson()).toList(),
      };

      if (intake.notes != null && intake.notes!.isNotEmpty) {
        logPayload['manual_farm_tag'] = intake.notes;
        logPayload['notes'] = intake.notes;
      }

      try {
        await _client.from('slaughter_logs').insert(logPayload);
      } catch (e) {
        debugPrint('Intake Log Insert Warning: $e');
        // Fallback: insert minimal payload matching schema
        await _client.from('slaughter_logs').insert({
          'id': intake.id,
          'branch_code': branchCode,
          'tag_number': intake.intakeNumber,
          'type': intake.supplierName,
          'initial_weight': intake.totalQuantity,
          'status': 'completed',
        });
      }

      // 2. Add Batches & Update Warehouse Quantities
      for (final item in intake.items) {
        try {
          await addWarehouseBatch(
            WarehouseBatch(
              id: UuidUtils.generate(),
              batchNumber: item.batchNumber,
              productName: item.productName,
              category: item.category,
              quantity: item.quantityReceived,
              expiryDate: item.expiryDate,
              status: BatchStatus.shelfReady,
              shelfLocation: item.warehouseLocation,
              source: BatchSource(name: intake.supplierName, location: item.warehouseLocation ?? 'Main HQ', owner: 'Adom Mmoroso ENT.'),
              createdAt: intake.date,
            ),
            branchCode,
          );
        } catch (e) {
          debugPrint('Batch Insert Warning: $e');
        }

        // Atomic update of warehouse quantity
        try {
          final current = await _client.from('products').select('warehouse_quantity').eq('id', item.productId).maybeSingle();
          final existingVal = (current?['warehouse_quantity'] as num? ?? 0).toDouble();
          await _client.from('products').update({
            'warehouse_quantity': existingVal + item.quantityReceived,
            'last_stock_update': DateTime.now().toIso8601String(),
          }).eq('id', item.productId);
        } catch (e) {
          debugPrint('Warning: error updating warehouse_quantity on products ($e)');
        }
      }

      // 3. Automated Customer Restock SMS Alert Checker
      try {
        final restockService = SupabaseRestockRequestService();
        await restockService.checkAndNotifyRestockedProducts(intake, branchCode ?? '', null);
      } catch (e) {
        debugPrint('Restock Notification Checker Warning: $e');
      }
    } catch (e) {
      debugPrint('Error confirming intake: $e');
      rethrow;
    }
  }

  Future<void> updateIntake(WarehouseIntakeRecord intake) async {
    try {
      final Map<String, dynamic> updatePayload = {
        'tag_number': intake.intakeNumber,
        'type': intake.supplierName,
        'source_farm': intake.supplierName,
        'slaughter_time': intake.date.toIso8601String(),
      };
      if (intake.notes != null) {
        updatePayload['manual_farm_tag'] = intake.notes;
      }

      await _client
          .from('slaughter_logs')
          .update(updatePayload)
          .or('id.eq.${intake.id},tag_number.eq.${intake.intakeNumber}');
    } catch (e) {
      debugPrint('Error updating intake record: $e');
    }
  }

  Future<void> deleteIntake(WarehouseIntakeRecord intake) async {
    try {
      await _client
          .from('slaughter_logs')
          .delete()
          .or('id.eq.${intake.id},tag_number.eq.${intake.intakeNumber}');

      for (final item in intake.items) {
        try {
          await _client.from('meat_batches').delete().eq('batch_number', item.batchNumber);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error deleting intake record: $e');
    }
  }

  Future<void> deleteBatch(String batchId) async {
    try {
      await _client.from('meat_batches').delete().eq('id', batchId);
    } catch (e) {
      debugPrint('Error deleting batch: $e');
    }
  }

  Future<void> deleteBatchesByNumber(String batchNumber) async {
    try {
      await _client.from('meat_batches').delete().eq('batch_number', batchNumber);
    } catch (e) {
      debugPrint('Error deleting batches by number: $e');
    }
  }

  Stream<List<WarehouseDispatchRecord>> watchDispatches(String branchCode) {
    try {
      return _client
          .from('warehouse_dispatches')
          .stream(primaryKey: ['id'])
          .map((data) => data.map((json) {
                final map = Map<String, dynamic>.from(json);
                return WarehouseDispatchRecord.fromJson(map);
              }).toList())
          .handleError((e, st) {
            debugPrint('Supabase watchDispatches Stream Warning: $e');
            return <WarehouseDispatchRecord>[];
          });
    } catch (e) {
      debugPrint('Error watching dispatches: $e');
      return Stream.value([]);
    }
  }

  Future<void> confirmDispatch(WarehouseDispatchRecord dispatch, [String? branchCode]) async {
    try {
      // 1. Record Dispatch Transaction in warehouse_dispatches
      try {
        await _client.from('warehouse_dispatches').upsert({
          'id': dispatch.id,
          'dispatch_number': dispatch.dispatchNumber,
          'source_location': 'Main HQ Warehouse',
          'destination_store': dispatch.destinationStore,
          'items': dispatch.items.map((i) => i.toJson()).toList(),
          'notes': dispatch.notes,
          'dispatched_by': dispatch.dispatchedBy,
          'is_confirmed': true,
          'date': dispatch.date.toIso8601String(),
        });
      } catch (e) {
        debugPrint('Warehouse dispatch record upsert warning: $e');
      }

      // 2. Deduct from Warehouse Stock & Increase Store Stock
      for (final item in dispatch.items) {
        double currentStore = 0.0;
        double currentWarehouse = 0.0;
        double currentDailyAdded = 0.0;

        try {
          final current = await _client.from('products').select('stock_quantity, warehouse_quantity, daily_stock_added').eq('id', item.productId).maybeSingle();
          currentStore = (current?['stock_quantity'] as num? ?? 0).toDouble();
          currentWarehouse = (current?['warehouse_quantity'] as num? ?? 0).toDouble();
          currentDailyAdded = (current?['daily_stock_added'] as num? ?? 0).toDouble();
        } catch (_) {
          try {
            final current = await _client.from('products').select('stock_quantity').eq('id', item.productId).maybeSingle();
            currentStore = (current?['stock_quantity'] as num? ?? 0).toDouble();
          } catch (e) {
            debugPrint('Warning fetching product stock: $e');
          }
        }

        final newWarehouse = (currentWarehouse - item.quantityDispatched).clamp(0.0, double.infinity);
        final newStore = currentStore + item.quantityDispatched;
        final newDailyAdded = currentDailyAdded + item.quantityDispatched;

        try {
          await _client.from('products').update({
            'warehouse_quantity': newWarehouse,
            'stock_quantity': newStore,
            'daily_stock_added': newDailyAdded,
            'last_stock_update': DateTime.now().toIso8601String(),
          }).eq('id', item.productId);
        } catch (e) {
          debugPrint('Fallback updating stock (warehouse_quantity missing): $e');
          try {
            await _client.from('products').update({
              'stock_quantity': newStore,
              'daily_stock_added': newDailyAdded,
              'last_stock_update': DateTime.now().toIso8601String(),
            }).eq('id', item.productId);
          } catch (err) {
            debugPrint('Error updating store stock: $err');
          }
        }
      }
    } catch (e) {
      debugPrint('Error confirming dispatch: $e');
      rethrow;
    }
  }
}

final supabaseWarehouseServiceProvider = Provider<SupabaseWarehouseService>((ref) {
  return SupabaseWarehouseService();
});

// Alias for legacy compatibility
typedef SupabaseButcherService = SupabaseWarehouseService;
final supabaseButcherServiceProvider = supabaseWarehouseServiceProvider;
