import 'package:flutter/material.dart';
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
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is ServiceType) {
      _selectedService = extra;
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
    if (!_formKey.currentState!.validate() || _selectedService == null) return;

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
            title: Text(
              'تم تقديم الطلب بنجاح',
              style: AppTextStyles.headlineMed,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'كود تتبع الطلب الخاص بك هو:',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    result.trackingCode,
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: AppColors.gold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.go('/');
                },
                child: const Text('العودة للرئيسية'),
              ),
              AppButton(
                label: 'تتبع الطلب',
                onTap: () {
                  context.go('/track/${result.trackingCode}');
                },
                variant: ButtonVariant.ghost,
                size: ButtonSize.md,
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStep(String label, bool active) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: active ? AppColors.gold : AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Icon(
              Icons.check,
              size: 18,
              color: active ? AppColors.background : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['اختر الخدمة', 'بياناتك', 'تأكيد الطلب'];

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل طلب جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('خطوات سهلة وسريعة', style: AppTextStyles.headlineLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'اختر الخدمة ثم املأ تفاصيل الاتصال والموقع.',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: List.generate(steps.length, (index) {
                    final active = index <= 1;
                    return _buildStep(steps[index], active);
                  }),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('اختر الخدمة', style: AppTextStyles.headlineMed),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: ServiceType.values.map((type) {
                          final selected = _selectedService == type;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedService = type),
                            child: AppCard(
                              color: selected
                                  ? AppColors.surface1
                                  : AppColors.surface3,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.lg,
                                horizontal: AppSpacing.xl,
                              ),
                              onTap: null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    type.icon,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    type.label,
                                    style: AppTextStyles.titleLarge.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_selectedService == null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'يرجى اختيار نوع الخدمة للمتابعة',
                          style: AppTextStyles.bodyMed.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'الاسم بالكامل',
                  controller: _nameController,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'يرجى إدخال الاسم' : null,
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'رقم واتساب',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'يرجى إدخال الرقم' : null,
                  prefixIcon: Icons.phone_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'المنطقة / العنوان',
                  controller: _areaController,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'يرجى إدخال العنوان' : null,
                  prefixIcon: Icons.location_on_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'وصف المشكلة (اختياري)',
                  hint: 'صف المشكلة بإيجاز',
                  controller: _descriptionController,
                  maxLines: 4,
                  prefixIcon: Icons.description_outlined,
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: AppButton(
          label: 'تأكيد الطلب',
          onTap: _isLoading ? null : _submit,
          isLoading: _isLoading,
          icon: Icons.arrow_back_ios_new,
        ),
      ),
    );
  }
}
