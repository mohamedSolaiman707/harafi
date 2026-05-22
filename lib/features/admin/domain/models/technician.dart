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

  factory Technician.fromJson(Map<String, dynamic> json) =>
      _$TechnicianFromJson(json);
}
