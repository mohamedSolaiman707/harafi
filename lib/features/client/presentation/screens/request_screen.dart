import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/presentation/providers/orders_provider.dart';

class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({super.key});

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();
  ServiceType? _selectedService;
  bool _isPreSelected = false; // هل العميل اختار الخدمة من الشاشة الرئيسية؟
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is ServiceType && !_isPreSelected) {
      _selectedService = extra;
      _isPreSelected = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار نوع الخدمة أولاً')),
      );
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final order = Order(
        id: '',
        trackingCode: '',
        clientName: _nameController.text,
        clientPhone: _phoneController.text,
        service: _selectedService!,
        area: _areaController.text,
        description: _descriptionController.text,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await ref.read(ordersRepositoryProvider).create(order);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
            title: const Text(
              'تم تقديم الطلب بنجاح',
              textAlign: TextAlign.center,
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'كود تتبع الطلب الخاص بك هو:',
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: result.trackingCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ الكود')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.copy, color: AppColors.gold, size: 20),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            result.trackingCode,
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: AppColors.gold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('العودة للرئيسية'),
              ),
              AppButton(
                label: 'تتبع الطلب',
                onTap: () => context.go('/track/${result.trackingCode}'),
                variant: ButtonVariant.ghost,
                size: ButtonSize.md,
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width > 800 ? (width - 800) / 2 : AppSpacing.xl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تسجيل طلب جديد'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.surface2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('خطوات سهلة وسريعة', style: AppTextStyles.headlineLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'املأ تفاصيل الاتصال والموقع لخدمتك في أسرع وقت.',
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                // قسم الخدمات - يظهر بذكاء
                _buildServiceSelection(),
                
                const SizedBox(height: AppSpacing.xl),
                
                // بيانات العميل
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بيانات التواصل والموقع', style: AppTextStyles.titleLarge),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'الاسم بالكامل',
                        controller: _nameController,
                        validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الاسم' : null,
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'رقم واتساب',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الرقم' : null,
                        prefixIcon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'المنطقة / العنوان بالتفصيل',
                        controller: _areaController,
                        validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال العنوان' : null,
                        prefixIcon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'ملاحظات إضافية (اختياري)',
                        hint: 'مثال: موعد الحضور المناسب أو تفاصيل العطل',
                        controller: _descriptionController,
                        maxLines: 3,
                        prefixIcon: Icons.description_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.md, horizontalPadding, AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border(top: BorderSide(color: AppColors.borderDefault)),
        ),
        child: AppButton(
          label: 'تأكيد الطلب الآن',
          onTap: _isLoading ? null : _submit,
          isLoading: _isLoading,
          icon: Icons.verified_outlined,
        ),
      ),
    );
  }

  Widget _buildServiceSelection() {
    // إذا كان العميل اختار من الصفحة الرئيسية، نعرض له الخدمة المختارة فقط مع إمكانية التغيير إذا أراد
    if (_isPreSelected && _selectedService != null) {
      return AppCard(
        color: AppColors.gold.withValues(alpha: 0.05),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(_selectedService!.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الخدمة المختارة', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
                  Text(_selectedService!.label, style: AppTextStyles.headlineMed),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isPreSelected = false),
              child: const Text('تغيير'),
            ),
          ],
        ),
      );
    }

    // الحالة الطبيعية: عرض كل الخدمات مقسمة
    return Column(
      children: ServiceCategory.values.map((category) {
        final services = ServiceType.values.where((s) => s.category == category).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(category.label, style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: services.map((type) {
                    final selected = _selectedService == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedService = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.gold.withValues(alpha: 0.1) : AppColors.surface3,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? AppColors.gold : AppColors.borderDefault,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(type.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              type.label,
                              style: AppTextStyles.titleMed.copyWith(
                                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
