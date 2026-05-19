import '../../features/admin/domain/models/order.dart';
import '../../features/admin/domain/models/technician.dart';

class WhatsAppUtils {
  static String formatPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '2$cleaned';
    } else if (cleaned.startsWith('1')) {
      cleaned = '20$cleaned';
    }
    return cleaned;
  }

  // استخدام Uri لضمان تشفير النصوص العربية والرموز التعبيرية بشكل صحيح
  static Uri buildUri(String phone, String message) {
    final formattedPhone = formatPhone(phone);
    return Uri.https('wa.me', '/$formattedPhone', {
      'text': message,
    });
  }

  static String clientMessage(Order order) =>
      'السلام عليكم أ/ ${order.clientName} \n'
      'بخصوص طلب ${order.service.label} الخاص بك في منطقة ${order.area ?? ""}:\n'
      'نود إبلاغك بأننا استلمنا طلبك وجاري المتابعة.\n'
      'شكراً لثقتك بـ "حرفي" ';

  static String techMessage(Order order) =>
      'السلام عليكم \nعندك شغلة جديدة:\n\n'
      ' العميل: ${order.clientName}\n'
      ' المنطقة: ${order.area ?? 'غير محدد'}\n'
      ' الخدمة: ${order.service.label}\n'
      ' المشكلة: ${order.description ?? 'غير محدد'}\n'
      ' الرقم: ${order.clientPhone}\n\n'
      'لو متاح كلمنا. شكراً ';
}
