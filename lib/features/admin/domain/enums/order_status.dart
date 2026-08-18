import 'package:json_annotation/json_annotation.dart';

enum OrderStatus {
  @JsonValue('بانتظار المراجعة')
  pending('بانتظار المراجعة'),
  
  @JsonValue('بانتظار موافقة الفني')
  assigned('بانتظار موافقة الفني'),
  
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
