import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/order_message.dart';

/// بث مباشر لرسائل طلب معين باستخدام Realtime
final orderMessagesStreamProvider =
    StreamProvider.family<List<OrderMessage>, String>((ref, orderId) {
  final supabase = Supabase.instance.client;

  // StreamController لدمج الاستعلام الأولي + التحديثات الآنية
  return supabase
      .from('order_messages')
      .stream(primaryKey: ['id'])
      .eq('order_id', orderId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map((e) => OrderMessage.fromJson(e)).toList());
});

/// إرسال رسالة جديدة مع إظهار الخطأ بدل ابتلاعه
Future<void> sendOrderMessage({
  required String orderId,
  required String senderType,
  required String senderName,
  required String message,
}) async {
  final response = await Supabase.instance.client
      .from('order_messages')
      .insert({
        'order_id': orderId,
        'sender_type': senderType,
        'sender_name': senderName,
        'message': message,
      })
      .select();

  if (response.isEmpty) {
    throw Exception('فشل إرسال الرسالة، يرجى التحقق من اتصالك وإعادة المحاولة.');
  }
}
