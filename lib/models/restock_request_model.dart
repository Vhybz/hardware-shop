class ProductRestockRequest {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String productId;
  final String productName;
  final String? productSku;
  final String? variantOrNotes; // Size, Shade, Packaging (e.g. 500ml, Boxes, Shade 02)
  final String status; // 'pending', 'notified', 'fulfilled', 'cancelled'
  final String? branchCode;
  final DateTime createdAt;
  final DateTime? notifiedAt;

  ProductRestockRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.productId,
    required this.productName,
    this.productSku,
    this.variantOrNotes,
    this.status = 'pending',
    this.branchCode,
    required this.createdAt,
    this.notifiedAt,
  });

  bool get isPending => status == 'pending';
  bool get isNotified => status == 'notified';

  ProductRestockRequest copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? productId,
    String? productName,
    String? productSku,
    String? variantOrNotes,
    String? status,
    String? branchCode,
    DateTime? createdAt,
    DateTime? notifiedAt,
  }) {
    return ProductRestockRequest(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      variantOrNotes: variantOrNotes ?? this.variantOrNotes,
      status: status ?? this.status,
      branchCode: branchCode ?? this.branchCode,
      createdAt: createdAt ?? this.createdAt,
      notifiedAt: notifiedAt ?? this.notifiedAt,
    );
  }

  factory ProductRestockRequest.fromJson(Map<String, dynamic> json) {
    return ProductRestockRequest(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Customer',
      customerPhone: json['customer_phone']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Product',
      productSku: json['product_sku']?.toString(),
      variantOrNotes: json['variant_or_notes']?.toString() ?? json['notes']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      branchCode: json['branch_code']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      notifiedAt: json['notified_at'] != null ? DateTime.tryParse(json['notified_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'product_id': productId,
    'product_name': productName,
    'product_sku': productSku,
    'variant_or_notes': variantOrNotes,
    'status': status,
    'branch_code': branchCode,
    'created_at': createdAt.toIso8601String(),
    'notified_at': notifiedAt?.toIso8601String(),
  };
}
