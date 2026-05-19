import 'package:json_annotation/json_annotation.dart';

enum ServiceType {
  @JsonValue('سباكة')
  plumbing('سباكة', '🚿'),
  @JsonValue('كهرباء')
  electrical('كهرباء', '⚡'),
  @JsonValue('نجارة')
  carpentry('نجارة', '🪚');

  const ServiceType(this.label, this.icon);
  final String label;
  final String icon;
}
