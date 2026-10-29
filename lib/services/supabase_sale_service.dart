import '../models/sale_model.dart';
import '../core/supabase_config.dart';
import 'package:flutter/foundation.dart';

class SupabaseSaleService {
  final _client = SupabaseConfig.client;

  Future<List<SaleRecord>> getSales(String? branchCode, {int limit = 200}) async {
    try {
      dynamic query = _client.from('sales').select();
      if (branchCode != null && branchCode.isNotEmpty && branchCode != 'ALL' && branchCode != 'HQ') {
        query = query.eq('branch_code', branchCode);
      }
      final response = await query.order('timestamp', ascending: false).limit(limit);
      
      return (response as List).map((json) => SaleRecord.fromJson(json)).toList();
    } catch (e) {
      debugPrint('SupabaseSaleService getSales error: $e');
      return [];
    }
  }

  Future<void> saveSale(SaleRecord sale) async {
    final data = sale.toJson();
    try {
      await _client.from('sales').insert(data);
    } catch (e) {
      if (e.toString().contains('PGRST204') || e.toString().toUpperCase().contains('COLUMN')) {
        debugPrint('SupabaseSaleService saveSale column error fallback: $e');
        final cleanData = Map<String, dynamic>.from(data)
          ..remove('total_cost')
          ..remove('total_discount')
          ..remove('applied_promo')
          ..remove('correction_reason')
          ..remove('bank_receipt_url')
          ..remove('bank_receipt_id')
          ..remove('is_verified');
        await _client.from('sales').insert(cleanData);
      } else {
        rethrow;
      }
    }
  }

  Future<void> updateSale(SaleRecord sale) async {
    final data = sale.toJson();
    try {
      await _client
          .from('sales')
          .update(data)
          .eq('id', sale.id);
    } catch (e) {
      if (e.toString().contains('PGRST204') || e.toString().toUpperCase().contains('COLUMN')) {
        debugPrint('SupabaseSaleService updateSale column error fallback: $e');
        final cleanData = Map<String, dynamic>.from(data)
          ..remove('total_cost')
          ..remove('total_discount')
          ..remove('applied_promo')
          ..remove('correction_reason')
          ..remove('bank_receipt_url')
          ..remove('bank_receipt_id')
          ..remove('is_verified');
        await _client
            .from('sales')
            .update(cleanData)
            .eq('id', sale.id);
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteSales(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('sales').delete().filter('id', 'in', '(${ids.join(',')})');
  }

  Stream<List<SaleRecord>> getSalesStream(String? branchCode) {
    try {
      dynamic stream = _client.from('sales').stream(primaryKey: ['id']);
      if (branchCode != null && branchCode.isNotEmpty && branchCode != 'ALL' && branchCode != 'HQ') {
        stream = stream.eq('branch_code', branchCode);
      }
      return stream
          .order('timestamp', ascending: false)
          .limit(150)
          .map((data) => data.map((json) => SaleRecord.fromJson(json)).toList())
          .handleError((e, st) {
            debugPrint('Sale Stream Warning: $e');
            return <SaleRecord>[];
          });
    } catch (_) {
      return Stream.value([]);
    }
  }
}
