// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'technician.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TechnicianImpl _$$TechnicianImplFromJson(Map<String, dynamic> json) =>
    _$TechnicianImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      spec: $enumDecode(_$ServiceTypeEnumMap, json['spec']),
      priceRange: json['price_range'] as String?,
      visitPrice: (json['visit_price'] as num?)?.toInt() ?? 50,
      area: json['area'] as String?,
      status:
          $enumDecodeNullable(_$TechStatusEnumMap, json['status']) ??
          TechStatus.available,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalJobs: (json['total_jobs'] as num?)?.toInt() ?? 0,
      photoUrl: json['photo_url'] as String?,
      bio: json['bio'] as String?,
      totalEarnings: (json['total_earnings'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$TechnicianImplToJson(_$TechnicianImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'spec': _$ServiceTypeEnumMap[instance.spec]!,
      'price_range': instance.priceRange,
      'visit_price': instance.visitPrice,
      'area': instance.area,
      'status': _$TechStatusEnumMap[instance.status]!,
      'rating': instance.rating,
      'total_jobs': instance.totalJobs,
      'photo_url': instance.photoUrl,
      'bio': instance.bio,
      'total_earnings': instance.totalEarnings,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$ServiceTypeEnumMap = {
  ServiceType.plumbing: 'سباكة',
  ServiceType.electrical: 'كهرباء',
  ServiceType.carpentry: 'نجارة',
  ServiceType.ac: 'تكييفات',
  ServiceType.refrigerators: 'تلاجات',
  ServiceType.washingMachines: 'غسالات',
  ServiceType.screens: 'شاشات',
  ServiceType.stoves: 'بوتاجازات',
};

const _$TechStatusEnumMap = {
  TechStatus.available: 'متاح',
  TechStatus.busy: 'مشغول',
  TechStatus.onLeave: 'إجازة',
};
