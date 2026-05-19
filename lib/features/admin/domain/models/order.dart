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
  final int? rating;
  final String? ratingComment;
  final DateTime? estimatedArrival;
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
    this.rating,
    this.ratingComment,
    this.estimatedArrival,
    this.logs = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // التحقق من نوع الخدمة ودعم العربي والإنجليزي
    final serviceValue = json['service']?.toString() ?? '';
    final service = ServiceType.values.firstWhere(
      (e) => e.name == serviceValue || e.label == serviceValue,
      orElse: () => ServiceType.plumbing,
    );

    // منطق ذكي لقراءة الحالة من قاعدة البيانات (يدعم كل القيم في صورتك)
    final statusValue = json['status']?.toString() ?? '';
    final status = OrderStatus.values.firstWhere(
      (e) => e.name == statusValue || 
             e.label == statusValue || 
             (statusValue == 'جاري' && e == OrderStatus.pending) ||
             (statusValue == 'on_the_way' && e == OrderStatus.onTheWay),
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
      rating: json['rating'] as int?,
      ratingComment: json['rating_comment'],
      estimatedArrival: json['estimated_arrival'] != null 
          ? DateTime.parse(json['estimated_arrival']) 
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
    'service': service.label, // تخزين الخدمة بالعربي كما في DB
    'area': area,
    'description': description,
    'tech_id': techId,
    'status': status.label, // تخزين الحالة بالعربي ليتوافق مع Enum في Supabase
    'final_price': finalPrice,
    'admin_notes': adminNotes,
    'rating': rating,
    'rating_comment': ratingComment,
    'estimated_arrival': estimatedArrival?.toIso8601String(),
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
    int? rating,
    String? ratingComment,
    DateTime? estimatedArrival,
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
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      logs: logs ?? this.logs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
