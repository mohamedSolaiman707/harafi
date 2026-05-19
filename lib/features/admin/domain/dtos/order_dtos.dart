import '../enums/service_type.dart';

class CreateOrderDto {
  final String clientName;
  final String clientPhone;
  final ServiceType service;
  final String? area;
  final String? description;

  CreateOrderDto({
    required this.clientName,
    required this.clientPhone,
    required this.service,
    this.area,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'client_name': clientName,
      'client_phone': clientPhone,
      'service': service.label,
      if (area != null) 'area': area,
      if (description != null) 'description': description,
    };
  }
}
