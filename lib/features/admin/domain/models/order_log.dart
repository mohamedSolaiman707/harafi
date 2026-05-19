import '../enums/order_status.dart';

class OrderLog {
  final OrderStatus status;
  final DateTime timestamp;
  final String? message;

  OrderLog({
    required this.status,
    required this.timestamp,
    this.message,
  });

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    return OrderLog(
      status: OrderStatus.values.firstWhere(
        (e) => e.name == json['status'] || e.label == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      timestamp: DateTime.parse(json['created_at'] ?? json['timestamp'] ?? DateTime.now().toIso8601String()),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'timestamp': timestamp.toIso8601String(),
    'message': message,
  };
}
