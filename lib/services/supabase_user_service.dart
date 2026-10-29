import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../core/supabase_config.dart';

class SupabaseUserService {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<UserAccount>> getUsers() async {
    final response = await _client
        .from('users')
        .select()
        .eq('is_deleted', false);
    
    return (response as List).map((json) => UserAccount.fromJson(json)).toList();
  }

  Future<void> addUser(UserAccount account) async {
    final data = account.toJson();
    data['is_deleted'] = false; // Always ensure new/upserted accounts are active
    try {
      await _client.from('users').upsert(data, onConflict: 'email');
    } catch (e) {
      if (e.toString().contains('PGRST204') || e.toString().contains('column')) {
        debugPrint('SupabaseUserService addUser column error fallback: $e');
        final cleanData = _cleanUserDataForDb(data);
        await _client.from('users').upsert(cleanData, onConflict: 'email');
      } else {
        rethrow;
      }
    }
  }

  Future<void> updateUser(UserAccount account) async {
    final data = account.toJson();
    try {
      await _client
          .from('users')
          .update(data)
          .eq('id', account.id);
    } catch (e) {
      if (e.toString().contains('PGRST204') || e.toString().contains('column') || e.toString().contains('is_passcode_enabled')) {
        debugPrint('SupabaseUserService updateUser column error fallback: $e');
        final cleanData = _cleanUserDataForDb(data);
        await _client
            .from('users')
            .update(cleanData)
            .eq('id', account.id);
      } else {
        rethrow;
      }
    }
  }

  Map<String, dynamic> _cleanUserDataForDb(Map<String, dynamic> data) {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('enabled_permissions');
    cleanData.remove('newly_added_permissions');
    cleanData.remove('secondary_roles');
    cleanData.remove('temporary_role');
    cleanData.remove('temp_role_start');
    cleanData.remove('temp_role_end');
    cleanData.remove('salary_amount');
    cleanData.remove('salary_day');
    cleanData.remove('last_salary_date');
    cleanData.remove('last_payment_was_advance');
    cleanData.remove('passcode_sent_at');
    cleanData.remove('theme_mode');
    cleanData.remove('theme_primary_color');
    cleanData.remove('total_salary_paid');
    cleanData.remove('total_advances_taken');
    cleanData.remove('shop_location');
    cleanData.remove('last_seen');
    cleanData.remove('is_passcode_enabled');
    return cleanData;
  }

  Future<void> updateUserFields(String userId, Map<String, dynamic> fields) async {
    await _client
        .from('users')
        .update(fields)
        .eq('id', userId);
  }

  Future<void> deleteUser(String id) async {
    await _client
        .from('users')
        .update({
          'is_deleted': true,
          'status': 'suspended',
        })
        .eq('id', id);
  }

  Future<void> hardDeleteUser(String id) async {
    // 1. Delete from public.users first
    await _client
        .from('users')
        .delete()
        .eq('id', id);

    // 2. If successful, delete from Auth too
    try {
      await SupabaseConfig.adminClient.auth.admin.deleteUser(id);
    } catch (e) {
      debugPrint('SupabaseUserService: Auth cleanup failed (possibly already deleted or insufficient permissions): $e');
    }
  }

  Future<UserAccount?> getUserById(String id) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', id)
          .single();
      return UserAccount.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<UserAccount?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('users')
        .select()
        .eq('id', user.id)
        .single();
    
    return UserAccount.fromJson(response);
  }

  Future<bool> checkPhoneExists(String phone) async {
    final response = await _client
        .from('users')
        .select('phone')
        .eq('phone', phone)
        .limit(1)
        .maybeSingle();
    
    return response != null;
  }

  Future<String?> uploadProfilePicture(String userId, Uint8List bytes) async {
    try {
      // Use a unique name including timestamp to avoid caching issues
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_$timestamp.jpg';
      final path = 'profiles/$fileName';
      
      // Optional: Delete old profile pictures to keep storage clean
      try {
        final List<FileObject> existingFiles = await _client.storage.from('user-profiles').list(path: 'profiles');
        final List<String> userFiles = existingFiles
            .where((f) => f.name.startsWith(userId))
            .map((f) => 'profiles/${f.name}')
            .toList();
        
        if (userFiles.isNotEmpty) {
          await _client.storage.from('user-profiles').remove(userFiles);
        }
      } catch (e) {
        debugPrint('Cleanup old profiles error (non-critical): $e');
      }

      await _client.storage.from('user-profiles').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      return _client.storage.from('user-profiles').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }

  Stream<UserAccount?> streamUser(String id) {
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((data) => data.isEmpty ? null : UserAccount.fromJson(data.first));
  }

  Stream<List<UserAccount>> watchUsers() {
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((json) => UserAccount.fromJson(json)).where((u) => !u.isDeleted).toList());
  }
}
