import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../core/supabase_config.dart';
import '../core/uuid_utils.dart';

/// This service manages the "Offline-First" logic for City Cosmetics POS.
/// It uses Hive as a fast, schema-less storage for pending cloud actions.
class OfflineSyncService {
  static const String queueBoxName = 'sync_queue';
  static const String productsBoxName = 'products_cache';
  static const String customersBoxName = 'customers_cache';
  static const String salesBoxName = 'sales_cache';
  static const String notificationsBoxName = 'notifications_cache';
  static const String expensesBoxName = 'expenses_cache';
  static const String transfersBoxName = 'transfers_cache';
  static const String butcherBoxName = 'butcher_cache';
  static const String auditBoxName = 'audit_cache';
  static const String settingsBoxName = 'app_settings';
  static const String branchesBoxName = 'branches_cache';
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static bool _isProcessing = false;
  static bool isForcedOffline = false;

  static List<int> _getOrCreateEncryptionKey() {
    const String seed = 'CityCosmetics_AES256_Secure_Offline_Queue_Key_2026';
    final bytes = seed.codeUnits;
    final List<int> key = List<int>.filled(32, 0);
    for (int i = 0; i < 32; i++) {
      key[i] = (bytes[i % bytes.length] + i * 37) % 256;
    }
    return key;
  }

  static Future<Box<E>> _openSecureBox<E>(String boxName, List<int> key) async {
    try {
      if (kIsWeb) {
        return await Hive.openBox<E>(boxName);
      }
      return await Hive.openBox<E>(boxName, encryptionCipher: HiveAesCipher(key));
    } catch (e) {
      debugPrint('Hive Box Error ($boxName): $e. Wiping corrupted local cache and re-creating clean box...');
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {}
      try {
        return await Hive.openBox<E>(boxName);
      } catch (_) {
        return await Hive.openBox<E>('${boxName}_clean');
      }
    }
  }

  static const String _dbVersionKey = 'adom_hardware_v2026_v5';

  /// Initialize Hive and the sync monitoring
  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      final key = _getOrCreateEncryptionKey();

      await _openSecureBox(queueBoxName, key);
      await _openSecureBox(productsBoxName, key);
      await _openSecureBox(customersBoxName, key);
      await _openSecureBox(salesBoxName, key);
      await _openSecureBox(notificationsBoxName, key);
      await _openSecureBox(expensesBoxName, key);
      await _openSecureBox(transfersBoxName, key);
      await _openSecureBox(butcherBoxName, key);
      await _openSecureBox(branchesBoxName, key);
      await _openSecureBox(auditBoxName, key);
      final settingsBox = await _openSecureBox(settingsBoxName, key);

      // Auto-purge stale IndexedDB cache from legacy cosmetics database
      final String? currentVersion = settingsBox.get('db_version');
      if (currentVersion != _dbVersionKey) {
        debugPrint('Adom Hardware: Migrating web/local cache to version $_dbVersionKey...');
        await Hive.box(productsBoxName).clear();
        await Hive.box(salesBoxName).clear();
        await Hive.box(branchesBoxName).clear();
        await Hive.box(customersBoxName).clear();
        await settingsBox.put('db_version', _dbVersionKey);
      }
      
