import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/location_provider.dart';

/// كويري البحث في الشاشة الرئيسية
final homeSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// كود التتبع المحفوظ آخر مرة
final lastTrackedCodeProvider = FutureProvider.autoDispose<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('last_tracked_code');
});

/// المحافظة المحددة في شيت اختيار الموقع بالشاشة الرئيسية
final homeSelectedGovProvider = StateProvider.autoDispose<String>((ref) {
  final currentLocation = ref.watch(userLocationProvider);
  return currentLocation.governorate;
});

/// حالة تركيز حقل البحث في الشاشة الرئيسية
final homeSearchIsFocusedProvider = StateProvider.autoDispose<bool>((ref) => false);

/// حالة وجود نص في حقل البحث بالشاشة الرئيسية
final homeSearchHasTextProvider = StateProvider.autoDispose<bool>((ref) => false);
