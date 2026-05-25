import '../enums/service_type.dart';
import '../enums/tech_status.dart';

class CreateTechnicianDto {
  final String? id; 
  final String name;
  final String phone;
  final ServiceType spec;
  final String? priceRange;
  final int? visitPrice;
  final String? area;
  final String? photoUrl;
  final String? bio;
  final bool isVerified;

  CreateTechnicianDto({
    this.id,
    required this.name,
    required this.phone,
    required this.spec,
    this.priceRange,
    this.visitPrice,
    this.area,
    this.photoUrl,
    this.bio,
    this.isVerified = false,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'spec': spec.label,
      if (priceRange != null) 'price_range': priceRange,
      if (visitPrice != null) 'visit_price': visitPrice,
      if (area != null) 'area': area,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (bio != null) 'bio': bio,
      'is_verified': isVerified,
      'status': TechStatus.pending.label,
      'total_earnings': 0,
      'total_jobs': 0,
      'rating': 0.0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

class UpdateTechnicianDto {
  final String? name;
  final String? phone;
  final ServiceType? spec;
  final String? priceRange;
  final int? visitPrice;
  final String? area;
  final TechStatus? status;
  final String? photoUrl;
  final String? bio;
  final int? totalEarnings;
  final bool? isVerified;

  UpdateTechnicianDto({
    this.name,
    this.phone,
    this.spec,
    this.priceRange,
    this.visitPrice,
    this.area,
    this.status,
    this.photoUrl,
    this.bio,
    this.totalEarnings,
    this.isVerified,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (spec != null) 'spec': spec!.label,
      if (priceRange != null) 'price_range': priceRange,
      if (visitPrice != null) 'visit_price': visitPrice,
      if (area != null) 'area': area,
      if (status != null) 'status': status!.label,
      if (photoUrl != null) 'photo_url': photoUrl,
      if (bio != null) 'bio': bio,
      if (totalEarnings != null) 'total_earnings': totalEarnings,
      if (isVerified != null) 'is_verified': isVerified,
    };
  }
}
