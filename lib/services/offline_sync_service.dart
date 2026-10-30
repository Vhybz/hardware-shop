import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'laravel_api_service.dart';
import '../core/uuid_utils.dart';

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
  static StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;
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

  static Future<Box> _openSecureBox(String boxName, List<int> key) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box(boxName);
      }
      if (kIsWeb) {
        return await Hive.openBox(boxName);
      }
      return await Hive.openBox(boxName,
          encryptionCipher: HiveAesCipher(key));
    } catch (e) {
      debugPrint('Hive Box Error ($boxName): $e. Wiping local cache...');
      try {
        await Hive.deleteBoxFromDisk(boxName);
      } catch (_) {}
      try {
        return await Hive.openBox(boxName);
      } catch (_) {
        return await Hive.openBox('${boxName}_clean');
      }
    }
  }

  static Future<void> initialize() async {
    await Hive.initFlutter();
    final encryptionKey = _getOrCreateEncryptionKey();

    await _openSecureBox(queueBoxName, encryptionKey);
    await _openSecureBox(productsBoxName, encryptionKey);
    await _openSecureBox(customersBoxName, encryptionKey);
    await _openSecureBox(salesBoxName, encryptionKey);
    await _openSecureBox(notificationsBoxName, encryptionKey);
    await _openSecureBox(expensesBoxName, encryptionKey);
    await _openSecureBox(transfersBoxName, encryptionKey);
    await _openSecureBox(butcherBoxName, encryptionKey);
    await _openSecureBox(auditBoxName, encryptionKey);
    await _openSecureBox(settingsBoxName, encryptionKey);
    await _openSecureBox(branchesBoxName, encryptionKey);

    _listenToConnectivity();
    unawaited(processQueue());
  }

  static void _listenToConnectivity() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final bool isOnline =
            results.any((result) => result != ConnectivityResult.none);
        if (isOnline) {
          processQueue();
        }
      },
    );
  }

  static int getPendingCount() {
    try {
      if (Hive.isBoxOpen(queueBoxName)) {
        return Hive.box(queueBoxName).length;
      }
    } catch (_) {}
    return 0;
  }

  static Future<void> clearAllCache() async {
    try {
      final boxes = [
        queueBoxName,
        productsBoxName,
        customersBoxName,
        salesBoxName,
        notificationsBoxName,
        expensesBoxName,
        transfersBoxName,
        butcherBoxName,
        auditBoxName,
        branchesBoxName,
      ];
      for (final name in boxes) {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).clear();
        }
      }
    } catch (e) {
      debugPrint('clearAllCache error: $e');
    }
  }

  static Future<void> addToQueue(
    String actionType, [
    Map<String, dynamic>? payloadPositional,
    Map<String, dynamic>? data,
  ]) async {
    final payload = payloadPositional ?? data ?? {};
    try {
      if (!Hive.isBoxOpen(queueBoxName)) return;
      final box = Hive.box(queueBoxName);
      final String requestId =
          payload['id']?.toString() ?? UuidUtils.generate();

      final queueItem = {
        'id': requestId,
        'type': actionType,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await box.put(requestId, queueItem);
      processQueue();
    } catch (e) {
      debugPrint('addToQueue error: $e');
    }
  }

  static Future<void> processQueue() async {
    if (_isProcessing || isForcedOffline) return;

    final results = await Connectivity().checkConnectivity();
    if (results.every((result) => result == ConnectivityResult.none)) return;

    _isProcessing = true;

    try {
      if (Hive.isBoxOpen(queueBoxName)) {
        final box = Hive.box(queueBoxName);
        if (box.isNotEmpty) {
          final List<dynamic> keys = List.from(box.keys);
          final List<Map<String, dynamic>> batchPayloads = [];

          for (final key in keys) {
            final item = box.get(key);
            if (item == null) continue;
            batchPayloads.add(Map<String, dynamic>.from(item));
          }

          if (batchPayloads.isNotEmpty) {
            final success = await LaravelApiService.processBatchSync(batchPayloads);
            if (success) {
              await box.clear();
            }
          }
        }
      }

      await syncAllLocalDataToCloud();
    } catch (e) {
      debugPrint('processQueue error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  static Future<int> syncAllLocalDataToCloud() async {
    final List<Map<String, dynamic>> batchPayloads = [];

    // 1. Local Users
    try {
      if (Hive.isBoxOpen(settingsBoxName)) {
        final box = Hive.box(settingsBoxName);
        final rawUsers = box.get('users_cache');
        if (rawUsers != null && rawUsers is List) {
          for (final u in rawUsers) {
            final map = Map<String, dynamic>.from(u);
            if (map['email'] != null) {
              batchPayloads.add({'type': 'USER', 'payload': map});
            }
          }
        }
      }
    } catch (_) {}

    // 2. Local Sales
    try {
      if (Hive.isBoxOpen(salesBoxName)) {
        final box = Hive.box(salesBoxName);
        for (final s in box.values) {
          final map = Map<String, dynamic>.from(s);
          if (map['id'] != null) {
            batchPayloads.add({'type': 'SALE', 'payload': map});
          }
        }
      }
    } catch (_) {}

    // 3. Local Products
    try {
      if (Hive.isBoxOpen(productsBoxName)) {
        final box = Hive.box(productsBoxName);
        for (final p in box.values) {
          final map = Map<String, dynamic>.from(p);
          if (map['id'] != null) {
            batchPayloads.add({'type': 'UPDATE_PRODUCT', 'payload': map});
          }
        }
      }
    } catch (_) {}

    // 4. Local Customers
    try {
      if (Hive.isBoxOpen(customersBoxName)) {
        final box = Hive.box(customersBoxName);
        for (final c in box.values) {
          final map = Map<String, dynamic>.from(c);
          if (map['id'] != null) {
            batchPayloads.add({'type': 'CUSTOMER', 'payload': map});
          }
        }
      }
    } catch (_) {}

    // 5. Local Expenses
    try {
      if (Hive.isBoxOpen(expensesBoxName)) {
        final box = Hive.box(expensesBoxName);
        for (final e in box.values) {
          final map = Map<String, dynamic>.from(e);
          if (map['id'] != null) {
            batchPayloads.add({'type': 'EXPENSE', 'payload': map});
          }
        }
      }
    } catch (_) {}

    if (batchPayloads.isEmpty) return 0;

    try {
      final success = await LaravelApiService.processBatchSync(batchPayloads);
      if (success) {
        debugPrint('syncAllLocalDataToCloud: ${batchPayloads.length} records pushed to Neon Cloud!');
        return batchPayloads.length;
      }
    } catch (e) {
      debugPrint('syncAllLocalDataToCloud error: $e');
    }
    return 0;
  }

  static void dispose() {
    _connectivitySubscription?.cancel();
  }
}
