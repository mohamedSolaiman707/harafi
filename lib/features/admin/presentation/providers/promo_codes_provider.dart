import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/promo_code.dart';

final promoCodesStreamProvider = StreamProvider<List<PromoCode>>((ref) {
  return Supabase.instance.client
      .from('promo_codes')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) => data.map((json) => PromoCode.fromJson(json)).toList());
});

final activePromoCodeProvider = StateProvider<PromoCode?>((ref) => null);

Future<PromoCode?> validateAndFetchPromoCode(String rawCode) async {
  final cleanCode = rawCode.trim().toUpperCase();
  if (cleanCode.isEmpty) return null;

  try {
    final response = await Supabase.instance.client
        .from('promo_codes')
        .select()
        .eq('code', cleanCode)
        .maybeSingle();

    if (response == null) return null;
    final promo = PromoCode.fromJson(response);
    return promo.isValid ? promo : null;
  } catch (_) {
    return null;
  }
}

/// دالة لزيادة عدد استخدامات كود الخصم في الداتابيز بمقدار 1 عند نجاح طلب العميل
Future<void> incrementPromoCodeUse(String rawCode) async {
  final cleanCode = rawCode.trim().toUpperCase();
  if (cleanCode.isEmpty) return;

  try {
    final response = await Supabase.instance.client
        .from('promo_codes')
        .select('id, current_uses')
        .eq('code', cleanCode)
        .maybeSingle();

    if (response != null) {
      final String id = response['id'].toString();
      final int currentUses = (response['current_uses'] as num?)?.toInt() ?? 0;
      await Supabase.instance.client
          .from('promo_codes')
          .update({'current_uses': currentUses + 1})
          .eq('id', id);
    }
  } catch (e) {
    debugPrint('Error incrementing promo code uses: $e');
  }
}
