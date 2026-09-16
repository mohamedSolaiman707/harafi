import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../../core/constants/app_constants.dart';

// ─── تسجيل الفني ──────────────────────────────────────────────────────────────

/// حالة تحميل شاشة تسجيل الفني
final techRegisterLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// التخصص المختار في شاشة التسجيل
final techRegisterSpecProvider = StateProvider<ServiceType?>((ref) => null);

/// المحافظة المختارة في شاشة التسجيل
final techRegisterGovProvider = StateProvider<String>((ref) {
  return AppConstants.governoratesAndCities.keys.first;
});

/// المدينة المختارة في شاشة التسجيل
final techRegisterCityProvider = StateProvider<String>((ref) {
  final gov = ref.watch(techRegisterGovProvider);
  return AppConstants.governoratesAndCities[gov]?.first ?? '';
});

/// صورة وجه البطاقة الشخصية
final techRegisterIdFrontProvider = StateProvider<XFile?>((ref) => null);

/// صورة ظهر البطاقة الشخصية
final techRegisterIdBackProvider = StateProvider<XFile?>((ref) => null);

/// صورة صحيفة الحالة الجنائية (الفيش والتشبيه)
final techRegisterCriminalRecordProvider = StateProvider<XFile?>((ref) => null);

/// صورة إثبات الهوية (توفير التوافقية مع الكود السابق)
final techRegisterIdProofProvider = StateProvider<XFile?>((ref) => null);

/// الصورة الشخصية للفني (تظهر في الملف الشخصي وللعملاء)
final techRegisterAvatarProvider = StateProvider<XFile?>((ref) => null);

/// خطوة التسجيل الحالية (0 = الحساب، 1 = المجال، 2 = التوثيق)
final techRegisterStepProvider = StateProvider.autoDispose<int>((ref) => 0);


// ─── الملف الشخصي ─────────────────────────────────────────────────────────────

/// وضع التعديل في الملف الشخصي
final techProfileEditingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// حالة تحميل حفظ الملف الشخصي
final techProfileLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// حالة رفع صورة الملف الشخصي
final techProfileAvatarUploadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// حالة رفع صورة معرض الأعمال
final techProfilePortfolioUploadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// المحافظة المختارة في الملف الشخصي
final techProfileGovProvider = StateProvider.autoDispose<String?>((ref) => null);

/// المدينة/المنطقة المختارة في الملف الشخصي
final techProfileAreaProvider = StateProvider.autoDispose<String?>((ref) => null);

// ─── تفاصيل الطلب (الشاشة المخصصة للفني) ─────────────────────────────────────

/// حالة تحميل إنهاء/رفض الطلب في الشيت
final techOrderSheetLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// قائمة الصور المختارة في شيت إنهاء الطلب
final techOrderCompletionImagesProvider =
    StateProvider.autoDispose<List<dynamic>>((ref) => []);

/// قائمة الأسباب المحددة للاعتذار في شيت الاعتذار
final techOrderRejectionReasonsProvider =
    StateProvider.autoDispose<List<String>>((ref) => []);
