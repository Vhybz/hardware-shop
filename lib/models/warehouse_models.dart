import 'dart:convert';

enum ShipmentStatus { pending, receiving, inspected, completed, processed }

enum BatchStatus { 
  transporting, 
  received, 
  receiving,
  unboxing,
  preparing,
  cutting,
  packaging, 
  shelfReady,
  dispatched,
  completed 
}

// Keep enum aliases for legacy compatibility
typedef SlaughterStatus = ShipmentStatus;
typedef MeatBatchStatus = BatchStatus;

enum ShipmentCategory { buildingMaterials, steelRebar, plumbingPVC, electricals, paintsFinishes, roofingTimber, toolsFasteners, doorsHardware, general }

class ShipmentLog {
  final String id;
  final String tagNumber; // Unique shipment tracking #
  final String supplierName;
  final String? invoiceNumber;
  final DateTime arrivalDate;
  final double? shipmentCost;
  final double totalItemsReceived;
  final ShipmentStatus status;
  final String? receivedBy;
  final String? notes;

  ShipmentLog({
    required this.id,
    required this.tagNumber,
    required this.supplierName,
    this.invoiceNumber,
    required this.arrivalDate,
    this.shipmentCost,
    this.totalItemsReceived = 0,
    this.status = ShipmentStatus.pending,
    this.receivedBy,
    this.notes,
  });

  // Alias getters for UI compatibility
  String get animalType => supplierName;
  String get type => supplierName;
  double get liveWeight => totalItemsReceived;
  double get meatWeight => totalItemsReceived;
  double? get farmPrice => shipmentCost;
  DateTime get slaughterTime => arrivalDate;

  ShipmentLog copyWith({
    String? id,
    String? tagNumber,
    String? supplierName,
    String? invoiceNumber,
    DateTime? arrivalDate,
    double? shipmentCost,
    double? totalItemsReceived,
    ShipmentStatus? status,
    String? receivedBy,
    String? notes,
  }) {
    return ShipmentLog(
      id: id ?? this.id,
      tagNumber: tagNumber ?? this.tagNumber,
      supplierName: supplierName ?? this.supplierName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      shipmentCost: shipmentCost ?? this.shipmentCost,
      totalItemsReceived: totalItemsReceived ?? this.totalItemsReceived,
      status: status ?? this.status,
      receivedBy: receivedBy ?? this.receivedBy,
      notes: notes ?? this.notes,
    );
  }

