import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'offline_sync_service.dart';
import 'offline_auth_vault.dart';
import 'laravel_api_service.dart';
import '../models/user_model.dart';

class DummyUserService {
  Future<UserAccount?> fetchUserById(String id) async => null;
  Future<List<UserAccount>> getUsers([String? branchCode]) async => [];
}

class UserNotifier extends StateNotifier<List<UserAccount>> {
  final Ref ref;
  final service = DummyUserService();

  UserNotifier(this.ref) : super([]) {
    _init();
  }

  void _init() {
    _loadFromCache();
  }

  Future<void> loadUsers({bool? silent}) async {
    _loadFromCache();
    await fetchRemoteUsers();
  }

  Future<void> fetchRemoteUsers() async {
    try {
      final remoteList = await LaravelApiService.fetchUsers();
      if (remoteList.isNotEmpty) {
        final List<UserAccount> remoteUsers = remoteList
            .map((u) => UserAccount.fromJson(Map<String, dynamic>.from(u)))
            .toList();

        final Map<String, UserAccount> userMap = {};
        for (final u in state) {
          userMap[u.id] = u;
        }
        for (final u in remoteUsers) {
          userMap[u.id] = u;
        }

        state = userMap.values.toList();
        _saveToCache();
      }
    } catch (e) {
      debugPrint('UserNotifier fetchRemoteUsers error: $e');
    }
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.settingsBoxName)) {
        final box = Hive.box(OfflineSyncService.settingsBoxName);
        final rawUsers = box.get('users_cache');
        if (rawUsers != null && rawUsers is List) {
          final users = rawUsers
              .map((u) => UserAccount.fromJson(Map<String, dynamic>.from(u)))
              .toList();
          state = users;
        }
      }
    } catch (e) {
      debugPrint('UserNotifier _loadFromCache error: $e');
    }
  }

  void _saveToCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.settingsBoxName)) {
        final box = Hive.box(OfflineSyncService.settingsBoxName);
        final rawUsers = state.map((u) => u.toJson()).toList();
        box.put('users_cache', rawUsers);
      }
    } catch (e) {
      debugPrint('UserNotifier _saveToCache error: $e');
    }
  }

  Future<void> updateUserFields(
      String userId, Map<String, dynamic> fields) async {
    UserAccount? updatedUser;
    state = state.map((u) {
      if (u.id == userId) {
        updatedUser = UserAccount.fromJson({...u.toJson(), ...fields});
        final sessionUser = ref.read(sessionUserProfileProvider);
        if (sessionUser?.id == userId) {
          ref.read(sessionUserProfileProvider.notifier).state = updatedUser;
        }
        return updatedUser!;
      }
      return u;
    }).toList();
    _saveToCache();

    if (updatedUser != null) {
      unawaited(OfflineSyncService.addToQueue('USER', updatedUser!.toJson()));
    }
  }

  Future<void> approveUser(String id) async {
    await updateUserFields(id, {'status': 'approved'});
  }

  Future<void> suspendUser(String id) async {
    await updateUserFields(id, {'status': 'suspended'});
  }

  Future<void> activateUser(String id) async {
    await updateUserFields(id, {'status': 'approved'});
  }

  Future<void> clearTemporaryPromotion(String id) async {}

  Future<void> deleteUser(String id) async {
    final userToDelete = state.where((u) => u.id == id).firstOrNull;
    if (userToDelete != null) {
      await OfflineAuthVault.deleteAccount(userToDelete.email);
    }
    state = state.where((u) => u.id != id).toList();
    _saveToCache();
  }

  Future<void> promoteTemporarily(
      String id, dynamic role, DateTime duration, [dynamic extra]) async {}

  Future<void> updatePasscode(String id, String code,
      {bool? lockAfterUpdate}) async {
    await updateUserFields(id, {'passcode': code, 'is_passcode_enabled': true});
  }

  Future<void> setPasscodeEnabled(String id, bool enabled,
      {bool? lockAfterUpdate}) async {
    await updateUserFields(id, {'is_passcode_enabled': enabled});
  }

  Future<void> addAccount(UserAccount user) async {
    state = [...state, user];
    _saveToCache();
  }

  Future<void> updateRoles(String id, {dynamic primaryRole}) async {
    if (primaryRole != null) {
      final roleStr = primaryRole is String ? primaryRole : primaryRole.toString();
      await updateUserFields(id, {'role': roleStr});
    }
  }

  Future<void> setPermissions(String id, dynamic permissions) async {
    List<String> list = [];
    if (permissions is Iterable) {
      list = permissions.map((e) => e.toString()).toList();
    }
    await updateUserFields(id, {'enabled_permissions': list});
  }

  Future<void> updateSalary(String id,
      {double? amount,
      int? day,
      dynamic addSalaryPaid,
      dynamic addAdvanceTaken,
      dynamic isAdvance,
      DateTime? lastPaid}) async {
    if (amount != null) {
      await updateUserFields(id, {'base_salary': amount});
    }
  }

  Future<String?> uploadExternalPhoto(String id, Uint8List bytes) async {
    try {
      final base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
      await updateUserFields(id, {'photo_url': base64Image});
      return base64Image;
    } catch (e) {
      debugPrint('UserNotifier uploadExternalPhoto error: $e');
      return null;
    }
  }

  Future<String?> updatePhoto(String id, Uint8List bytes) async {
    try {
      final base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
      await updateUserFields(id, {'photo_url': base64Image});
      return base64Image;
    } catch (e) {
      debugPrint('UserNotifier updatePhoto error: $e');
      return null;
    }
  }

  Future<void> updateProfile({
    String? userId,
    String? firstName,
    String? surname,
    String? phone,
    String? gender,
    DateTime? dob,
  }) async {
    if (userId == null) return;
    final fields = <String, dynamic>{};
    if (firstName != null) fields['first_name'] = firstName;
    if (surname != null) fields['surname'] = surname;
    if (phone != null) fields['phone'] = phone;
    await updateUserFields(userId, fields);
  }

  Future<UserAccount?> fetchUserById(String id) async {
    return state.where((u) => u.id == id).firstOrNull;
  }

  Future<bool> checkPhoneExists(String phone, {bool? silent}) async {
    return state.any((u) => u.phone == phone);
  }

  Future<bool> checkIfAnyAdminExists({bool? silent}) async {
    return state.any((u) => u.role == UserRole.superAdmin || u.role == UserRole.admin);
  }

  Future<void> updateTheme(String userId, [dynamic param1, dynamic param2]) async {}

  Future<void> markPermissionAsSeen(String id, String route) async {}
}

