import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(Product product, double quantity, bool isWholesale, {String? selectedUnit}) {
    final price = product.getPrice(isWholesale);
    final basePrice = isWholesale ? product.wholesalePrice : product.retailPrice;
    addItemWithCustomPrice(product, quantity, price, basePrice, selectedUnit: selectedUnit);
  }

  void addItemWithCustomPrice(Product product, double quantity, double customPrice, double originalPrice, {String? selectedUnit}) {
    final String unit = selectedUnit ?? product.unit;

    // Check if item with same product ID, unit, and sale price already exists in cart
    final existingIndex = state.indexWhere((item) =>
      item.product.id == product.id &&
      (item.selectedUnit ?? item.product.unit) == unit &&
      item.priceAtSale == customPrice
    );

    if (existingIndex != -1) {
      final existing = state[existingIndex];
      final updatedItem = CartItem(
        product: existing.product,
        quantity: existing.quantity + quantity,
        priceAtSale: existing.priceAtSale,
        originalPrice: existing.originalPrice,
        selectedUnit: existing.selectedUnit,
      );
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) updatedItem else state[i]
      ];
    } else {
      state = [
        ...state,
        CartItem(
          product: product,
          quantity: quantity,
          priceAtSale: customPrice,
          originalPrice: originalPrice,
          selectedUnit: unit,
        )
      ];
    }
  }

  void updateQuantity(int index, double newQuantity) {
    if (index < 0 || index >= state.length) return;
    if (newQuantity <= 0) {
      removeItem(index);
      return;
    }
    final item = state[index];
    final updatedItem = CartItem(
      product: item.product,
      quantity: newQuantity,
      priceAtSale: item.priceAtSale,
      originalPrice: item.originalPrice,
      selectedUnit: item.selectedUnit,
    );
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index) updatedItem else state[i]
    ];
  }

  void incrementQuantity(int index, double delta) {
    if (index < 0 || index >= state.length) return;
    updateQuantity(index, state[index].quantity + delta);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.length) return;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i != index) state[i]
    ];
  }

  void clear() {
    state = [];
  }

  double get subtotal => state.fold(0, (sum, item) => sum + item.total);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

// Provider to track if we are in Wholesale mode
final isWholesaleProvider = StateProvider<bool>((ref) => false);
