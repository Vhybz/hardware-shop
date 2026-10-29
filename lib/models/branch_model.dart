class Branch {
  final String code;
  final String name;
  final String location;
  final String? adminId;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime createdAt;

  Branch({
    required this.code,
    required this.name,
    required this.location,
    this.adminId,
    this.latitude = 7.3349,
    this.longitude = -2.3123,
    this.radiusMeters = 500.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      adminId: json['admin_id'],
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : 7.3349,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : -2.3123,
      radiusMeters: (json['radius_meters'] is num) ? (json['radius_meters'] as num).toDouble() : 500.0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'location': location,
      if (adminId != null) 'admin_id': adminId,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