  factory ShipmentLog.fromJson(Map<String, dynamic> json) {
    return ShipmentLog(
      id: json['id']?.toString() ?? '',
      tagNumber: json['tag_number']?.toString() ?? json['tagNumber']?.toString() ?? 'SHIP-001',
      supplierName: json['type']?.toString() ?? json['animal_type']?.toString() ?? json['supplier_name']?.toString() ?? 'General Cosmetics Supplier',
      invoiceNumber: json['invoice_number']?.toString() ?? json['manual_farm_tag']?.toString(),
      arrivalDate: json['slaughter_time'] != null 
          ? DateTime.tryParse(json['slaughter_time'].toString()) ?? DateTime.now() 
          : (json['slaughter_date'] != null 
              ? DateTime.tryParse(json['slaughter_date'].toString()) ?? DateTime.now() 
              : DateTime.now()),
      shipmentCost: (json['farm_price'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? (json['shipment_cost'] as num?)?.toDouble(),
      totalItemsReceived: (json['initial_weight'] as num?)?.toDouble() ?? (json['carcass_weight'] as num?)?.toDouble() ?? (json['live_weight'] as num?)?.toDouble() ?? 0,
      status: ShipmentStatus.values.firstWhere(
        (e) => e.name == json['status']?.toString(), 
        orElse: () => ShipmentStatus.completed,
      ),
      receivedBy: json['butcher_name']?.toString() ?? json['received_by']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tag_number': tagNumber,
      'type': supplierName,
      'animal_type': supplierName,
      'manual_farm_tag': invoiceNumber,
      'invoice_number': invoiceNumber,
      'slaughter_time': arrivalDate.toIso8601String(),
      'slaughter_date': arrivalDate.toIso8601String(),
      'farm_price': shipmentCost,
      'price': shipmentCost,
      'initial_weight': totalItemsReceived,
      'live_weight': totalItemsReceived,
      'carcass_weight': totalItemsReceived,
      'status': status.name,
      'butcher_name': receivedBy,
      'notes': notes,
    };
  }
}

// Alias for UI screen compatibility
typedef SlaughterLog = ShipmentLog;

class BatchSource {
  final String name;
  final String location;
  final String owner;

  BatchSource({required this.name, required this.location, required this.owner});

  factory BatchSource.fromJson(Map<String, dynamic> json) {
    return BatchSource(
      name: json['name']?.toString() ?? 'Supplier Warehouse',
      location: json['location']?.toString() ?? 'Main HQ',
      owner: json['owner']?.toString() ?? 'Adom Mmoroso ENT.',
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'location': location, 'owner': owner};
}

class WarehouseBatch {
  final String id;
  final String batchNumber;
  final String productName;
  final String category;
  final double quantity;
  final double costPrice;
  final double retailPrice;
  final DateTime? expiryDate;
  final BatchStatus status;
  final String? shelfLocation;
  final BatchSource? source;
  final DateTime createdAt;
  final String? barcode;

  WarehouseBatch({
    required this.id,
    required this.batchNumber,
    required this.productName,
    this.category = 'Cosmetics',
    required this.quantity,
    this.costPrice = 0.0,
    this.retailPrice = 0.0,
    this.expiryDate,
    this.status = BatchStatus.receiving,
    this.shelfLocation,
    this.source,
    required this.createdAt,
    this.barcode,
  });

  // Compatibility aliases
  String get meatType => productName;
  double get weight => quantity;

  factory WarehouseBatch.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    return WarehouseBatch(
      id: map['id']?.toString() ?? '',
      batchNumber: map['batch_number']?.toString() ?? map['id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? map['item_name']?.toString() ?? map['meat_type']?.toString() ?? 'Hardware Item',
      category: map['category']?.toString() ?? 'Building Materials',
      quantity: (map['current_weight'] as num?)?.toDouble() ?? (map['initial_weight'] as num?)?.toDouble() ?? (map['weight'] as num?)?.toDouble() ?? (map['quantity'] as num?)?.toDouble() ?? 0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      retailPrice: (map['retail_price'] as num?)?.toDouble() ?? 0,
      expiryDate: map['expiry_date'] != null ? DateTime.tryParse(map['expiry_date'].toString()) : null,
      status: BatchStatus.values.firstWhere(
        (e) => e.name == map['status']?.toString(),
        orElse: () => BatchStatus.preparing,
      ),
      shelfLocation: map['shelf_location']?.toString(),
      source: map['source'] != null 
          ? BatchSource.fromJson(map['source']) 
          : BatchSource(
              name: map['source_name']?.toString() ?? 'Supplier Warehouse',
              location: map['source_location']?.toString() ?? 'HQ',
              owner: map['owner_name']?.toString() ?? 'Adom Mmoroso ENT.',
            ),
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      barcode: map['barcode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_number': batchNumber,
      'meat_type': productName,
      'category': category,
      'initial_weight': quantity,
      'current_weight': quantity,
      'cost_price': costPrice,
      'retail_price': retailPrice,
      'expiry_date': expiryDate?.toIso8601String(),
      'status': status.name,
      'shelf_location': shelfLocation,
      'source_name': source?.name,
      'source_location': source?.location,
      'owner_name': source?.owner,
      'created_at': createdAt.toIso8601String(),
      'barcode': barcode,
    };
  }
}

// Alias for UI compatibility
typedef MeatBatch = WarehouseBatch;

class StockUnit {
  final String id;
  final String batchId;
  final String productName;
  final double quantity;
  final double price;
  final DateTime? expiryDate;
  final String? barcode;

  StockUnit({
    required this.id,
    required this.batchId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.expiryDate,
    this.barcode,
  });

  factory StockUnit.fromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    return StockUnit(
      id: map['id']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      productName: map['meat_type']?.toString() ?? map['product_name']?.toString() ?? 'Unit Item',
      quantity: (map['weight'] as num?)?.toDouble() ?? (map['quantity'] as num?)?.toDouble() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      expiryDate: map['expiry_date'] != null ? DateTime.tryParse(map['expiry_date'].toString()) : null,
      barcode: map['barcode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'meat_type': productName,
      'weight': quantity,
      'price': price,
      'expiry_date': expiryDate?.toIso8601String(),
      'barcode': barcode,
    };
  }
}

// Alias for UI compatibility
typedef MeatCut = StockUnit;

enum ProductCondition { good, damaged, expired }

class IntakeItem {
  final String productId;
  final String productName;
  final String sku;
  final String category;
  final String? brand;
  final double quantityReceived;
  final String batchNumber;
  final DateTime? expiryDate;
  final ProductCondition condition;
  final String? warehouseLocation;
  final double expectedCost; // Calculated from product's costPrice * quantityReceived
  final double actualCost;   // Actual receipt cost entered by user

  IntakeItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.category,
    this.brand,
    required this.quantityReceived,
    required this.batchNumber,
    this.expiryDate,
    this.condition = ProductCondition.good,
    this.warehouseLocation,
    this.expectedCost = 0.0,
    this.actualCost = 0.0,
  });

  factory IntakeItem.fromJson(Map<String, dynamic> json) {
    return IntakeItem(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      brand: json['brand']?.toString(),
      quantityReceived: (json['quantity_received'] as num? ?? 0).toDouble(),
      batchNumber: json['batch_number']?.toString() ?? '',
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date'].toString()) : null,
      condition: ProductCondition.values.firstWhere(
        (e) => e.name == json['condition']?.toString(),
        orElse: () => ProductCondition.good,
      ),
      warehouseLocation: json['warehouse_location']?.toString(),
      expectedCost: (json['expected_cost'] as num? ?? 0.0).toDouble(),
      actualCost: (json['actual_cost'] as num? ?? json['expected_cost'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'sku': sku,
    'category': category,
    'brand': brand,
    'quantity_received': quantityReceived,
    'batch_number': batchNumber,
    'expiry_date': expiryDate?.toIso8601String(),
    'condition': condition.name,
    'warehouse_location': warehouseLocation,
    'expected_cost': expectedCost,
    'actual_cost': actualCost,
  };
}

class WarehouseIntakeRecord {
  final String id;
  final String intakeNumber;
  final DateTime date;
  final String supplierName;
  final List<IntakeItem> items;
  final String? notes;
  final String? receivedBy;
  final bool isConfirmed;
  final double rawQuantity;
  final double expectedTotalCost;
  final double actualTotalCost;

  WarehouseIntakeRecord({
    required this.id,
    required this.intakeNumber,
    required this.date,
    required this.supplierName,
    required this.items,
    this.notes,
    this.receivedBy,
    this.isConfirmed = true,
    this.rawQuantity = 0.0,
    this.expectedTotalCost = 0.0,
    this.actualTotalCost = 0.0,
  });

  double get totalQuantity {
    if (items.isNotEmpty) {
      final sum = items.fold(0.0, (s, item) => s + item.quantityReceived);
      if (sum > 0) return sum;
    }
    return rawQuantity > 0 ? rawQuantity : 0.0;
  }

  double get calculatedExpectedTotal {
    if (expectedTotalCost > 0) return expectedTotalCost;
    return items.fold(0.0, (s, i) => s + i.expectedCost);
  }

  double get calculatedActualTotal {
    if (actualTotalCost > 0) return actualTotalCost;
    return items.fold(0.0, (s, i) => s + i.actualCost);
  }

  double get costVariance => calculatedActualTotal - calculatedExpectedTotal;

  factory WarehouseIntakeRecord.fromJson(Map<String, dynamic> json) {
    List rawItems = [];
    if (json['items'] is List) {
      rawItems = json['items'] as List;
    } else if (json['items'] is String && (json['items'] as String).isNotEmpty) {
      try {
        rawItems = jsonDecode(json['items'] as String) as List? ?? [];
      } catch (_) {}
    }

    final recId = json['id']?.toString() ?? '';
    final numStr = json['intake_number']?.toString() ?? json['tag_number']?.toString() ?? (recId.length > 8 ? 'INT-${recId.substring(recId.length - 8).toUpperCase()}' : 'INT-001');
    final double rawQty = (json['initial_weight'] as num? ?? json['weight'] as num? ?? json['quantity'] as num? ?? 0.0).toDouble();

    return WarehouseIntakeRecord(
      id: recId,
      intakeNumber: numStr,
      date: json['date'] != null 
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() 
          : (json['slaughter_time'] != null 
              ? DateTime.tryParse(json['slaughter_time'].toString()) ?? DateTime.now() 
              : (json['created_at'] != null 
                  ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() 
                  : (json['slaughter_date'] != null 
                      ? DateTime.tryParse(json['slaughter_date'].toString()) ?? DateTime.now() 
                      : (json['transfer_time'] != null 
                          ? DateTime.tryParse(json['transfer_time'].toString()) ?? DateTime.now() 
                          : DateTime.now())))),
      supplierName: json['supplier_name']?.toString() ?? json['type']?.toString() ?? 'General Supplier',
      items: rawItems.map((e) => IntakeItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      notes: json['notes']?.toString() ?? json['manual_farm_tag']?.toString(),
      receivedBy: json['received_by']?.toString(),
      isConfirmed: json['is_confirmed'] ?? true,
      rawQuantity: rawQty,
      expectedTotalCost: (json['expected_total_cost'] as num? ?? 0.0).toDouble(),
      actualTotalCost: (json['actual_total_cost'] as num? ?? json['expected_total_cost'] as num? ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'intake_number': intakeNumber,
    'date': date.toIso8601String(),
    'supplier_name': supplierName,
    'items': items.map((e) => e.toJson()).toList(),
    'notes': notes,
    'received_by': receivedBy,
    'is_confirmed': isConfirmed,
    'raw_quantity': rawQuantity,
    'expected_total_cost': expectedTotalCost,
    'actual_total_cost': actualTotalCost,
  };
}

class DispatchItem {
  final String productId;
  final String productName;
  final String sku;
  final double quantityDispatched;
  final String? batchNumber;
  final DateTime? expiryDate;

  DispatchItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantityDispatched,
    this.batchNumber,
    this.expiryDate,
  });

  factory DispatchItem.fromJson(Map<String, dynamic> json) {
    return DispatchItem(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      quantityDispatched: (json['quantity_dispatched'] as num? ?? 0).toDouble(),
      batchNumber: json['batch_number']?.toString(),
      expiryDate: json['expiry_date'] != null ? DateTime.tryParse(json['expiry_date'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'sku': sku,
    'quantity_dispatched': quantityDispatched,
    'batch_number': batchNumber,
    'expiry_date': expiryDate?.toIso8601String(),
  };
}

class WarehouseDispatchRecord {
  final String id;
  final String dispatchNumber;
  final DateTime date;
  final String destinationStore;
  final List<DispatchItem> items;
  final String? notes;
  final String? dispatchedBy;
  final bool isConfirmed;
  final double rawQuantity;

  WarehouseDispatchRecord({
    required this.id,
    required this.dispatchNumber,
    required this.date,
    required this.destinationStore,
    required this.items,
    this.notes,
    this.dispatchedBy,
    this.isConfirmed = true,
    this.rawQuantity = 0.0,
  });

  double get totalQuantity {
    if (items.isNotEmpty) {
      final sum = items.fold(0.0, (s, item) => s + item.quantityDispatched);
      if (sum > 0) return sum;
    }
    return rawQuantity > 0 ? rawQuantity : 0.0;
  }

  factory WarehouseDispatchRecord.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    final recId = json['id']?.toString() ?? '';
    final numStr = json['dispatch_number']?.toString() ?? json['batch_id']?.toString() ?? (recId.length > 8 ? 'DSP-${recId.substring(recId.length - 8).toUpperCase()}' : 'DSP-001');
    final double rawQty = (json['weight'] as num? ?? json['quantity'] as num? ?? json['quantity_dispatched'] as num? ?? 0.0).toDouble();

    return WarehouseDispatchRecord(
      id: recId,
      dispatchNumber: numStr,
      date: json['date'] != null 
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() 
          : (json['transfer_time'] != null ? DateTime.tryParse(json['transfer_time'].toString()) ?? DateTime.now() : DateTime.now()),
      destinationStore: json['destination_store']?.toString() ?? json['destination']?.toString() ?? 'Adom Mmoroso ENT.',
      items: rawItems.map((e) => DispatchItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      notes: json['notes']?.toString(),
      dispatchedBy: json['dispatched_by']?.toString() ?? json['meat_type']?.toString(),
      isConfirmed: json['is_confirmed'] ?? true,
      rawQuantity: rawQty,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dispatch_number': dispatchNumber,
    'date': date.toIso8601String(),
    'destination_store': destinationStore,
    'items': items.map((e) => e.toJson()).toList(),
    'notes': notes,
    'dispatched_by': dispatchedBy,
    'is_confirmed': isConfirmed,
    'raw_quantity': rawQuantity,
  };
}
