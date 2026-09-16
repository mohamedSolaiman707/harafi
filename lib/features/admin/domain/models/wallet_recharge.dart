class WalletRecharge {
  final String id;
  final String techId;
  final String techName;
  final String techPhone;
  final int amount;
  final String senderPhone;
  final String receiptUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final String paymentMethod; // 'vodafone_cash', 'fawry'
  final String? fawryRefCode;
  final bool isAutoProcessed;
  final DateTime createdAt;
  final DateTime? approvedAt;

  const WalletRecharge({
    required this.id,
    required this.techId,
    required this.techName,
    required this.techPhone,
    required this.amount,
    required this.senderPhone,
    required this.receiptUrl,
    this.status = 'pending',
    this.rejectionReason,
    this.paymentMethod = 'vodafone_cash',
    this.fawryRefCode,
    this.isAutoProcessed = false,
    required this.createdAt,
    this.approvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isFawry => paymentMethod == 'fawry';

  factory WalletRecharge.fromJson(Map<String, dynamic> json) {
    return WalletRecharge(
      id: json['id']?.toString() ?? '',
      techId: json['tech_id']?.toString() ?? '',
      techName: json['tech_name']?.toString() ?? '',
      techPhone: json['tech_phone']?.toString() ?? '',
      amount: _toInt(json['amount']) ?? 0,
      senderPhone: json['sender_phone']?.toString() ?? '',
      receiptUrl: json['receipt_url']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      paymentMethod: json['payment_method']?.toString() ?? 'vodafone_cash',
      fawryRefCode: json['fawry_ref_code']?.toString(),
      isAutoProcessed: json['is_auto_processed'] == true,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tech_id': techId,
      'tech_name': techName,
      'tech_phone': techPhone,
      'amount': amount,
      'sender_phone': senderPhone,
      'receipt_url': receiptUrl,
      'status': status,
      'rejection_reason': rejectionReason,
      'payment_method': paymentMethod,
      'fawry_ref_code': fawryRefCode,
      'is_auto_processed': isAutoProcessed,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
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
