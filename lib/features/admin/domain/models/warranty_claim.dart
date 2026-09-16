class WarrantyClaim {
  final String id;
  final String orderId;
  final String trackingCode;
  final String clientName;
  final String clientPhone;
  final String? techId;
  final String issueDescription;
  final List<String> claimImages;
  final String status; // pending, investigating, resolved, rejected
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const WarrantyClaim({
    required this.id,
    required this.orderId,
    required this.trackingCode,
    required this.clientName,
    required this.clientPhone,
    this.techId,
    required this.issueDescription,
    this.claimImages = const [],
    this.status = 'pending',
    this.rejectionReason,
    required this.createdAt,
    this.resolvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isRejected => status == 'rejected';

  factory WarrantyClaim.fromJson(Map<String, dynamic> json) {
    return WarrantyClaim(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      trackingCode: json['tracking_code']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      clientPhone: json['client_phone']?.toString() ?? '',
      techId: json['tech_id']?.toString(),
      issueDescription: json['issue_description']?.toString() ?? '',
      claimImages: (json['claim_images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'order_id': orderId,
      'tracking_code': trackingCode,
      'client_name': clientName,
      'client_phone': clientPhone,
      'issue_description': issueDescription,
      'claim_images': claimImages,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
    if (techId != null) map['tech_id'] = techId;
    if (rejectionReason != null) map['rejection_reason'] = rejectionReason;
    if (resolvedAt != null) map['resolved_at'] = resolvedAt?.toIso8601String();
    return map;
  }
}
