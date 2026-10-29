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

  static Future<Box<E>> _openSecureBox<E>(String boxName, List<int> key) async {
    try {
      if (kIsWeb) {
        return await Hive.openBox<E>(boxName);
      }
      return await Hive.openBox<E>(boxName,
          encryptionCipher: HiveAesCipher(key));
    } catch (e) {
      debugPrint('Hive Box Error ($boxName): $e. Wiping local cache...');
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

  static Future<void> initialize() async {
    await Hive.initFlutter();
    final encryptionKey = _getOrCreateEncryptionKey();

    await _openSecureBox<Map>(queueBoxName, encryptionKey);
    await _openSecureBox<Map>(productsBoxName, encryptionKey);
    await _openSecureBox<Map>(customersBoxName, encryptionKey);
    await _openSecureBox<Map>(salesBoxName, encryptionKey);
    await _openSecureBox<Map>(notificationsBoxName, encryptionKey);
    await _openSecureBox<Map>(expensesBoxName, encryptionKey);
    await _openSecureBox<Map>(transfersBoxName, encryptionKey);
    await _openSecureBox<Map>(butcherBoxName, encryptionKey);
    await _openSecureBox<Map>(auditBoxName, encryptionKey);
    await _openSecureBox<dynamic>(settingsBoxName, encryptionKey);
    await _openSecureBox<Map>(branchesBoxName, encryptionKey);

    _listenToConnectivity();
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

    if (!Hive.isBoxOpen(queueBoxName)) return;
    final box = Hive.box(queueBoxName);
    if (box.isEmpty) return;

    _isProcessing = true;
    final List<dynamic> keys = List.from(box.keys);
    final List<Map<String, dynamic>> batchPayloads = [];

    for (final key in keys) {
      final item = box.get(key);
      if (item == null) continue;
      batchPayloads.add(Map<String, dynamic>.from(item));
    }

    try {
      if (batchPayloads.isNotEmpty) {
        final success = await LaravelApiService.processBatchSync(batchPayloads);
        if (success) {
          await box.clear();
        }
      }
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
  }

  static void dispose() {
    _connectivitySubscription?.cancel();
  }
}
