import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LaravelApiService {
  static String get baseUrl {
    final envUrl = dotenv.env['LARAVEL_API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      if (kIsWeb && envUrl.contains('10.0.2.2')) {
        return 'http://127.0.0.1:8000/api/v1';
      }
      return envUrl;
    }
    return 'https://adom-pos-api.onrender.com/api/v1';
  }

  static String? get _token {
    if (!Hive.isBoxOpen('app_settings')) return null;
    final box = Hive.box('app_settings');
    return box.get('laravel_token') as String?;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null && _token!.isNotEmpty)
          'Authorization': 'Bearer $_token',
      };

  /// Login with email & password via Laravel Sanctum
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == 'success') {
        final token = data['token'] as String?;
        if (token != null) {
          final box = Hive.isBoxOpen('app_settings')
              ? Hive.box('app_settings')
              : await Hive.openBox('app_settings');
          await box.put('laravel_token', token);
        }
        return data;
      }
      throw Exception(data['message'] ?? 'Login failed');
    } catch (e) {
      debugPrint('LaravelApiService Login Error: $e');
      rethrow;
    }
  }

  /// Register new user via Laravel API
  static Future<Map<String, dynamic>> register(
      Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode(userData),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['status'] == 'success') {
        final token = data['token'] as String?;
        if (token != null) {
          final box = Hive.isBoxOpen('app_settings')
              ? Hive.box('app_settings')
              : await Hive.openBox('app_settings');
          await box.put('laravel_token', token);
        }
        return data;
      }
      throw Exception(data['message'] ?? 'Registration failed');
    } catch (e) {
      debugPrint('LaravelApiService Register Error: $e');
      rethrow;
    }
  }

  /// Get current user profile
  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch user profile');
  }

  /// Fetch users list from Laravel API
  static Future<List<dynamic>> fetchUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('LaravelApiService fetchUsers Error: $e');
    }
    return [];
  }

  /// Fetch products list for a branch
  static Future<List<dynamic>> fetchProducts(String branchCode) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products?branch_code=$branchCode'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] as List<dynamic>;
    }
    throw Exception('Failed to load products');
  }

  /// Create or update product on Laravel API
  static Future<bool> submitProduct(Map<String, dynamic> productJson) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/products'),
        headers: _headers,
        body: jsonEncode(productJson),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('LaravelApiService submitProduct Error: $e');
      return false;
    }
  }

  /// Submit sale transaction
  static Future<bool> submitSale(Map<String, dynamic> saleJson) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sales'),
        headers: _headers,
        body: jsonEncode(saleJson),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
      throw Exception('Server returned ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('LaravelApiService submitSale Error: $e');
      rethrow;
    }
  }

  /// Submit customer record
  static Future<bool> submitCustomer(Map<String, dynamic> customerJson) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/customers'),
        headers: _headers,
        body: jsonEncode(customerJson),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('LaravelApiService submitCustomer Error: $e');
      return false;
    }
  }

  /// Fetch customers
  static Future<List<dynamic>> fetchCustomers(String branchCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customers?branch_code=$branchCode'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('LaravelApiService fetchCustomers Error: $e');
    }
    return [];
  }

  /// Submit expense record
  static Future<bool> submitExpense(Map<String, dynamic> expenseJson) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/expenses'),
        headers: _headers,
        body: jsonEncode(expenseJson),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('LaravelApiService submitExpense Error: $e');
      return false;
    }
  }

  /// Fetch expenses
  static Future<List<dynamic>> fetchExpenses(String branchCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/expenses?branch_code=$branchCode'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('LaravelApiService fetchExpenses Error: $e');
    }
    return [];
  }

  /// Submit branch record
  static Future<bool> submitBranch(Map<String, dynamic> branchJson) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/branches'),
        headers: _headers,
        body: jsonEncode(branchJson),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('LaravelApiService submitBranch Error: $e');
      return false;
    }
  }

  /// Fetch branches
  static Future<List<dynamic>> fetchBranches() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/branches'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('LaravelApiService fetchBranches Error: $e');
    }
    return [];
  }

  /// Submit audit log record
  static Future<bool> submitAuditLog(Map<String, dynamic> auditJson) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/audit-logs'),
        headers: _headers,
        body: jsonEncode(auditJson),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('LaravelApiService submitAuditLog Error: $e');
      return false;
    }
  }

  /// Fetch audit logs
  static Future<List<dynamic>> fetchAuditLogs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/audit-logs'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('LaravelApiService fetchAuditLogs Error: $e');
    }
    return [];
  }

  /// Process offline batch queue sync
  static Future<bool> processBatchSync(
      List<Map<String, dynamic>> batch) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sync/batch'),
      headers: _headers,
      body: jsonEncode({'batch': batch}),
    );

    return response.statusCode == 200;
  }
}
