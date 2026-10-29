import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/branch_model.dart';
import '../core/supabase_config.dart';
import 'offline_sync_service.dart';
import 'supabase_product_service.dart';

class SupabaseBranchService {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<Branch>> getBranches() async {
    try {
      final response = await _client
          .from('branches')
          .select()
          .order('name', ascending: true);
      
      final branches = (response as List).map((json) => Branch.fromJson(json)).toList();
      _saveToCache(branches);
      return branches;
    } catch (e) {
      debugPrint('SupabaseBranchService getBranches error (offline fallback): $e');
      return _loadFromCache();
    }
  }

  void _saveToCache(List<Branch> branches) {
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
          debugPrint('Branch Service: ${cached.length} branches loaded from local cache.');
          return cached;
        }
      }
    } catch (e) {
      debugPrint('Branch Cache Load Error: $e');
    }
    return [];
  }

  Future<void> createBranch(Branch branch) async {
    try {
      await _client.from('branches').insert(branch.toJson());
      try {
        final productService = SupabaseProductService();
        await productService.initializeNewBranchProducts(branch.code);
      } catch (e) {
        debugPrint('Warning initializing branch product catalog: $e');
      }
    } catch (e) {
      debugPrint('Error creating branch: $e');
      rethrow;
    }
  }

  Future<Branch?> getBranchByCode(String code) async {
    try {
      final response = await _client
          .from('branches')
          .select()
          .eq('code', code)
          .single();
      return Branch.fromJson(response);
    } catch (e) {
      // Offline fallback lookup
      final cached = _loadFromCache();
      return cached.where((b) => b.code == code).firstOrNull;
    }
  }

  Future<void> updateBranchAdmin(String code, String adminId) async {
    try {
      await _client
          .from('branches')
          .update({'admin_id': adminId})
          .eq('code', code);
    } catch (e) {
      debugPrint('Error updating branch admin: $e');
    }
  }
}
