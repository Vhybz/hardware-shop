import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/branch_model.dart';
import 'offline_sync_service.dart';
import 'laravel_api_service.dart';

class BranchService {
  Future<List<Branch>> getBranches() async {
    final cached = _loadFromCache();
    fetchRemoteBranches();
    return cached;
  }

  Future<void> fetchRemoteBranches() async {
    try {
      final remoteList = await LaravelApiService.fetchBranches();
      if (remoteList.isNotEmpty) {
        final List<Branch> remoteBranches = remoteList
            .map((b) => Branch.fromJson(Map<String, dynamic>.from(b)))
            .toList();
        saveToCache(remoteBranches);
      }
    } catch (e) {
      debugPrint('BranchService fetchRemoteBranches error: $e');
    }
  }

  void saveToCache(List<Branch> branches) {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.branchesBoxName)) {
        final box = Hive.box(OfflineSyncService.branchesBoxName);
        box.clear();
        for (final b in branches) {
          box.put(b.code, b.toJson());
        }
      }
    } catch (e) {
      debugPrint('Branch Cache Save Error: $e');
    }
  }

  List<Branch> _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.branchesBoxName)) {
        final box = Hive.box(OfflineSyncService.branchesBoxName);
        if (box.isNotEmpty) {
          final cached = box.values
              .map((json) => Branch.fromJson(Map<String, dynamic>.from(json)))
              .toList();
          return cached;
        }
      }
    } catch (e) {
      debugPrint('Branch Cache Load Error: $e');
    }
    return [
      Branch(
        code: 'MAIN',
        name: 'Main Hardware Branch',
        location: 'Zongo One Way, Sunyani',
      ),
    ];
  }

  Future<void> createBranch(Branch branch) async {
    final cached = _loadFromCache();
    cached.add(branch);
    saveToCache(cached);
    unawaited(LaravelApiService.submitBranch(branch.toJson()));
    await OfflineSyncService.addToQueue('BRANCH', branch.toJson());
  }

  Future<Branch?> getBranchByCode(String code) async {
    final cached = _loadFromCache();
    return cached.where((b) => b.code == code).firstOrNull;
  }

  Future<void> updateBranchAdmin(String code, String adminId) async {
    // Local state update
  }
}
