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
  final String? techNotes; // تقرير الفني عن العمل
  final int? rating;
  final String? ratingComment;
  final DateTime? estimatedArrival;
  final DateTime? completedAt; // وقت الإنجاز الفعلي
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
    final serviceValue = json['service']?.toString() ?? '';
    final service = ServiceType.values.firstWhere(
      (e) => e.name == serviceValue || e.label == serviceValue,
      orElse: () => ServiceType.plumbing,
    );

    final statusValue = json['status']?.toString() ?? '';
    final status = OrderStatus.values.firstWhere(
      (e) => e.name == statusValue || e.label == statusValue,
      orElse: () => OrderStatus.pending,
    );

    return Order(
      id: json['id']?.toString() ?? '',
      trackingCode: json['tracking_code']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      clientPhone: json['client_phone']?.toString() ?? '',
      service: service,
      area: json['area'],
      description: json['description'],
      techId: json['tech_id']?.toString(),
      status: status,
      finalPrice: json['final_price'] as int?,
      adminNotes: json['admin_notes'],
      techNotes: json['tech_notes'],
      rating: json['rating'] as int?,
      ratingComment: json['rating_comment'],
      estimatedArrival: json['estimated_arrival'] != null 
          ? DateTime.parse(json['estimated_arrival']) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      logs: (json['order_logs'] as List?)
              ?.map((e) => OrderLog.fromJson(e))
              .toList() ?? 
          [],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
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
