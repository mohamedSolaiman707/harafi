import '../enums/order_status.dart';
import '../enums/service_type.dart';
import 'order_log.dart';

class Order {
  final String id;
  final String trackingCode;
  final String clientName;
  final String clientPhone;
  final ServiceType service;
  final String? area;
  final String? description;
  final String? techId;
  final OrderStatus status;
  final int? finalPrice;
  final String? adminNotes;
  final String? techNotes;
  final int? rating;
  final String? ratingComment;
  final DateTime? estimatedArrival;
  final DateTime? completedAt;
  final List<OrderLog> logs;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.trackingCode,
    required this.clientName,
    required this.clientPhone,
    required this.service,
    this.area,
    this.description,
    this.techId,
    this.status = OrderStatus.pending,
    this.finalPrice,
    this.adminNotes,
    this.techNotes,
    this.rating,
    this.ratingComment,
    this.estimatedArrival,
    this.completedAt,
    this.logs = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // معالجة نوع الخدمة (يدعم العربي والإنجليزي)
    final serviceValue = json['service']?.toString() ?? '';
    final service = ServiceType.values.firstWhere(
      (e) => e.label == serviceValue || e.name == serviceValue,
      orElse: () => ServiceType.plumbing,
    );

    // معالجة الحالة (يدعم كل الصيغ الممكنة)
    final statusValue = json['status']?.toString() ?? '';
    final status = OrderStatus.values.firstWhere(
      (e) => e.label == statusValue || 
             e.name == statusValue || 
             (statusValue == 'pending' && e == OrderStatus.pending),
      orElse: () => OrderStatus.pending,
    );

    return Order(
      id: json['id']?.toString() ?? '',
      trackingCode: json['tracking_code']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? 'عميل غير معروف',
      clientPhone: json['client_phone']?.toString() ?? '',
      service: service,
      area: json['area']?.toString(),
      description: json['description']?.toString(),
      techId: json['tech_id']?.toString(),
      status: status,
      finalPrice: (json['final_price'] as num?)?.toInt(),
      adminNotes: json['admin_notes']?.toString(),
      techNotes: json['tech_notes']?.toString(),
      rating: (json['rating'] as num?)?.toInt(),
      ratingComment: json['rating_comment']?.toString(),
      estimatedArrival: json['estimated_arrival'] != null ? DateTime.tryParse(json['estimated_arrival'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      logs: (json['order_logs'] as List?)
              ?.map((e) => OrderLog.fromJson(e))
              .toList() ?? [],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'client_name': clientName,
    'client_phone': clientPhone,
    'service': service.label,
    'area': area,
    'description': description,
    'tech_id': techId,
    'status': status.label,
    'final_price': finalPrice,
    'admin_notes': adminNotes,
    'tech_notes': techNotes,
    'rating': rating,
    'rating_comment': ratingComment,
    'estimated_arrival': estimatedArrival?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  Order copyWith({
    String? id,
    String? trackingCode,
    String? clientName,
    String? clientPhone,
    ServiceType? service,
    String? area,
    String? description,
    String? techId,
    OrderStatus? status,
    int? finalPrice,
    String? adminNotes,
    String? techNotes,
    int? rating,
    String? ratingComment,
    DateTime? estimatedArrival,
    DateTime? completedAt,
    List<OrderLog>? logs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      trackingCode: trackingCode ?? this.trackingCode,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      service: service ?? this.service,
      area: area ?? this.area,
      description: description ?? this.description,
      techId: techId ?? this.techId,
      status: status ?? this.status,
      finalPrice: finalPrice ?? this.finalPrice,
      adminNotes: adminNotes ?? this.adminNotes,
      techNotes: techNotes ?? this.techNotes,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      completedAt: completedAt ?? this.completedAt,
      logs: logs ?? this.logs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
