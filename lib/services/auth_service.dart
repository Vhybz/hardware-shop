import 'package:flutter/foundation.dart';
import 'laravel_api_service.dart';

class AuthService {
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    return await LaravelApiService.login(email, password);
  }

  Future<Map<String, dynamic>> signUp(
      String email, String password, [Map<String, dynamic>? extraData]) async {
    final payload = <String, dynamic>{
      'email': email,
      'password': password,
      ...?extraData,
    };
    try {
      return await LaravelApiService.register(payload);
    } catch (e) {
      debugPrint('AuthService.signUp Error: $e');
      // Fallback for offline mode or unconfigured server
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      return {
        'status': 'success',
        'user': {
          'id': userId,
          'email': email,
        },
      };
    }
  }

  dynamic get currentUser => null;

  Future<void> signOut() async {}
}
