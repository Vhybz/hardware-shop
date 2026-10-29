class SupplierReturnedItem {
  final String productId;
  final String productName;
  final String sku;
  final double quantityReturned;
  final String batchNumber;
  final String reason;

  SupplierReturnedItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantityReturned,
    required this.batchNumber,
    this.reason = 'damaged_in_transit',
  });

  factory SupplierReturnedItem.fromJson(Map<String, dynamic> json) {
    return SupplierReturnedItem(
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Product',
      sku: json['sku']?.toString() ?? '',
      quantityReturned: (json['quantity_returned'] as num? ?? 0.0).toDouble(),
      batchNumber: json['batch_number']?.toString() ?? '',
      reason: json['reason']?.toString() ?? 'damaged_in_transit',
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_name': productName,
    'sku': sku,
    'quantity_returned': quantityReturned,
    'batch_number': batchNumber,
    'reason': reason,
  };
}

class SupplierReturnRecord {
  final String id;
  final String returnNumber;
  final String intakeNumber;
  final String supplierName;
  final List<SupplierReturnedItem> items;
  final double totalQuantity;
  final String reason;
  final String processedBy;
  final String? branchCode;
  final DateTime createdAt;

  SupplierReturnRecord({
    required this.id,
    required this.returnNumber,
    required this.intakeNumber,
    required this.supplierName,
    required this.items,
    required this.totalQuantity,
    this.reason = 'damaged_in_transit',
    required this.processedBy,
    this.branchCode,
    required this.createdAt,
  });

  factory SupplierReturnRecord.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return SupplierReturnRecord(
      id: json['id']?.toString() ?? '',
      returnNumber: json['return_number']?.toString() ?? 'SRN-001',
      intakeNumber: json['intake_number']?.toString() ?? '',
      supplierName: json['supplier_name']?.toString() ?? 'Supplier',
      items: rawItems.map((e) => SupplierReturnedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      totalQuantity: (json['total_quantity'] as num? ?? 0.0).toDouble(),
      reason: json['reason']?.toString() ?? 'damaged_in_transit',
      processedBy: json['processed_by']?.toString() ?? 'Staff',
      branchCode: json['branch_code']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'return_number': returnNumber,
    'intake_number': intakeNumber,
    'supplier_name': supplierName,
    'items': items.map((e) => e.toJson()).toList(),
    'total_quantity': totalQuantity,
    'reason': reason,
    'processed_by': processedBy,
    'branch_code': branchCode,
    'created_at': createdAt.toIso8601String(),
  };
}
