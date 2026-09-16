class PromoCode {
  final String id;
  final String code;
  final int discountPercentage;
  final int discountAmount;
  final int maxUses;
  final int currentUses;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;

  const PromoCode({
    required this.id,
    required this.code,
    this.discountPercentage = 0,
    this.discountAmount = 0,
    this.maxUses = 100,
    this.currentUses = 0,
    this.expiresAt,
    this.isActive = true,
    required this.createdAt,
  });

  bool get isValid {
    if (!isActive) return false;
    if (currentUses >= maxUses) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  int calculateDiscount(int originalPrice) {
    if (!isValid || originalPrice <= 0) return 0;
    if (discountPercentage > 0) {
      final calculated = (originalPrice * (discountPercentage / 100)).round();
      return calculated > originalPrice ? originalPrice : calculated;
    }
    if (discountAmount > 0) {
      return discountAmount > originalPrice ? originalPrice : discountAmount;
    }
    return 0;
  }

  factory PromoCode.fromJson(Map<String, dynamic> json) {
    return PromoCode(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString().toUpperCase().trim() ?? '',
      discountPercentage: _toInt(json['discount_percentage']) ?? 0,
      discountAmount: _toInt(json['discount_amount']) ?? 0,
      maxUses: _toInt(json['max_uses']) ?? 100,
      currentUses: _toInt(json['current_uses']) ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == 'true',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code.toUpperCase().trim(),
      'discount_percentage': discountPercentage,
      'discount_amount': discountAmount,
      'max_uses': maxUses,
      'current_uses': currentUses,
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
