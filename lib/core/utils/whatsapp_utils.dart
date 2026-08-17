import '../../features/admin/domain/models/order.dart';

class WhatsAppUtils {
  static const _baseUrl = 'https://wa.me/';

  static String formatPhone(String phone) {
    String n = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (n.startsWith('0')) n = '2$n';
    if (n.startsWith('1')) n = '20$n';
    if (!n.startsWith('2')) n = '2$n'; 
    return n;
  }

  static Uri buildUri(String phone, String message) {
    final formatted = formatPhone(phone);
    final encodedMsg = Uri.encodeComponent(message);
    
    // الرابط العالمي wa.me هو الأفضل والأكثر احترافية لأنه يفتح التطبيق 
    // إذا كان موجوداً، أو يفتح صفحة ويب إذا لم يكن موجوداً (Fallback).
    return Uri.parse('$_baseUrl$formatted?text=$encodedMsg');
  }

  // الرسائل
  static String orderCreated(String trackingCode) =>
      'السلام عليكم 🙏\n'
      'تم استلام طلبك في حرفي ✅\n'
      'كود التتبع: $trackingCode\n'
      'تابع طلبك: https://7arafi.com/track/$trackingCode';

  static String techAssignedClient(String techName, String trackingCode) =>
      'تم تعيين الفني $techName لطلبك 🔧\n'
      'هيتواصل معاك قريباً.\n'
      'تابع: https://7arafi.com/track/$trackingCode';

  static String techAssignedTech(Order order) =>
      'عندك شغلة جديدة في حرفي 🔧\n\n'
      '👤 العميل: ${order.clientName}\n'
      '📍 المنطقة: ${order.area ?? "غير محدد"}\n'
      '🔧 الخدمة: ${order.service.label}\n'
      '📝 المشكلة: ${order.description ?? "بدون وصف"}\n'
      '📞 الرقم: ${order.clientPhone}';

  static String orderCompleted(String trackingCode) =>
      'تم إنجاز طلبك بنجاح ✅\n'
      'يسعدنا تقييم الخدمة:\n'
      'https://7arafi.com/track/$trackingCode';
}
