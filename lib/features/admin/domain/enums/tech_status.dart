import 'package:json_annotation/json_annotation.dart';

enum TechStatus {
  @JsonValue('متاح')
  available('متاح'),
  @JsonValue('مشغول')
  busy('مشغول'),
  @JsonValue('إجازة')
  onLeave('إجازة');

  const TechStatus(this.label);
  final String label;
}
