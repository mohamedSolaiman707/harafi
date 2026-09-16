import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../domain/models/promo_code.dart';
import '../providers/promo_codes_provider.dart';

class PromoCodesScreen extends ConsumerWidget {
  const PromoCodesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promoCodesAsync = ref.watch(promoCodesStreamProvider);
    final width = MediaQuery.of(context).size.width;
    final sidePadding = width > 1200 ? AppSpacing.xl : AppSpacing.lg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة البرومو كود والخصومات 🎁'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => _showCreatePromoDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('كود جديد'),
            ),
          ),
        ],
      ),
      body: promoCodesAsync.when(
        data: (codes) {
          if (codes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('لا توجد أكواد خصم حالية ℹ️'),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'إنشاء أول كود خصم',
                    onTap: () => _showCreatePromoDialog(context, ref),
                    variant: ButtonVariant.ghost,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(sidePadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: codes.length,
                  itemBuilder: (context, index) {
                    final item = codes[index];
                    return _PromoCodeCard(promo: item);
                  },
                ),
              ),
            ),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => AppErrorWidget(
          message: 'خطأ في تحميل الكوبونات',
          error: e,
          onRetry: () => ref.invalidate(promoCodesStreamProvider),
        ),
      ),
    );
  }

  void _showCreatePromoDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _CreatePromoDialog(),
    );
  }
}

class _PromoCodeCard extends ConsumerWidget {
  final PromoCode promo;
  const _PromoCodeCard({required this.promo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isValid = promo.isValid;
    final String discountLabel = promo.discountPercentage > 0
        ? 'خصم ${promo.discountPercentage}%'
        : 'خصم ${promo.discountAmount} ج.م';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        color: isValid ? AppColors.surface1 : AppColors.surface2.withValues(alpha: 0.5),
        border: Border.all(
          color: isValid ? AppColors.gold.withValues(alpha: 0.5) : AppColors.borderSubtle,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isValid ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surface3,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.confirmation_number_rounded,
                color: isValid ? AppColors.gold : AppColors.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        promo.code,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          discountLabel,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الاستخدامات: ${promo.currentUses} / ${promo.maxUses} • ${promo.expiresAt != null ? "ينتهي: ${intl.DateFormat('d MMM yyyy').format(promo.expiresAt!)}" : "بدون تاريخ انتهاء"}',
                    style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Switch(
              value: promo.isActive,
              activeThumbColor: AppColors.gold,
              onChanged: (val) async {
                await Supabase.instance.client
                    .from('promo_codes')
                    .update({'is_active': val})
                    .eq('id', promo.id);
                ref.invalidate(promoCodesStreamProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
              onPressed: () async {
                await Supabase.instance.client
                    .from('promo_codes')
                    .delete()
                    .eq('id', promo.id);
                ref.invalidate(promoCodesStreamProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePromoDialog extends ConsumerStatefulWidget {
  const _CreatePromoDialog();

  @override
  ConsumerState<_CreatePromoDialog> createState() => _CreatePromoDialogState();
}

class _CreatePromoDialogState extends ConsumerState<_CreatePromoDialog> {
  final _codeController = TextEditingController();
  final _discountController = TextEditingController(text: '10');
  final _maxUsesController = TextEditingController(text: '100');
  bool _isPercentage = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _discountController.dispose();
    _maxUsesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    final discount = int.tryParse(_discountController.text.trim()) ?? 0;
    final maxUses = int.tryParse(_maxUsesController.text.trim()) ?? 100;

    if (code.isEmpty || discount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة رمز الكود وقيمة الخصم الصحيحة')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'code': code,
        'discount_percentage': _isPercentage ? discount : 0,
        'discount_amount': !_isPercentage ? discount : 0,
        'max_uses': maxUses,
        'current_uses': 0,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('promo_codes').insert(data);
      ref.invalidate(promoCodesStreamProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشـاء كود الخصم بنجاح! 🎉')));
      }
    } catch (e) {
      if (mounted) AppErrorHandler.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('إنشاء كود خصم جديد 🎁'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'رمز الكوبون (مثال: SUMMER20)',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('نسبة مئوية %')),
                    selected: _isPercentage,
                    onSelected: (val) => setState(() => _isPercentage = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('مبلغ ثابت (ج.م)')),
                    selected: !_isPercentage,
                    onSelected: (val) => setState(() => _isPercentage = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _isPercentage ? 'نسبة الخصم (%)' : 'مبلغ الخصم (ج.م)',
                prefixIcon: const Icon(Icons.monetization_on_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _maxUsesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الحد الأقصى لعدد الاستخدامات',
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        AppButton(
          label: 'تأكيد الحفظ',
          onTap: _submit,
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
