import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../core/supabase_config.dart';

class SupabaseCustomerService {
  final _client = SupabaseConfig.client;

  Future<List<Customer>> getCustomers(String branchCode) async {
    try {
      var query = _client.from('customers').select();
      
      if (branchCode.isNotEmpty) {
        query = query.eq('branch_code', branchCode);
      }
      
      final response = await query.order('name', ascending: true);
      
      return (response as List).map((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      debugPrint('SupabaseCustomerService getCustomers error: $e');
      return [];
    }
  }

  Future<Customer> addCustomer(Customer customer) async {
    final Map<String, dynamic> data = customer.toJson();
    
    // If it's a temporary ID, let Supabase generate a real one
    if (customer.id.startsWith('00000000-0000-0000-0000-')) {
      data.remove('id');
    }

    // Ensure branch_code is null if it's empty to avoid foreign key errors
    if (data['branch_code'] == null || (data['branch_code'] is String && data['branch_code'].toString().isEmpty)) {
      data.remove('branch_code');
    }
    
    try {
      final response = await _client
          .from('customers')
          .insert(data)
          .select()
          .single();
      
      return Customer.fromJson(response);
    } catch (e) {
      debugPrint('SUPABASE CUSTOMER INSERT ERROR: $e');
      rethrow;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    await _client
        .from('customers')
        .update(customer.toJson())
        .eq('id', customer.id);
  }

  Future<void> approveCustomer(String customerId, {double creditLimit = 0.0, String priceTier = 'wholesale'}) async {
    try {
      await _client.from('customers').update({
        'status': 'active',
        'credit_limit': creditLimit,
        'price_tier': priceTier,
      }).eq('id', customerId);
    } catch (e) {
      debugPrint('Error approving customer: $e');
      rethrow;
    }
  }

  Future<void> rejectCustomer(String customerId) async {
    try {
      await _client.from('customers').update({
        'status': 'suspended',
      }).eq('id', customerId);
    } catch (e) {
      debugPrint('Error rejecting customer: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }

  Stream<List<Customer>> watchCustomers(String branchCode) {
    try {
      // Stream all customers across branches so online app customers & B2B accounts are always loaded
      return _client
          .from('customers')
          .stream(primaryKey: ['id'])
          .order('name', ascending: true)
          .map((data) => data.map((json) => Customer.fromJson(json)).where((c) => !c.isDeleted).toList())
          .handleError((e, st) => <Customer>[]);
    } catch (_) {
      return Stream.value([]);
    }
  }
}
