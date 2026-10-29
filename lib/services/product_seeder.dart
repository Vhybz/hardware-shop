import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/uuid_utils.dart';
import 'product_service.dart';
import 'user_provider.dart';
import 'sale_provider.dart';
import 'offline_sync_service.dart';

class DefaultProductItem {
  final String name;
  final String category;
  final String unit;
  final String sku;
  final double lowStockThreshold;

  const DefaultProductItem({
    required this.name,
    required this.category,
    required this.unit,
    required this.sku,
    this.lowStockThreshold = 10.0,
  });
}

class ProductSeeder {
  final Ref ref;
  ProductSeeder(this.ref);

  /// Resets all product stock quantities (Store & Warehouse) to 0.0 Pcs locally
  Future<void> resetAllStockToZero() async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.branchCode == null) return;

    if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
      final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
      final keys = List.from(box.keys);
      for (final key in keys) {
        final item = box.get(key);
        if (item != null) {
          final map = Map<String, dynamic>.from(item);
          map['stock_quantity'] = 0.0;
          map['warehouse_quantity'] = 0.0;
          map['daily_stock_added'] = 0.0;
          await box.put(key, map);
        }
      }
    }

    ref.invalidate(productsFutureProvider);
  }

  /// Default Zero-Price Product Catalog for Hardware & Building Materials
  static const List<DefaultProductItem> defaultCatalog = [
    DefaultProductItem(
        name: 'GHACEM CEMENT 42.5N (BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-CEM-01'),
    DefaultProductItem(
        name: 'DANGOTE CEMENT 42.5R (BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-CEM-02'),
    DefaultProductItem(
        name: 'CIMAF CEMENT 42.5N (BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-CEM-03'),
    DefaultProductItem(
        name: 'SUPERSET CEMENT 32.5R (BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-CEM-04'),
    DefaultProductItem(
        name: 'WHITE CEMENT 25KG (BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-CEM-05'),
    DefaultProductItem(
        name: 'TILE ADHESIVE (20KG BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-TIL-01'),
    DefaultProductItem(
        name: 'TILE GROUT WHITE (5KG BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-TIL-02'),
    DefaultProductItem(
        name: 'TILE GROUT GREY (5KG BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-TIL-03'),
    DefaultProductItem(
        name: 'HYDRATED LIME (25KG BAG)',
        category: 'BUILDING MATERIALS',
        unit: 'Bag',
        sku: 'BM-LIM-01'),
  ];

  /// Seeds missing default hardware products into local Hive storage
  Future<void> seedProducts() async {
    await seedHardwareProductsIfEmpty();
  }

  Future<void> seedHardwareProductsIfEmpty() async {
    final user = ref.read(currentUserProvider);
    final branchCode = user?.branchCode ?? 'MAIN';

    final productsBox = Hive.box<Map>(OfflineSyncService.productsBoxName);
    final existingSkus = <String>{};

    for (final key in productsBox.keys) {
      final item = productsBox.get(key);
      if (item != null && item['sku'] != null) {
        existingSkus.add(item['sku'].toString().toUpperCase());
      }
    }

    final now = DateTime.now().toIso8601String();

    for (final item in defaultCatalog) {
      if (!existingSkus.contains(item.sku.toUpperCase())) {
        final id = UuidUtils.generate();
        final newProductMap = {
          'id': id,
          'name': item.name,
          'category': item.category,
          'unit': item.unit,
          'sku': item.sku,
          'price': 0.0,
          'cost_price': 0.0,
          'stock_quantity': 0.0,
          'warehouse_quantity': 0.0,
          'branch_code': branchCode,
          'low_stock_threshold': item.lowStockThreshold,
          'created_at': now,
          'updated_at': now,
          'is_active': true,
          'is_deleted': false,
        };

        await productsBox.put(id, newProductMap);
      }
    }

    ref.read(productsFutureProvider.notifier).refreshFromCache();
    ref.invalidate(productsFutureProvider);
  }

  /// Purges old cosmetics products and legacy records from local Hive cache
  Future<void> purgeLegacyCosmeticsData() async {
    final productsBox = Hive.box<Map>(OfflineSyncService.productsBoxName);
    final keys = List.from(productsBox.keys);

    for (final key in keys) {
      final item = productsBox.get(key);
      if (item != null) {
        final category = (item['category'] ?? '').toString().toLowerCase();
        if (category.contains('skincare') ||
            category.contains('cosmetics') ||
            category.contains('makeup') ||
            category.contains('perfume') ||
            category.contains('fragrance') ||
            category.contains('haircare')) {
          await productsBox.delete(key);
        }
      }
    }

    ref.invalidate(productsFutureProvider);
    ref.invalidate(saleHistoryProvider);
  }
}

final productSeederProvider =
    Provider<ProductSeeder>((ref) => ProductSeeder(ref));
