import 'package:json_annotation/json_annotation.dart';

enum OrderStatus {
  @JsonValue('جاري')
  pending('جاري'),
  @JsonValue('مكتمل')
  completed('مكتمل'),
  @JsonValue('ملغي')
  cancelled('ملغي');

  const OrderStatus(this.label);
  final String label;
}
