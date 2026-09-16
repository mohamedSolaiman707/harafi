import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin/domain/enums/service_type.dart';

/// حالة تحميل شاشة إرسال الطلب
final requestLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// حالة تحميل إرسال التقييم
final ratingSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// التقييم المختار (عدد النجوم)
final ratingSelectedStarsProvider = StateProvider.autoDispose<int>((ref) => 0);

/// الصفحة الحالية لشيت شرح التطبيق
final onboardingPageIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

/// نوع الخدمة المحددة في شاشة طلب الخدمة
final requestSelectedServiceProvider = StateProvider.autoDispose<ServiceType?>((ref) => null);

/// أسباب التقييم المنخفض المحددة
final ratingSelectedReasonsProvider = StateProvider.autoDispose<List<String>>((ref) => []);

/// رقم الهاتف الذي تم البحث به في شاشة سجل الطلبات للعميل
final clientOrdersSearchPhoneProvider = StateProvider.autoDispose<String?>((ref) => null);
