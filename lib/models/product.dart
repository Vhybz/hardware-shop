import 'package:citypos/models/customer_model.dart';

enum PromoTarget { retail, wholesale, both }
enum PromoCustomerTarget { all, regularsOnly, specialOnly, specificPerson }

class PriceBracket {
  final double minWeight;
  final double maxWeight;
  final double price;

  PriceBracket({
    required this.minWeight, 
    required this.maxWeight, 
    required this.price
  });

  factory PriceBracket.fromJson(dynamic json) {
    final map = Map<String, dynamic>.from(json);
    return PriceBracket(
      minWeight: (map['minWeight'] as num).toDouble(),
      maxWeight: (map['maxWeight'] as num).toDouble(),
      price: (map['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'minWeight': minWeight,
    'maxWeight': maxWeight,
    'price': price,
  };
}

class Product {
  final String id;
  final String? branchCode;
  final String name;
  final double retailPrice;
  final double wholesalePrice;
  final double costPrice;
  final List<PriceBracket>? retailBrackets;
  final List<PriceBracket>? wholesaleBrackets;
  final String imageUrl;
  final String category;
  final double stockQuantity; // Store Stock
  final double warehouseQuantity; // Warehouse Stock
  final double minStoreStock; // Minimum Store Stock Threshold
  final String? sku;
  final String? brand;
  final String? size;
  final String? warehouseLocation;
  final String unit;
  final double discountPercentage;
  final DateTime? promoStartDate;
  final DateTime? promoEndDate;
  final PromoTarget promoTarget;
  final PromoCustomerTarget promoCustomerTarget;
  final String? targetCustomerId;
  final bool hasPacks; // Packaging option: Packs enabled
  final bool hasBoxes; // Packaging option: Boxes enabled
  final double pcsPerPack; // Pieces per pack (default 12.0)
  final double packsPerBox; // Packs per box (default 10.0)
  final double pcsPerBox; // Total pieces per box (pcsPerPack * packsPerBox)
  final bool isDeleted; // Soft delete
  final bool isUnlimited; // Stock doesn't decrease on sales
  final bool allowRetail; // Available for Retail sales
  final bool allowWholesale; // Available for Wholesale sales
  final double lowStockThreshold;
  final double dailyStockAdded;
  final DateTime? lastStockUpdate;

  Product({
    required this.id,
    this.branchCode,
    required this.name,
    required this.retailPrice,
    required this.wholesalePrice,
    this.costPrice = 0,
    this.retailBrackets,
    this.wholesaleBrackets,
    required this.imageUrl,
    required this.category,
    this.stockQuantity = 0,
    this.warehouseQuantity = 0,
    this.minStoreStock = 5.0,
    this.sku,
    this.brand,
    this.size = 'Standard',
    this.warehouseLocation,
    this.unit = 'pcs',
    this.hasPacks = true,
    this.hasBoxes = true,
    this.pcsPerPack = 12.0,
    this.packsPerBox = 10.0,
    this.pcsPerBox = 120.0,
    this.discountPercentage = 0.0,
    this.promoStartDate,
    this.promoEndDate,
    this.promoTarget = PromoTarget.both,
    this.promoCustomerTarget = PromoCustomerTarget.all,
    this.targetCustomerId,
    this.isDeleted = false,
    this.isUnlimited = false,
    this.allowRetail = true,
    this.allowWholesale = true,
    this.lowStockThreshold = 5.0, // Default threshold
    this.dailyStockAdded = 0.0,
    this.lastStockUpdate,
  });

  bool get isRetailOnly => allowRetail && !allowWholesale;
  bool get isWholesaleOnly => !allowRetail && allowWholesale;
  bool get isBothRetailAndWholesale => allowRetail && allowWholesale;

  bool get needsDispatch => !isUnlimited && stockQuantity <= minStoreStock;
  double get storeStock => stockQuantity;

  /// Total pieces per box
  double get totalPcsPerBox => pcsPerPack > 0 && packsPerBox > 0 ? (pcsPerPack * packsPerBox) : (pcsPerBox > 0 ? pcsPerBox : 120.0);

  /// Packs & Boxes in store
  double get storePacks => pcsPerPack > 0 ? stockQuantity / pcsPerPack : stockQuantity;
  double get storeBoxes => totalPcsPerBox > 0 ? stockQuantity / totalPcsPerBox : stockQuantity;

  /// Packs & Boxes in warehouse
  double get warehousePacks => pcsPerPack > 0 ? warehouseQuantity / pcsPerPack : warehouseQuantity;
  double get warehouseBoxes => totalPcsPerBox > 0 ? warehouseQuantity / totalPcsPerBox : warehouseQuantity;

  /// Display for POS: ONLY pieces (e.g. "120 Pcs")
  String get posStockDisplay => isUnlimited ? 'UNLIMITED' : '${stockQuantity.toInt()} Pcs';

  /// Display for Stock Control (Store): Pcs, Packs & Boxes
  String get stockControlStoreDisplay {
    if (isUnlimited) return 'UNLIMITED';
    final int pcs = stockQuantity.toInt();
    
    if (hasPacks && hasBoxes) {
      final double pk = storePacks;
      final double bx = storeBoxes;
      final pkStr = pk % 1 == 0 ? pk.toInt().toString() : pk.toStringAsFixed(1);
      final bxStr = bx % 1 == 0 ? bx.toInt().toString() : bx.toStringAsFixed(1);
      return '$pcs Pcs ($pkStr Packs | $bxStr Boxes)';
    } else if (hasBoxes) {
      final double bx = storeBoxes;
      final bxStr = bx % 1 == 0 ? bx.toInt().toString() : bx.toStringAsFixed(1);
      return '$pcs Pcs ($bxStr Boxes)';
    } else if (hasPacks) {
      final double pk = storePacks;
      final pkStr = pk % 1 == 0 ? pk.toInt().toString() : pk.toStringAsFixed(1);
      return '$pcs Pcs ($pkStr Packs)';
    }
    return '$pcs Pcs';
  }

  /// Display for Stock Control (Warehouse): Pcs, Packs & Boxes
  String get stockControlWarehouseDisplay {
    final int pcs = warehouseQuantity.toInt();
    
    if (hasPacks && hasBoxes) {
      final double pk = warehousePacks;
      final double bx = warehouseBoxes;
      final pkStr = pk % 1 == 0 ? pk.toInt().toString() : pk.toStringAsFixed(1);
      final bxStr = bx % 1 == 0 ? bx.toInt().toString() : bx.toStringAsFixed(1);
      return '$pcs Pcs ($pkStr Packs | $bxStr Boxes)';
    } else if (hasBoxes) {
      final double bx = warehouseBoxes;
      final bxStr = bx % 1 == 0 ? bx.toInt().toString() : bx.toStringAsFixed(1);
      return '$pcs Pcs ($bxStr Boxes)';
    } else if (hasPacks) {
      final double pk = warehousePacks;
      final pkStr = pk % 1 == 0 ? pk.toInt().toString() : pk.toStringAsFixed(1);
      return '$pcs Pcs ($pkStr Packs)';
    }
    return '$pcs Pcs';
  }

  /// Logic to check if promotion is currently scheduled correctly by date
  bool get isPromoScheduled {
    if (discountPercentage <= 0) return false;
    if (promoStartDate == null || promoEndDate == null) return true;
    
    final now = DateTime.now();
    return !now.isBefore(promoStartDate!) && now.isBefore(promoEndDate!.add(const Duration(days: 1)));
  }

  /// Check if promo is active for a specific mode and customer
  bool isPromoActiveFor(bool isWholesale, Customer? customer, {bool ignoreCustomerFilter = false}) {
    if (!isPromoScheduled) return false;
    
    // Check mode target
    bool modeMatch = false;
    if (promoTarget == PromoTarget.both) {
      modeMatch = true;
    } else if (isWholesale) {
      modeMatch = (promoTarget == PromoTarget.wholesale);
    } else {
      modeMatch = (promoTarget == PromoTarget.retail);
    }

    if (!modeMatch) return false;

    // Check customer target
    if (ignoreCustomerFilter || promoCustomerTarget == PromoCustomerTarget.all) return true;
    if (customer == null) return false;

    switch (promoCustomerTarget) {
      case PromoCustomerTarget.all:
        return true;
      case PromoCustomerTarget.regularsOnly:
        return customer.isFavorite;
      case PromoCustomerTarget.specialOnly:
        return customer.isSpecial;
      case PromoCustomerTarget.specificPerson:
        return targetCustomerId != null && customer.id == targetCustomerId;
    }
  }

  /// Helper to get price based on mode, weight, and active discount
  double getPrice(bool isWholesale, {double? weight, Customer? customer, bool ignoreCustomerFilter = false}) {
    final brackets = isWholesale ? wholesaleBrackets : retailBrackets;
    double currentPrice = isWholesale ? wholesalePrice : retailPrice;
    
    if (weight != null && brackets != null && brackets.isNotEmpty) {
      for (var bracket in brackets) {
        if (weight >= bracket.minWeight && weight <= bracket.maxWeight) {
          currentPrice = bracket.price;
          break;
        }
      }
    }

    if (isPromoActiveFor(isWholesale, customer, ignoreCustomerFilter: ignoreCustomerFilter)) {
      return currentPrice * (1 - (discountPercentage / 100));
    }
    return currentPrice;
  }

  Product copyWith({
    String? name,
    String? branchCode,
    double? retailPrice,
    double? wholesalePrice,
    double? costPrice,
    double? stockQuantity,
    double? warehouseQuantity,
    double? minStoreStock,
    String? sku,
    String? brand,
    String? size,
    String? warehouseLocation,
    String? category,
    String? unit,
    bool? hasPacks,
    bool? hasBoxes,
    double? pcsPerPack,
    double? packsPerBox,
    double? pcsPerBox,
    double? discountPercentage,
    DateTime? promoStartDate,
    DateTime? promoEndDate,
    PromoTarget? promoTarget,
    PromoCustomerTarget? promoCustomerTarget,
    String? targetCustomerId,
    String? imageUrl,
    bool? isDeleted,
    bool? isUnlimited,
    bool? allowRetail,
    bool? allowWholesale,
    double? lowStockThreshold,
    double? dailyStockAdded,
    DateTime? lastStockUpdate,
  }) {
    return Product(
      id: id,
      branchCode: branchCode ?? this.branchCode,
      name: name ?? this.name,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      costPrice: costPrice ?? this.costPrice,
      retailBrackets: retailBrackets,
      wholesaleBrackets: wholesaleBrackets,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      warehouseQuantity: warehouseQuantity ?? this.warehouseQuantity,
      minStoreStock: minStoreStock ?? this.minStoreStock,
      sku: sku ?? this.sku,
      brand: brand ?? this.brand,
      size: size ?? this.size,
      warehouseLocation: warehouseLocation ?? this.warehouseLocation,
      unit: unit ?? this.unit,
      hasPacks: hasPacks ?? this.hasPacks,
      hasBoxes: hasBoxes ?? this.hasBoxes,
      pcsPerPack: pcsPerPack ?? this.pcsPerPack,
      packsPerBox: packsPerBox ?? this.packsPerBox,
      pcsPerBox: pcsPerBox ?? this.pcsPerBox,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      promoStartDate: promoStartDate ?? this.promoStartDate,
      promoEndDate: promoEndDate ?? this.promoEndDate,
      promoTarget: promoTarget ?? this.promoTarget,
      promoCustomerTarget: promoCustomerTarget ?? this.promoCustomerTarget,
      targetCustomerId: targetCustomerId ?? this.targetCustomerId,
      isDeleted: isDeleted ?? this.isDeleted,
      isUnlimited: isUnlimited ?? this.isUnlimited,
      allowRetail: allowRetail ?? this.allowRetail,
      allowWholesale: allowWholesale ?? this.allowWholesale,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      dailyStockAdded: dailyStockAdded ?? this.dailyStockAdded,
      lastStockUpdate: lastStockUpdate ?? this.lastStockUpdate,
    );
  }

  factory Product.fromJson(dynamic json) {
    final map = Map<String, dynamic>.from(json);
    PromoCustomerTarget safeCustomerTarget(String? target) {
      if (target == null) return PromoCustomerTarget.all;
      try {
        return PromoCustomerTarget.values.byName(target);
      } catch (_) {
        return PromoCustomerTarget.all;
      }
    }

    PromoTarget safePromoTarget(dynamic val) {
      if (val == null) return PromoTarget.both;
      final str = val.toString().toLowerCase().trim();
      if (str.contains('retail')) return PromoTarget.retail;
      if (str.contains('wholesale')) return PromoTarget.wholesale;
      return PromoTarget.both;
    }

    double safeNum(dynamic val, [double defaultVal = 0.0]) {
      if (val == null) return defaultVal;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? defaultVal;
    }

    String parsedCategory = map['category']?.toString() ?? 'BUILDING MATERIALS';
    final upperCat = parsedCategory.toUpperCase();
    if (upperCat.contains('SKINCARE') || upperCat.contains('COSMETIC') || upperCat.contains('MAKEUP') || upperCat.contains('FRAGRANCE') || upperCat.contains('HAIRCARE') || upperCat.contains('PERFUME')) {
      parsedCategory = 'BUILDING MATERIALS';
    }

    return Product(
      id: map['id'] as String,
      branchCode: map['branch_code']?.toString(),
      name: map['name'] as String? ?? 'Product',
      retailPrice: safeNum(map['retail_price']),
      wholesalePrice: safeNum(map['wholesale_price']),
      costPrice: safeNum(map['cost_price']),
      retailBrackets: (map['retail_brackets'] as List?)
          ?.map((e) => PriceBracket.fromJson(e))
          .toList(),
      wholesaleBrackets: (map['wholesale_brackets'] as List?)
          ?.map((e) => PriceBracket.fromJson(e))
          .toList(),
      imageUrl: map['image_url'] as String? ?? '',
      category: parsedCategory,
      stockQuantity: safeNum(map['stock_quantity']),
      warehouseQuantity: safeNum(map['warehouse_quantity'] ?? map['initial_weight']),
      minStoreStock: safeNum(map['min_store_stock'] ?? map['low_stock_threshold'], 5.0),
      sku: map['sku']?.toString(),
      brand: map['brand']?.toString(),
      size: (map['size'] != null && map['size'].toString().trim().isNotEmpty) ? map['size'].toString() : 'Standard',
      warehouseLocation: map['warehouse_location']?.toString(),
      unit: map['unit'] as String? ?? 'Pcs',
      hasPacks: map['has_packs'] ?? true,
      hasBoxes: map['has_boxes'] ?? true,
      pcsPerPack: safeNum(map['pcs_per_pack'], 12.0),
      packsPerBox: safeNum(map['packs_per_box'], 10.0),
      pcsPerBox: safeNum(map['pcs_per_box'] ?? map['pieces_per_box'], 120.0),
      discountPercentage: safeNum(map['discount_percentage']),
      promoStartDate: map['promo_start_date'] != null 
          ? DateTime.tryParse(map['promo_start_date'].toString()) 
          : (map['promo_start'] != null ? DateTime.tryParse(map['promo_start'].toString()) : null),
      promoEndDate: map['promo_end_date'] != null 
          ? DateTime.tryParse(map['promo_end_date'].toString()) 
          : (map['promo_end'] != null ? DateTime.tryParse(map['promo_end'].toString()) : null),
      promoTarget: safePromoTarget(map['promo_target']),
      promoCustomerTarget: safeCustomerTarget(map['promo_customer_target']),
      targetCustomerId: map['target_customer_id']?.toString(),
      isDeleted: map['is_deleted'] == true,
      isUnlimited: map['is_unlimited'] == true,
      allowRetail: map['allow_retail'] ?? true,
      allowWholesale: map['allow_wholesale'] ?? true,
      lowStockThreshold: safeNum(map['low_stock_threshold'], 5.0),
      dailyStockAdded: safeNum(map['daily_stock_added']),
      lastStockUpdate: map['last_stock_update'] != null ? DateTime.tryParse(map['last_stock_update'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'branch_code': branchCode,
        'name': name,
        'retail_price': retailPrice,
        'wholesale_price': wholesalePrice,
        'cost_price': costPrice,
        'retail_brackets': retailBrackets?.map((e) => e.toJson()).toList(),
        'wholesale_brackets': wholesaleBrackets?.map((e) => e.toJson()).toList(),
        'image_url': imageUrl,
        'category': category,
        'stock_quantity': stockQuantity,
        'warehouse_quantity': warehouseQuantity,
        'min_store_stock': minStoreStock,
        'sku': sku,
        'brand': brand,
        'size': size,
        'warehouse_location': warehouseLocation,
        'unit': unit,
        'has_packs': hasPacks,
        'has_boxes': hasBoxes,
        'pcs_per_pack': pcsPerPack,
        'packs_per_box': packsPerBox,
        'pcs_per_box': pcsPerBox,
        'discount_percentage': discountPercentage,
        'promo_start': promoStartDate?.toIso8601String(),
        'promo_end': promoEndDate?.toIso8601String(),
        'promo_target': promoTarget.name,
        'promo_customer_target': promoCustomerTarget.name,
        'target_customer_id': targetCustomerId,
        'is_deleted': isDeleted,
        'is_unlimited': isUnlimited,
        'allow_retail': allowRetail,
        'allow_wholesale': allowWholesale,
        'low_stock_threshold': lowStockThreshold,
        'daily_stock_added': dailyStockAdded,
        'last_stock_update': lastStockUpdate?.toIso8601String(),
      };
}

class CartItem {
  final Product product;
  final double quantity;
  final double priceAtSale;
  final double originalPrice;
  final String? selectedUnit;

  CartItem({
    required this.product, 
    required this.quantity,
    required this.priceAtSale,
    required this.originalPrice,
    this.selectedUnit,
  });

  double get total => priceAtSale * quantity;
  double get discount => (originalPrice - priceAtSale) * quantity;
}
