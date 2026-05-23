import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
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
  bool _isPreSelected = false;
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
        clientName: _nameController.text.trim(),
        clientPhone: _phoneController.text.trim(),
        service: _selectedService!,
        area: _areaController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await ref.read(ordersRepositoryProvider).create(order);

      if (mounted) {
        _showSuccessDialog(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إرسال الطلب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(Order result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 64),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تم استلام طلبك بنجاح!', style: AppTextStyles.headlineMed),
            const SizedBox(height: 16),
            Text(
              'كود التتبع الخاص بك:',
              style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: result.trackingCode));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(result.trackingCode, style: AppTextStyles.displayMedium.copyWith(color: AppColors.gold, letterSpacing: 2)),
                    const SizedBox(width: 12),
                    const Icon(Icons.copy, size: 20, color: AppColors.gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'سنقوم بالتواصل معك عبر الواتساب لتأكيد الموعد.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMed,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.go('/'), child: const Text('العودة للرئيسية')),
          AppButton(
            label: 'تتبع الطلب',
            size: ButtonSize.sm,
            onTap: () => context.go('/track/${result.trackingCode}'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width > 800 ? (width - 800) / 2 : AppSpacing.xl;

    return Scaffold(
      appBar: AppBar(title: const Text('طلب خدمة منزلية')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepHeader('1', 'اختر نوع الخدمة'),
              const SizedBox(height: AppSpacing.lg),
              _buildServiceGrid(),
              const SizedBox(height: AppSpacing.xxl),
              _buildStepHeader('2', 'بيانات التواصل والعنوان'),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    AppTextField(
                      label: 'الاسم',
                      controller: _nameController,
                      prefixIcon: Icons.person_outline,
                      validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'رقم الهاتف (واتساب)',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_android,
                      validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'العنوان بالتفصيل',
                      controller: _areaController,
                      prefixIcon: Icons.location_on_outlined,
                      validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'وصف المشكلة',
                      controller: _descriptionController,
                      hint: 'اشرح لنا المشكلة باختصار لنرسل الفني المناسب',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                label: 'تأكيد طلب الخدمة',
                onTap: _submit,
                isLoading: _isLoading,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String step, String title) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          child: Center(child: Text(step, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Text(title, style: AppTextStyles.headlineMed),
      ],
    );
  }

  Widget _buildServiceGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ServiceType.values.map((type) {
        final isSelected = _selectedService == type;
        return InkWell(
          onTap: () => setState(() => _selectedService = type),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.gold.withOpacity(0.1) : AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? AppColors.gold : AppColors.borderDefault, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  type.label,
                  style: AppTextStyles.titleMed.copyWith(color: isSelected ? AppColors.gold : AppColors.textPrimary),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