final currentUserIdProvider = StateProvider<String?>((ref) => null);

final sessionUserProfileProvider = StateProvider<UserAccount?>((ref) => null);

final passcodeUnlockedProvider = StateProvider<bool>((ref) => false);

final systemLockdownProvider = StateProvider<bool>((ref) => false);

final currentUserStreamProvider = StreamProvider<UserAccount?>((ref) {
  return const Stream.empty();
});

final currentUserProvider = Provider<UserAccount?>((ref) {
  final sessionUser = ref.watch(sessionUserProfileProvider);
  if (sessionUser != null) return sessionUser;

  final currentId = ref.watch(currentUserIdProvider);
  if (currentId != null) {
    try {
      return ref.watch(userProvider).firstWhere((u) => u.id == currentId);
    } catch (_) {}
  }

  return UserAccount(
    id: 'ADMIN-001',
    email: 'admin@adomhardware.com',
    firstName: 'Clifford',
    surname: 'Kyere-Adom',
    role: UserRole.admin,
    branchCode: 'MAIN',
  );
});

final userProvider =
    StateNotifierProvider<UserNotifier, List<UserAccount>>((ref) {
  return UserNotifier(ref);
});

final userLoadingProvider = StateProvider<bool>((ref) => false);

final liveHeartbeatProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 3), (count) => count);
});
