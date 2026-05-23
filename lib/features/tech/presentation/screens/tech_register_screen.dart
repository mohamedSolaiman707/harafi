import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/dtos/technician_dtos.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/presentation/providers/techs_provider.dart';

class TechRegisterScreen extends ConsumerStatefulWidget {
  const TechRegisterScreen({super.key});

  @override
  ConsumerState<TechRegisterScreen> createState() => _TechRegisterScreenState();
}

class _TechRegisterScreenState extends ConsumerState<TechRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  ServiceType? _selectedSpec;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      context.go('/tech/login');
      return;
    }

    if (!_formKey.currentState!.validate() || _selectedSpec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع البيانات واختيار التخصص')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // النظام المظبوط: نربط حساب الفني بالـ ID والرقم الموثقين من Auth
    final dto = CreateTechnicianDto(
      id: user.id, 
      name: _nameController.text.trim(),
      phone: user.phone ?? '', // الهاتف موثق مسبقاً عبر OTP
      spec: _selectedSpec!,
      bio: _bioController.text.trim(),
    );

    final result = await ref.read(techsRepositoryProvider).addTechnician(dto);

    result.when(
      left: (failure) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${failure.message}')),
        );
      },
      right: (tech) {
        if (mounted) context.go('/tech/dashboard');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('إكمال ملف الفني')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 64, color: AppColors.gold),
                  const SizedBox(height: AppSpacing.lg),
                  Text('خطوة واحدة وتكون معنا', style: AppTextStyles.headlineMed),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'رقم الهاتف الموثق: ${user?.phone ?? ""}',
                    style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'الاسم الكامل',
                          controller: _nameController,
                          hint: 'اسمك كما في البطاقة',
                          prefixIcon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        DropdownButtonFormField<ServiceType>(
                          decoration: const InputDecoration(
                            labelText: 'التخصص الأساسي',
                            prefixIcon: Icon(Icons.build_circle_outlined),
                          ),
                          dropdownColor: AppColors.surface2,
                          items: ServiceType.values.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedSpec = val),
                          validator: (v) => v == null ? 'يرجى اختيار التخصص' : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'نبذة عن خبرتك',
                          controller: _bioController,
                          hint: 'مثال: فني كهرباء متخصص في التمديدات المنزلية',
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        AppButton(
                          label: 'حفظ وإرسال للمراجعة',
                          onTap: _submitRequest,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