      // Listen for connectivity changes to trigger sync automatically
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          debugPrint('Connectivity Restored: Triggering background sync...');
          processQueue();
        }
      });
      
      // Initial check
      processQueue();
    } catch (e) {
      if (e.toString().contains('lock failed')) {
        debugPrint('OFFLINE ENGINE WARNING: Database is already locked by another process.');
        // We don't rethrow here so the app can still boot, though offline sync will be disabled for this session
      } else {
        rethrow;
      }
    }
  }

  /// Add a data action (Sale, Intake, Waste, etc.) to the local Hive queue.
  /// This returns immediately, allowing the UI to stay fast.
  static Future<void> addToQueue({
    required String actionType,
    required Map<String, dynamic> data,
  }) async {
    final box = Hive.box(queueBoxName);
    final String requestId = '${DateTime.now().millisecondsSinceEpoch}_$actionType';
    
    await box.put(requestId, {
      'type': actionType,
      'payload': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    debugPrint('Offline Engine: Action "$actionType" cached in Hive (ID: $requestId)');
    
    // Attempt sync immediately (will fail silently if no net)
    processQueue();
  }

  /// Processes all pending items in the Hive Box and pushes them to Supabase
  static Future<void> processQueue() async {
    if (_isProcessing || isForcedOffline) {
      if (isForcedOffline) {
        debugPrint('Sync Monitor: Forced Offline Mode Active. Queue processing paused.');
      }
      return;
    }
    
    final results = await Connectivity().checkConnectivity();
    if (results.every((result) => result == ConnectivityResult.none)) {
      debugPrint('Sync Monitor: Device is offline. Waiting for connection...');
      return;
    }

    final box = Hive.box(queueBoxName);
    if (box.isEmpty) return;

    _isProcessing = true;
    debugPrint('Sync Monitor: ${box.length} pending items found. Starting cloud push...');

    final List<dynamic> keys = List.from(box.keys);

    for (final key in keys) {
      final item = box.get(key);
      if (item == null) continue; // Safety: skip if item was deleted while loop was running

      final String type = item['type'];
      final Map<String, dynamic> payload = Map<String, dynamic>.from(item['payload']);

      try {
        bool success = false;
        debugPrint('Sync Monitor: Pushing $type action to Supabase...');
        
        switch (type) {
          case 'SALE':
            try {
              await SupabaseConfig.client.from('sales').upsert(payload);
            } catch (saleErr) {
              final errStr = saleErr.toString().toUpperCase();
              if (errStr.contains('PGRST204') || errStr.contains('COLUMN')) {
                final cleanPayload = Map<String, dynamic>.from(payload)
                  ..remove('total_cost')
                  ..remove('total_discount')
                  ..remove('applied_promo')
                  ..remove('correction_reason')
                  ..remove('bank_receipt_url')
                  ..remove('bank_receipt_id')
                  ..remove('is_verified');
                await SupabaseConfig.client.from('sales').upsert(cleanPayload);
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'ANIMAL':
            await SupabaseConfig.client.from('animals').upsert(payload);
            success = true;
            break;
          case 'INTAKE':
            await SupabaseConfig.client.from('slaughter_logs').upsert(payload);
            success = true;
            break;
          case 'UPDATE_SLAUGHTER':
            await SupabaseConfig.client.from('slaughter_logs').upsert(payload);
            success = true;
            break;
          case 'CREATE_BATCH':
            await SupabaseConfig.client.from('meat_batches').upsert(payload);
            success = true;
            break;
          case 'UPDATE_BATCH':
            await SupabaseConfig.client.from('meat_batches').upsert(payload);
            success = true;
            break;
          case 'UPDATE_PRODUCT':
            try {
              await SupabaseConfig.client.from('products').upsert(payload);
            } catch (prodErr) {
              final errStr = prodErr.toString().toUpperCase();
              if (errStr.contains('PGRST204') || errStr.contains('PROMO_END') || errStr.contains('PROMO_START') || errStr.contains('COLUMN')) {
                final cleanPayload = Map<String, dynamic>.from(payload)
                  ..remove('promo_start')
                  ..remove('promo_end')
                  ..remove('promo_target')
                  ..remove('promo_customer_target')
                  ..remove('target_customer_id');
                await SupabaseConfig.client.from('products').upsert(cleanPayload);
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'CUT':
            await SupabaseConfig.client.from('meat_cuts').upsert(payload);
            success = true;
            break;
          case 'WASTE':
            await SupabaseConfig.client.from('butcher_waste').upsert(payload);
            success = true;
            break;
          case 'EXPENSE':
            await SupabaseConfig.client.from('expenses').upsert(payload);
            success = true;
            break;
          case 'CUSTOMER':
            await SupabaseConfig.client.from('customers').upsert(payload);
            success = true;
            break;
          case 'TRANSFER':
          case 'UPDATE_TRANSFER':
            try {
              await SupabaseConfig.client.from('stock_transfers').upsert(payload);
            } catch (transferErr) {
              final errStr = transferErr.toString().toUpperCase();
              if (errStr.contains('42703') || errStr.contains('TRANSFER_TIME') || errStr.contains('COLUMN')) {
                final cleanPayload = Map<String, dynamic>.from(payload);
                if (cleanPayload.containsKey('transfer_time')) {
                  final timeVal = cleanPayload.remove('transfer_time');
                  cleanPayload['created_at'] = timeVal;
                }
                await SupabaseConfig.client.from('stock_transfers').upsert(cleanPayload);
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          case 'UPDATE_PRODUCT_STOCK':
            // Using atomic increment via RPC to handle concurrency (multiple users)
            final double change = double.tryParse(payload['change_amount'].toString()) ?? 0.0;
            await SupabaseConfig.client.rpc('increment_stock', params: {
              'p_id': payload['id'],
              'p_amount': change,
            });
            success = true;
            break;
          case 'SALE_RETURN':
            await SupabaseConfig.client.from('sale_returns').upsert(payload);
            success = true;
            break;
          case 'SUPPLIER_RETURN':
            await SupabaseConfig.client.from('supplier_returns').upsert(payload);
            success = true;
            break;
          case 'WAREHOUSE_INTAKE':
            await SupabaseConfig.client.from('slaughter_logs').upsert(payload);
            success = true;
            break;
          case 'AUDIT':
            try {
              final Map<String, dynamic> auditPayload = Map<String, dynamic>.from(payload);
              if (!UuidUtils.isValidUuid(auditPayload['id']?.toString() ?? '')) {
                auditPayload['id'] = UuidUtils.generate();
              }
              await SupabaseConfig.client.from('audit_logs').upsert(auditPayload);
            } catch (_) {
              final cleanPayload = Map<String, dynamic>.from(payload)
                ..remove('branch_code')
                ..remove('old_data');
              if (!UuidUtils.isValidUuid(cleanPayload['id']?.toString() ?? '')) {
                cleanPayload['id'] = UuidUtils.generate();
              }
              try {
                await SupabaseConfig.client.from('audit_logs').upsert(cleanPayload);
              } catch (_) {
                // Non-critical audit trail; resolve item to prevent queue blocking
              }
            }
            success = true;
            break;
          case 'NOTIFICATION':
            await SupabaseConfig.client.from('notifications').upsert(payload);
            success = true;
            break;
          case 'CUSTOMER_PAYMENT':
            await SupabaseConfig.client.from('customer_payments').upsert(payload);
            success = true;
            break;
          case 'STOCK_HISTORY':
            await SupabaseConfig.client.from('stock_history').upsert(payload);
            success = true;
            break;
          case 'DOCUMENT':
            await SupabaseConfig.client.from('documentss').upsert(payload);
            success = true;
            break;
          case 'DELETE_DOCUMENT':
            await SupabaseConfig.client.from('documentss').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_CUT':
            await SupabaseConfig.client.from('meat_cuts').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_PRODUCT':
            await SupabaseConfig.client.from('products').update({'is_deleted': true}).eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_SALE':
            await SupabaseConfig.client.from('sales').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_CUSTOMER':
            await SupabaseConfig.client.from('customers').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'DELETE_EXPENSE':
            await SupabaseConfig.client.from('expenses').delete().eq('id', payload['id']);
            success = true;
            break;
          case 'PROMOTION':
            try {
              await SupabaseConfig.client.from('products').update(payload['data']).eq('id', payload['id']);
            } catch (promoErr) {
              final errStr = promoErr.toString().toUpperCase();
              if (errStr.contains('PGRST204') || errStr.contains('COLUMN')) {
                debugPrint('Sync Monitor: Promo columns not in DB schema for $key. Resolving gracefully.');
              } else {
                rethrow;
              }
            }
            success = true;
            break;
          default:
            debugPrint('Sync Monitor: Unknown action type "$type". Removing from queue.');
            await box.delete(key);
            continue;
        }

        if (success) {
          await box.delete(key);
          debugPrint('Sync Monitor: SUCCESS! Item $key pushed to Supabase.');
        }
      } catch (e) {
        final errorStr = e.toString().toUpperCase();
        debugPrint('Sync Monitor: FAILED to push item $key. Error: $e');

        // RECONCILIATION LOGIC FOR CONCURRENCY:
        // 1. DUPLICATE KEY (23505): Another device already synced this. Success!
        if (errorStr.contains('23505') || errorStr.contains('DUPLICATE KEY') || errorStr.contains('ALREADY EXISTS')) {
          debugPrint('Sync Monitor: Resolving Conflict. Item $key already exists in DB. Removing from queue.');
          await box.delete(key);
          continue;
        }

        // 2. FOREIGN KEY VIOLATION (23503): Cannot hard delete referenced rows. Perform soft delete or remove from queue.
        if (errorStr.contains('23503') || errorStr.contains('FOREIGN KEY') || errorStr.contains('STOCK_HISTORY_PRODUCT_ID_FKEY')) {
          if (type == 'DELETE_PRODUCT') {
            try {
              debugPrint('Sync Monitor: Soft deleting product $key instead of hard delete due to FK constraint (23503).');
              await SupabaseConfig.client.from('products').update({'is_deleted': true}).eq('id', payload['id']);
            } catch (_) {}
          }
          debugPrint('Sync Monitor: Resolving Foreign Key Conflict on $key. Removing from queue to unblock.');
          await box.delete(key);
          continue;
        }

        // 3. INVALID SYNTAX (22P02): Corrupted data that will never work.
        if (errorStr.contains('22P02') || errorStr.contains('INVALID INPUT SYNTAX')) {
          debugPrint('Sync Monitor: DISCARDING corrupted item $key to unblock queue.');
          await box.delete(key);
          continue;
        }

        // 4. MISSING COLUMN / SCHEMA MISMATCH (PGRST204 / PGRST200):
        if (errorStr.contains('PGRST204') || errorStr.contains('SCHEMA CACHE') || errorStr.contains('COULD NOT FIND THE')) {
          if (type == 'AUDIT' || type == 'NOTIFICATION' || type == 'STOCK_HISTORY') {
            debugPrint('Sync Monitor: Resolving schema mismatch on non-critical $type ($key). Removing from queue.');
            await box.delete(key);
            continue;
          }
        }

        // 3. NETWORK ERROR: Keep in queue and stop the loop to save battery/data
        if (errorStr.contains('SOCKETEXCEPTION') || errorStr.contains('NETWORK_ERROR') || errorStr.contains('FAILED HOST LOOKUP')) {
          debugPrint('Sync Monitor: Offline. Pausing sync loop.');
          break;
        }
      }
    }
    
    _isProcessing = false;
  }

  /// NEW: Retrieve pending actions of a specific type from the queue.
  /// This allows UI Notifiers to merge "not yet synced" data into their lists
  /// so that information doesn't "vanish" on refresh.
  static List<Map<String, dynamic>> getPendingItems(String actionType) {
    if (!Hive.isBoxOpen(queueBoxName)) return [];
    
    final box = Hive.box(queueBoxName);
    return box.values
        .where((item) => item['type'] == actionType)
        .map((item) => Map<String, dynamic>.from(item['payload']))
        .toList();
  }

  /// Returns total number of pending cloud sync actions in the queue.
  static int getPendingCount() {
    try {
      if (!Hive.isBoxOpen(queueBoxName)) return 0;
      return Hive.box(queueBoxName).length;
    } catch (_) {
      return 0;
    }
  }

  static bool get isProcessing => _isProcessing;

  static void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Clears all local cached data. Use with caution.
  static Future<void> clearAllCache() async {
    await Hive.box(productsBoxName).clear();
    await Hive.box(customersBoxName).clear();
    await Hive.box(salesBoxName).clear();
    await Hive.box(notificationsBoxName).clear();
    await Hive.box(expensesBoxName).clear();
    await Hive.box(transfersBoxName).clear();
    await Hive.box(butcherBoxName).clear();
    // settingsBoxName is usually kept to preserve theme
  }
}
