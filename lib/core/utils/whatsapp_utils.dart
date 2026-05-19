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

  static String buildLink(String phone, String message) {
    final formatted = formatPhone(phone);
    final encoded = Uri.encodeComponent(message);
    return 'https://wa.me/$formatted?text=$encoded';
  }

  static String clientMessage(Order order, Technician? tech) =>
      'السلام عليكم ${order.clientName} 🙏\n'
      'بخصوص طلب ${order.service.label} بتاعك —\n'
      'تم تعيين الفني ${tech?.name ?? ''} وهييجيلك قريباً.\n'
      'لو في أي استفسار كلمنا. شكراً 😊';

  static String techMessage(Order order) =>
      'السلام عليكم 🙏\nعندك شغلة جديدة:\n\n'
      '👤 العميل: ${order.clientName}\n'
      '📍 المنطقة: ${order.area ?? 'غير محدد'}\n'
      '🔧 الخدمة: ${order.service.label}\n'
      '📝 المشكلة: ${order.description ?? 'غير محدد'}\n'
      '📞 الرقم: ${order.clientPhone}\n\n'
      'لو متاح كلمنا. شكراً 🙏';
}
