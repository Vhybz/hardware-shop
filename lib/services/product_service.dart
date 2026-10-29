import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/system_models.dart';
import 'user_provider.dart';
import 'offline_sync_service.dart';
import 'laravel_api_service.dart';

abstract class ProductService {
  Future<List<Product>> getProducts(String branchCode);
  Future<List<Product>> getDeletedProducts(String branchCode);
  Future<Product> getProductById(String id);
  Future<void> addProduct(Product product);
  Future<void> updateProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<void> restoreProduct(String id);
  Future<void> updateStock(String id, double newQuantity);
  Future<void> applyPromotion(
      String id,
      double percentage,
      DateTime? start,
      DateTime? end,
      PromoTarget target,
      PromoCustomerTarget customerTarget,
      [String? targetCustomerId]);
  Future<String?> uploadProductImage(Uint8List bytes, String fileName);
  Stream<List<Product>> watchProducts(String branchCode);
}

class LocalProductService implements ProductService {
  @override
  Future<List<Product>> getProducts(String branchCode) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
        return box.values
            .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
            .where((p) => p.branchCode == branchCode && !p.isDeleted)
            .toList();
      }
    } catch (e) {
      debugPrint('LocalProductService getProducts error: $e');
    }
    return [];
  }

  @override
  Future<List<Product>> getDeletedProducts(String branchCode) async {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
        return box.values
            .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
            .where((p) => p.branchCode == branchCode && p.isDeleted)
            .toList();
      }
    } catch (e) {
      debugPrint('LocalProductService getDeletedProducts error: $e');
    }
    return [];
  }

  @override
  Future<Product> getProductById(String id) async {
    if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
      final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
      final item = box.get(id);
      if (item != null) {
        return Product.fromJson(Map<String, dynamic>.from(item));
      }
    }
    throw Exception('Product $id not found in local storage.');
  }

  @override
  Future<void> addProduct(Product product) async {
    if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
      final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
      await box.put(product.id, product.toJson());
    }
    await OfflineSyncService.addToQueue('UPDATE_PRODUCT', product.toJson());
    unawaited(LaravelApiService.submitProduct(product.toJson()));
  }

  @override
  Future<void> updateProduct(Product product) async {
    if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
      final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
      await box.put(product.id, product.toJson());
    }
    await OfflineSyncService.addToQueue('UPDATE_PRODUCT', product.toJson());
    unawaited(LaravelApiService.submitProduct(product.toJson()));
  }

  @override
  Future<void> deleteProduct(String id) async {
    if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
      final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
      final item = box.get(id);
      if (item != null) {
        final p = Product.fromJson(Map<String, dynamic>.from(item));
        final updated = p.copyWith(isDeleted: true);
        await box.put(id, updated.toJson());
      }
    }
    await OfflineSyncService.addToQueue('DELETE_PRODUCT', {'id': id});
  }

  @override
  Future<void> restoreProduct(String id) async {
    if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
      final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
      final item = box.get(id);
      if (item != null) {
        final p = Product.fromJson(Map<String, dynamic>.from(item));
        final updated = p.copyWith(isDeleted: false);
        await box.put(id, updated.toJson());
      }
    }
  }

  @override
  Future<void> updateStock(String id, double newQuantity) async {
    if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
      final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
      final item = box.get(id);
      if (item != null) {
        final p = Product.fromJson(Map<String, dynamic>.from(item));
        final updated = p.copyWith(stockQuantity: newQuantity);
        await box.put(id, updated.toJson());
      }
    }
  }

  @override
  Future<void> applyPromotion(
      String id,
      double percentage,
      DateTime? start,
      DateTime? end,
      PromoTarget target,
      PromoCustomerTarget customerTarget,
      [String? targetCustomerId]) async {
    if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
      final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
      final item = box.get(id);
      if (item != null) {
        final p = Product.fromJson(Map<String, dynamic>.from(item));
        final updated = p.copyWith(
          discountPercentage: percentage,
          promoStartDate: start,
          promoEndDate: end,
          promoTarget: target,
          promoCustomerTarget: customerTarget,
          targetCustomerId: targetCustomerId,
        );
        await box.put(id, updated.toJson());
      }
    }
  }

  @override
  Future<String?> uploadProductImage(Uint8List bytes, String fileName) async {
    return null;
  }

  @override
  Stream<List<Product>> watchProducts(String branchCode) async* {
    final initial = await getProducts(branchCode);
    yield initial;
  }
}

final productServiceProvider = Provider<ProductService>((ref) {
  return LocalProductService();
});

final productsFutureProvider = StateNotifierProvider<ProductNotifier,
    AsyncValue<List<Product>>>((ref) {
  return ProductNotifier(ref.watch(productServiceProvider), ref);
});

