// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrderImpl _$$OrderImplFromJson(Map<String, dynamic> json) => _$OrderImpl(
  id: json['id'] as String,
  trackingCode: json['tracking_code'] as String,
  clientName: json['client_name'] as String,
  clientPhone: json['client_phone'] as String,
  service: $enumDecode(_$ServiceTypeEnumMap, json['service']),
  area: json['area'] as String?,
  description: json['description'] as String?,
  techId: json['tech_id'] as String?,
  status:
      $enumDecodeNullable(_$OrderStatusEnumMap, json['status']) ??
      OrderStatus.pending,
  adminNotes: json['admin_notes'] as String?,
  rating: (json['rating'] as num?)?.toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$$OrderImplToJson(_$OrderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tracking_code': instance.trackingCode,
      'client_name': instance.clientName,
      'client_phone': instance.clientPhone,
      'service': _$ServiceTypeEnumMap[instance.service]!,
      'area': instance.area,
      'description': instance.description,
      'tech_id': instance.techId,
      'status': _$OrderStatusEnumMap[instance.status]!,
      'admin_notes': instance.adminNotes,
      'rating': instance.rating,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$ServiceTypeEnumMap = {
  ServiceType.plumbing: 'سباكة',
  ServiceType.electrical: 'كهرباء',
  ServiceType.carpentry: 'نجارة',
};

const _$OrderStatusEnumMap = {
  OrderStatus.pending: 'جاري',
  OrderStatus.completed: 'مكتمل',
  OrderStatus.cancelled: 'ملغي',
};
