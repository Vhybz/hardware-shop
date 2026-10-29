import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';

class OfflineAuthVault {
  static const String _authVaultBoxName = 'offline_auth_vault_box';
  static const String _salt = 'citypos_secure_salt_2026_ghana';

  /// Hash password with salted SHA-256 for secure local storage
  static String _hashCredentials(String email, String password) {
    final bytes = utf8.encode('$email:$_salt:$password');
    return sha256.convert(bytes).toString();
  }

  /// Saves user profile and encrypted password hash on successful online login
  static Future<void> saveUserCredentialsOnline(
    UserAccount user,
    String email,
    String password,
  ) async {
    try {
      final box = await Hive.openBox(_authVaultBoxName);
      final String credHash = _hashCredentials(email.trim().toLowerCase(), password);

      final Map<String, dynamic> vaultPayload = {
        'user_json': user.toJson(),
        'cred_hash': credHash,
        'email': email.trim().toLowerCase(),
        'saved_at': DateTime.now().toIso8601String(),
      };

      await box.put(email.trim().toLowerCase(), vaultPayload);
      await box.put('last_signed_in_user', vaultPayload);
      debugPrint('Offline Auth Vault: Credentials securely cached for ${email.trim()}');
    } catch (e) {
      debugPrint('Offline Auth Vault Save Error: $e');
    }
  }

  /// Attempts offline authentication against local device vault
  static Future<UserAccount?> attemptOfflineLogin(
    String email,
    String password,
  ) async {
    try {
      final box = await Hive.openBox(_authVaultBoxName);
      final String cleanEmail = email.trim().toLowerCase();
      final Map<dynamic, dynamic>? payload = box.get(cleanEmail) ?? box.get('last_signed_in_user');

      if (payload == null) return null;

      final Map<String, dynamic> data = Map<String, dynamic>.from(payload);
      final String expectedHash = data['cred_hash'] ?? '';
      final String enteredHash = _hashCredentials(cleanEmail, password);

      if (enteredHash == expectedHash) {
        final Map<String, dynamic> userJson = Map<String, dynamic>.from(data['user_json']);
        final user = UserAccount.fromJson(userJson);

        // Verify account is approved and not suspended
        if (user.status == AccountStatus.approved) {
          debugPrint('Offline Auth Vault: Successful offline authentication for ${user.email}');
          return user;
        }
      }
    } catch (e) {
      debugPrint('Offline Auth Vault Attempt Error: $e');
    }
    return null;
  }

  /// Attempts offline login using 4-digit staff passcode PIN
  static Future<UserAccount?> attemptOfflinePasscodeLogin(String passcode) async {
    try {
      final box = await Hive.openBox(_authVaultBoxName);
      for (final key in box.keys) {
        if (key == 'last_signed_in_user') continue;
        final raw = box.get(key);
        if (raw != null) {
          final data = Map<String, dynamic>.from(raw);
          final userJson = Map<String, dynamic>.from(data['user_json']);
          final user = UserAccount.fromJson(userJson);
          if (user.passcode == passcode.trim() && user.status == AccountStatus.approved) {
            return user;
          }
        }
      }
    } catch (e) {
      debugPrint('Offline Passcode Auth Error: $e');
    }
    return null;
  }

  /// Retrieves the last signed-in user profile from local vault for offline startup
  static Future<UserAccount?> getLastSavedUserProfile() async {
    try {
      final box = await Hive.openBox(_authVaultBoxName);
      final raw = box.get('last_signed_in_user');
      if (raw != null) {
        final data = Map<String, dynamic>.from(raw);
        final userJson = Map<String, dynamic>.from(data['user_json']);
        final user = UserAccount.fromJson(userJson);
        if (user.status == AccountStatus.approved) {
          debugPrint('Offline Auth Vault: Retrieved last saved profile for ${user.firstName} (${user.email})');
          return user;
        }
      }
    } catch (e) {
      debugPrint('Offline Auth Vault Get Last Saved Profile Error: $e');
    }
    return null;
  }
}
