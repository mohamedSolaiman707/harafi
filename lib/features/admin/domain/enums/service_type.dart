import 'package:json_annotation/json_annotation.dart';

enum ServiceCategory {
  home('صيانة منزلية', '🔧'),
  cooling('صيانة أجهزة تبريد', '❄️'),
  appliances('صيانة أجهزة كهربائية', '⚡');

  const ServiceCategory(this.label, this.icon);
  final String label;
  final String icon;
}

enum ServiceType {
  @JsonValue('سباكة')
  plumbing('سباكة', '🚿', ServiceCategory.home),
  
  @JsonValue('كهرباء')
  electrical('كهرباء', '⚡', ServiceCategory.home),
  
  @JsonValue('نجارة')
  carpentry('نجارة', '🪚', ServiceCategory.home),
  
  @JsonValue('تكييفات')
  ac('تكييفات', '❄️', ServiceCategory.cooling),

  @JsonValue('تلاجات')
  refrigerators('تلاجات', '🧊', ServiceCategory.cooling),

  @JsonValue('غسالات')
  washingMachines('غسالات', '🧺', ServiceCategory.appliances),
  
  @JsonValue('شاشات')
  screens('شاشات', '📺', ServiceCategory.appliances),

  @JsonValue('بوتاجازات')
  stoves('بوتاجازات', '🔥', ServiceCategory.appliances);

  const ServiceType(this.label, this.icon, this.category);
  final String label;
  final String icon;
  final ServiceCategory category;
}
