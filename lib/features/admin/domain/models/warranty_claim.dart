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
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
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
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isRejected => status == 'rejected';
  bool get isInvestigating => status == 'investigating';

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
      adminNotes: json['admin_notes']?.toString(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
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
      'updated_at': updatedAt.toIso8601String(),
    };
    if (techId != null) map['tech_id'] = techId;
    if (rejectionReason != null) map['rejection_reason'] = rejectionReason;
    if (adminNotes != null) map['admin_notes'] = adminNotes;
    if (resolvedAt != null) map['resolved_at'] = resolvedAt?.toIso8601String();
    return map;
  }

  WarrantyClaim copyWith({
    String? status,
    String? rejectionReason,
    String? adminNotes,
    DateTime? updatedAt,
    DateTime? resolvedAt,
  }) {
    return WarrantyClaim(
      id: id,
      orderId: orderId,
      trackingCode: trackingCode,
      clientName: clientName,
      clientPhone: clientPhone,
      techId: techId,
      issueDescription: issueDescription,
      claimImages: claimImages,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
