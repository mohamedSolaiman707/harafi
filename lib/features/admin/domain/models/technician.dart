import 'package:freezed_annotation/freezed_annotation.dart';
import '../enums/service_type.dart';
import '../enums/tech_status.dart';

part 'technician.freezed.dart';
part 'technician.g.dart';

@freezed
class Technician with _$Technician {
  const factory Technician({
    required String id,
    required String name,
    required String phone,
    required ServiceType spec,
    @JsonKey(name: 'price_range') String? priceRange,
    @JsonKey(name: 'visit_price') @Default(50) int visitPrice,
    String? area,
    @Default(TechStatus.pending) TechStatus status,
    @Default(0.0) double rating,
    @JsonKey(name: 'total_jobs') @Default(0) int totalJobs,
    @JsonKey(name: 'photo_url') String? photoUrl,
    String? bio,
    @JsonKey(name: 'total_earnings') @Default(0) int totalEarnings,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Technician;

  factory Technician.fromJson(Map<String, dynamic> json) {
    try {
      // 1. معالجة التخصص (Spec) - دعم شامل لكل الصيغ
      final specValue = json['spec']?.toString().trim() ?? '';
      final spec = ServiceType.values.firstWhere(
        (e) => e.label == specValue || e.name == specValue || e.toString().contains(specValue),
        orElse: () => ServiceType.plumbing,
      );

      // 2. معالجة الحالة (Status) - دعم شامل لكل الصيغ
      final statusValue = json['status']?.toString().trim() ?? '';
      final status = TechStatus.values.firstWhere(
        (e) => e.label == statusValue || e.name == statusValue || e.toString().contains(statusValue),
        orElse: () => TechStatus.pending,
      );

      return Technician(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'فني جديد',
        phone: json['phone']?.toString() ?? '',
        spec: spec,
        priceRange: json['price_range']?.toString(),
        visitPrice: _toInt(json['visit_price']) ?? 50,
        area: json['area']?.toString(),
        status: status,
        rating: _toDouble(json['rating']) ?? 0.0,
        totalJobs: _toInt(json['total_jobs']) ?? 0,
        photoUrl: json['photo_url']?.toString(),
        bio: json['bio']?.toString(),
        totalEarnings: _toInt(json['total_earnings']) ?? 0,
        createdAt: json['created_at'] != null 
            ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
      );
    } catch (e) {
      // في حالة حدوث خطأ كارثي، نعود بكائن آمن لكي لا يتوقف البرنامج
      return Technician(
        id: json['id']?.toString() ?? '',
        name: 'خطأ في بيانات: ${json['name']}',
        phone: '',
        spec: ServiceType.plumbing,
        createdAt: DateTime.now(),
        status: TechStatus.pending,
      );
    }
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
