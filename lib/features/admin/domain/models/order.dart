import 'package:freezed_annotation/freezed_annotation.dart';
import '../enums/order_status.dart';
import '../enums/service_type.dart';

part 'order.freezed.dart';
part 'order.g.dart';

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    @JsonKey(name: 'tracking_code') required String trackingCode,
    @JsonKey(name: 'client_name') required String clientName,
    @JsonKey(name: 'client_phone') required String clientPhone,
    required ServiceType service,
    String? area,
    String? description,
    @JsonKey(name: 'tech_id') String? techId,
    @Default(OrderStatus.pending) OrderStatus status,
    @JsonKey(name: 'admin_notes') String? adminNotes,
    int? rating,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) =>
      _$OrderFromJson(json);
}
