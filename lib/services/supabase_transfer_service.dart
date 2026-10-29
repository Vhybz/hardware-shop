import '../models/transfer_models.dart';
import '../core/supabase_config.dart';

class SupabaseTransferService {
  final _client = SupabaseConfig.client;

  Future<List<StockTransfer>> getTransfers() async {
    try {
      final response = await _client
          .from('stock_transfers')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((json) => StockTransfer.fromJson(json)).toList();
    } catch (e) {
      try {
        final response = await _client.from('stock_transfers').select();
        return (response as List).map((json) => StockTransfer.fromJson(json)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> addTransfer(StockTransfer transfer) async {
    final data = transfer.toJson();
    try {
      await _client.from('stock_transfers').insert(data);
    } catch (e) {
      if (e.toString().contains('42703') || e.toString().contains('transfer_time')) {
        final cleanData = Map<String, dynamic>.from(data)..remove('transfer_time');
        await _client.from('stock_transfers').insert(cleanData);
      } else {
        rethrow;
      }
    }
  }

  Future<void> updateTransferStatus(String id, TransferStatus status) async {
    await _client
        .from('stock_transfers')
        .update({'status': status.name})
        .eq('id', id);
  }

  Stream<List<StockTransfer>> watchTransfers() {
    return _client
        .from('stock_transfers')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((json) => StockTransfer.fromJson(json)).toList());
  }
}
