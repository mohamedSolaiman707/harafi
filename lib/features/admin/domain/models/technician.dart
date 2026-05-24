import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../enums/service_type.dart';
import '../enums/tech_status.dart';

part 'technician.freezed.dart';

@freezed
class Technician with _$Technician {
  const Technician._();

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
    @JsonKey(name: 'identity_proof_url') String? identityProofUrl, // جديد: صورة إثبات الهوية
    String? bio,
    @JsonKey(name: 'total_earnings') @Default(0) int totalEarnings,
    @JsonKey(name: 'portfolio_images') @Default([]) List<String> portfolioImages,
    @JsonKey(name: 'is_verified') @Default(false) bool isVerified,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Technician;

  String get rank {
    try {
      final t = this as dynamic;
      final int jobs = t.totalJobs ?? 0;
      final double rat = t.rating ?? 0.0;
      if (jobs >= 50 && rat >= 4.7) return 'حرفي بلاتيني';
      if (jobs >= 30 && rat >= 4.5) return 'فني ذهبي';
      if (jobs >= 10) return 'فني محترف';
    } catch (_) {}
    return 'فني صاعد';
  }

  Color get rankColor {
    try {
      final t = this as dynamic;
      final int jobs = t.totalJobs ?? 0;
      final double rat = t.rating ?? 0.0;
      if (jobs >= 50 && rat >= 4.7) return const Color(0xFFE5E4E2);
      if (jobs >= 30 && rat >= 4.5) return const Color(0xFFFFD700);
      if (jobs >= 10) return const Color(0xFFC0C0C0);
    } catch (_) {}
    return const Color(0xFFCD7F32);
  }

  IconData get rankIcon {
    try {
      final t = this as dynamic;
      final int jobs = t.totalJobs ?? 0;
      if (jobs >= 50) return Icons.workspace_premium;
      if (jobs >= 30) return Icons.military_tech;
      if (jobs >= 10) return Icons.stars;
    } catch (_) {}
    return Icons.person_outline;
  }

  factory Technician.fromJson(Map<String, dynamic> json) {
    try {
      final specValue = json['spec']?.toString().trim() ?? '';
      final spec = ServiceType.values.firstWhere(
            (e) => e.label == specValue || e.name == specValue || e.toString().contains(specValue),
        orElse: () => ServiceType.plumbing,
      );

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
        identityProofUrl: json['identity_proof_url']?.toString(),
        bio: json['bio']?.toString(),
        totalEarnings: _toInt(json['total_earnings']) ?? 0,
        portfolioImages: (json['portfolio_images'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isVerified: json['is_verified'] == true,
        createdAt: json['created_at'] != null
            ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
      );
    } catch (e) {
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

  Map<String, dynamic> toJson() => technicianToJson(this);

  static Map<String, dynamic> technicianToJson(Technician tech) {
    final t = tech as dynamic;
    return {
      'id': tech.id,
      'name': tech.name,
      'phone': tech.phone,
      'spec': tech.spec.label,
      'visit_price': tech.visitPrice,
      'area': tech.area,
      'status': tech.status.label,
      'rating': tech.rating,
      'total_jobs': tech.totalJobs,
      'total_earnings': tech.totalEarnings,
      'bio': tech.bio,
      'photo_url': tech.photoUrl,
      'identity_proof_url': tech.identityProofUrl,
      'portfolio_images': t.portfolioImages ?? [],
      'is_verified': t.isVerified ?? false,
      'created_at': tech.createdAt.toIso8601String(),
    };
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
