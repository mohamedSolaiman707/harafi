import '../enums/service_type.dart';
import '../enums/tech_status.dart';

class CreateTechnicianDto {
  final String name;
  final String phone;
  final ServiceType spec;
  final String? priceRange;
  final int? visitPrice;
  final String? area;

  CreateTechnicianDto({
    required this.name,
    required this.phone,
    required this.spec,
    this.priceRange,
    this.visitPrice,
    this.area,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'spec': spec.label,
      if (priceRange != null) 'price_range': priceRange,
      if (visitPrice != null) 'visit_price': visitPrice,
      if (area != null) 'area': area,
      'status': TechStatus.available.name,
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

  UpdateTechnicianDto({
    this.name,
    this.phone,
    this.spec,
    this.priceRange,
    this.visitPrice,
    this.area,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (spec != null) 'spec': spec!.label,
      if (priceRange != null) 'price_range': priceRange,
      if (visitPrice != null) 'visit_price': visitPrice,
      if (area != null) 'area': area,
      if (status != null) 'status': status!.name,
    };
  }
}
