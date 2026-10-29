import 'product.dart';

enum ReturnReason { changedMind, defective, expired, damaged, wrongItem }

class ReturnedItem {
  final Product product;
  final double quantityReturned;
  final double priceAtSale;
  final String? selectedUnit;
  final ReturnReason reason;
  final bool returnToStock; // true = add back to sellable stock; false = log to damage/waste

  ReturnedItem({
    required this.product,
    required this.quantityReturned,
    required this.priceAtSale,
    this.selectedUnit,
    this.reason = ReturnReason.changedMind,
    this.returnToStock = true,
  });

  double get totalRefund => quantityReturned * priceAtSale;

  factory ReturnedItem.fromJson(Map<String, dynamic> json) {
    return ReturnedItem(
      product: Product.fromJson(json['product']),
      quantityReturned: (json['quantity_returned'] as num? ?? 0.0).toDouble(),
      priceAtSale: (json['price_at_sale'] as num? ?? 0.0).toDouble(),
      selectedUnit: json['selected_unit']?.toString(),
      reason: ReturnReason.values.firstWhere(
        (e) => e.name == json['reason']?.toString(),
        orElse: () => ReturnReason.changedMind,
      ),
      returnToStock: json['return_to_stock'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity_returned': quantityReturned,
    'price_at_sale': priceAtSale,
    'selected_unit': selectedUnit,
    'reason': reason.name,
    'return_to_stock': returnToStock,
  };
}

class SaleReturnRecord {
  final String id;
  final String returnNumber;
  final String originalSaleId;
  final String? customerName;
  final String? customerPhone;
  final List<ReturnedItem> items;
  final double totalRefundAmount; // Net amount (positive = refund to customer; negative = topup paid by customer)
  final String refundMethod; // 'cash', 'mobileMoney', 'store_credit'
  final String processedBy;
  final String? branchCode;
  final DateTime createdAt;
  final String? replacementProductId;
  final String? replacementProductName;
  final double? replacementQuantity;
  final double? replacementTotalCost;

  SaleReturnRecord({
    required this.id,
    required this.returnNumber,
    required this.originalSaleId,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.totalRefundAmount,
    this.refundMethod = 'cash',
    required this.processedBy,
    this.branchCode,
    required this.createdAt,
    this.replacementProductId,
    this.replacementProductName,
    this.replacementQuantity,
    this.replacementTotalCost,
  });

  bool get isProductSwap => replacementProductName != null && replacementProductName!.isNotEmpty;

  factory SaleReturnRecord.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return SaleReturnRecord(
      id: json['id']?.toString() ?? '',
      returnNumber: json['return_number']?.toString() ?? 'RET-001',
      originalSaleId: json['original_sale_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      items: rawItems.map((e) => ReturnedItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      totalRefundAmount: (json['total_refund_amount'] as num? ?? 0.0).toDouble(),
      refundMethod: json['refund_method']?.toString() ?? 'cash',
      processedBy: json['processed_by']?.toString() ?? 'Staff',
      branchCode: json['branch_code']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      replacementProductId: json['replacement_product_id']?.toString(),
      replacementProductName: json['replacement_product_name']?.toString(),
      replacementQuantity: (json['replacement_quantity'] as num?)?.toDouble(),
      replacementTotalCost: (json['replacement_total_cost'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'return_number': returnNumber,
    'original_sale_id': originalSaleId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'items': items.map((e) => e.toJson()).toList(),
    'total_refund_amount': totalRefundAmount,
    'refund_method': refundMethod,
    'processed_by': processedBy,
    'branch_code': branchCode,
    'created_at': createdAt.toIso8601String(),
    'replacement_product_id': replacementProductId,
    'replacement_product_name': replacementProductName,
    'replacement_quantity': replacementQuantity,
    'replacement_total_cost': replacementTotalCost,
  };
}
