import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static late SupabaseClient _adminClient;
  static late SupabaseClient _publicClient;
  static bool _isInitialized = false;

  static const String activeSupabaseUrl = 'https://kzlvzcfagsdivoyvolzv.supabase.co';
  static const String activeSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6bHZ6Y2ZhZ3NkaXZveXZvbHp2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI1ODU1MTQsImV4cCI6MjEwODE2MTUxNH0.4SkQCODwDrKi9Sb4IbTbKthMgh63k4g8vKR3gPJOV-c';

  static SupabaseClient get adminClient {
    if (!_isInitialized) throw Exception('SupabaseConfig not initialized.');
    return _adminClient;
  }

  static SupabaseClient get client {
    // ALWAYS return the standard instance client to ensure 
    // Auth storage and PKCE flow work correctly.
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    String url = '';
    String anonKey = '';
    try {
      debugPrint('Supabase: Initializing with Adom Mmoroso ENT. database configuration...');
      
      // Priority 1: Environment Variables (--dart-define)
      url = const String.fromEnvironment('SUPABASE_URL');
      anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

      // Priority 2: .env file
      if (url.isEmpty) url = dotenv.env['SUPABASE_URL'] ?? '';
      if (anonKey.isEmpty) anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      // Force-override if URL is empty or points to legacy database instance
      if (url.isEmpty || url.contains('hgkkxffcsuobctmistfc')) {
        url = activeSupabaseUrl; 
      }
      
      if (anonKey.isEmpty || anonKey.contains('hgkkxffcsuobctmistfc')) {
        anonKey = activeSupabaseAnonKey;
      }

      String cleanUrl = url.trim();
      while (cleanUrl.startsWith('https:https://')) {
        cleanUrl = cleanUrl.substring(6);
      }
      while (cleanUrl.startsWith('http:http://')) {
        cleanUrl = cleanUrl.substring(5);
      }
      final cleanKey = anonKey.trim();

      if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
        throw Exception('Supabase URL is invalid: "$cleanUrl"');
      }

      String serviceRoleKey = const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
      if (serviceRoleKey.isEmpty) serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

      // 1. Initialize standard Supabase instance
      // This automatically sets up SharedPreferences for Auth
      await Supabase.initialize(
        url: cleanUrl,
        publishableKey: cleanKey, 
        debug: kDebugMode,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      
      // 2. Initialize our managed admin client separately if needed
      // Note: We avoid creating a manual public client because it breaks PKCE storage
      _publicClient = Supabase.instance.client;

      if (serviceRoleKey.trim().isNotEmpty) {
        _adminClient = SupabaseClient(cleanUrl, serviceRoleKey.trim());
      } else {
        _adminClient = _publicClient;
      }

      _isInitialized = true;
      debugPrint('Supabase initialized successfully via standard instance.');
    } catch (e) {
      if (e.toString().contains('already been initialized')) {
        _isInitialized = true;
        return;
      }
      rethrow;
    }
  }
}