final deletedProductsProvider = FutureProvider<List<Product>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final branchCode = user?.branchCode ?? '';
  final service = ref.watch(productServiceProvider);
  return service.getDeletedProducts(branchCode);
});

class ProductNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductService _service;
  final Ref ref;

  ProductNotifier(this._service, this.ref)
      : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _loadFromCache();

    ref.listen(currentUserProvider, (previous, next) {
      final bCode = next?.branchCode;
      if (bCode != previous?.branchCode && bCode != null) {
        _loadFromCache();
        syncFromBackend(bCode);
      }
    });
  }

  Future<void> loadProducts([String? branchCode]) async {
    _loadFromCache();
    if (branchCode != null && branchCode.isNotEmpty) {
      await syncFromBackend(branchCode);
    }
  }

  Future<void> syncFromBackend(String branchCode) async {
    try {
      final remoteData = await LaravelApiService.fetchProducts(branchCode);
      if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
        for (final item in remoteData) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            if (map['id'] != null) {
              await box.put(map['id'].toString(), map);
            }
          }
        }
      }
      _loadFromCache();
    } catch (e) {
      debugPrint('ProductNotifier syncFromBackend error: $e');
    }
  }

  void _loadFromCache() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
        final box = Hive.box<Map>(OfflineSyncService.productsBoxName);
        if (box.isNotEmpty) {
          final List<Product> cached = box.values
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .where((p) => !p.isDeleted)
              .toList();
          state = AsyncValue.data(cached);
        } else {
          state = const AsyncValue.data([]);
        }
      }
    } catch (e) {
      debugPrint('Product Engine Cache Error: $e');
      state = const AsyncValue.data([]);
    }
  }

  void refreshFromCache() {
    _loadFromCache();
  }

  Future<void> addProduct(Product product) async {
    await _service.addProduct(product);
    _loadFromCache();
  }

  Future<void> updateProduct(Product product) async {
    await _service.updateProduct(product);
    _loadFromCache();
  }

  Future<void> deleteProduct(String id) async {
    await _service.deleteProduct(id);
    _loadFromCache();
  }

  Future<void> restoreProduct(String id) async {
    await _service.restoreProduct(id);
    _loadFromCache();
  }

  Future<void> setUnlimitedStatus(bool isUnlimited) async {
    final current = state.value ?? [];
    for (final p in current) {
      await updateProduct(p.copyWith(isUnlimited: isUnlimited));
    }
  }

  Future<void> clearPromotions() async {
    final current = state.value ?? [];
    for (final p in current) {
      await updateProduct(p.copyWith(discountPercentage: 0));
    }
  }

  Future<void> applyPromotion(
    double percentage,
    DateTime start,
    DateTime end,
    PromoTarget target,
    PromoCustomerTarget customerTarget, {
    List<String>? selectedIds,
    Map<String, double>? individualPercentages,
    String? targetCustomerId,
  }) async {
    final current = state.value ?? [];
    for (final p in current) {
      if (selectedIds == null || selectedIds.contains(p.id)) {
        final pPercentage = individualPercentages?[p.id] ?? percentage;
        await updateProduct(p.copyWith(
          discountPercentage: pPercentage,
          promoStartDate: start,
          promoEndDate: end,
          promoTarget: target,
          promoCustomerTarget: customerTarget,
          targetCustomerId: targetCustomerId,
        ));
      }
    }
  }

  Future<void> removePromotion(String id) async {
    final current = state.value ?? [];
    final p = current.where((prod) => prod.id == id).firstOrNull;
    if (p != null) {
      await updateProduct(p.copyWith(discountPercentage: 0));
    }
  }

  Future<String?> uploadImage(Uint8List bytes, String fileName) async {
    return null;
  }

  Future<void> clearAllStock() async {
    final current = state.value ?? [];
    for (final p in current) {
      await updateProduct(p.copyWith(stockQuantity: 0, warehouseQuantity: 0));
    }
  }

  Future<void> updateStock(String id, double quantityChange,
      {String reason = 'ADJUSTMENT', String? referenceId}) async {
    final products = state.value;
    final now = DateTime.now();

    try {
      Product? product;
      if (products != null) {
        product = products.where((p) => p.id == id).firstOrNull;
      }

      if (product == null) {
        product = await _service.getProductById(id);
      }

      final double calculatedVal = product.stockQuantity + quantityChange;
      final newQuantity = product.isUnlimited
          ? product.stockQuantity
          : (calculatedVal < 0 ? 0.0 : calculatedVal);

      final updatedProduct = product.copyWith(
        stockQuantity: newQuantity,
        lastStockUpdate: now,
      );

      await _service.updateStock(id, newQuantity);

      if (products != null) {
        state = AsyncValue.data(products.map((p) {
          if (p.id == id) return updatedProduct;
          return p;
        }).toList());
      }
    } catch (e) {
      debugPrint('Stock Update Error: $e');
    }
  }
}
