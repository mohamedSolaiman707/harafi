import 'package:json_annotation/json_annotation.dart';

enum OrderStatus {
  @JsonValue('بانتظار المراجعة')
  pending('بانتظار المراجعة'),
  
  @JsonValue('تم تعيين فني')
  assigned('تم تعيين فني'),
  
  @JsonValue('الفني في الطريق')
  onTheWay('الفني في الطريق'),
  
  @JsonValue('بدأ العمل')
  started('بدأ العمل'),
  
  @JsonValue('مكتمل')
  completed('مكتمل'),
  
  @JsonValue('ملغي')
  cancelled('ملغي');

  const OrderStatus(this.label);
  final String label;
}
