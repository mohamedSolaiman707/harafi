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
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  ServiceType? _selectedSpec;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedSpec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع البيانات واختيار التخصص')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      String userId;

      if (currentUser == null) {
        // حالة فني جديد تماماً: إنشاء حساب Auth أولاً
        final phone = _phoneController.text.trim();
        final dummyEmail = '$phone@harafi.com';
        final authResponse = await Supabase.instance.client.auth.signUp(
          email: dummyEmail,
          password: _passwordController.text.trim(),
        );
        if (authResponse.user == null) throw 'فشل إنشاء الحساب';
        userId = authResponse.user!.id;
      } else {
        // حالة فني مسجل دخول بالهاتف لكنه يكمل بياناته
        userId = currentUser.id;
      }

      // إنشاء ملف الفني في قاعدة البيانات
      final dto = CreateTechnicianDto(
        id: userId,
        name: _nameController.text.trim(),
        phone: currentUser?.phone ?? _phoneController.text.trim(),
        spec: _selectedSpec!,
        bio: _bioController.text.trim(),
      );

      final result = await ref.read(techsRepositoryProvider).addTechnician(dto);
      
      result.when(
        left: (failure) => throw failure.message,
        right: (tech) {
          if (mounted) {
            ref.invalidate(currentTechnicianProvider);
            context.go('/tech/dashboard');
          }
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAlreadyLoggedIn = user != null;

    return Scaffold(
      appBar: AppBar(title: Text(isAlreadyLoggedIn ? 'إكمال الملف المهني' : 'تسجيل فني جديد')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Icon(
                    isAlreadyLoggedIn ? Icons.badge_outlined : Icons.person_add_alt_1_outlined,
                    size: 64, 
                    color: AppColors.gold
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    isAlreadyLoggedIn ? 'خطوة واحدة وتكون معنا' : 'انضم لشبكة حرفي المحترفة',
                    style: AppTextStyles.headlineMed,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'الاسم الكامل',
                          controller: _nameController,
                          hint: 'أدخل اسمك الثلاثي',
                          prefixIcon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        if (!isAlreadyLoggedIn) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            label: 'رقم الهاتف',
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_android,
                            validator: (v) => v!.length < 11 ? 'رقم غير صحيح' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            label: 'كلمة المرور',
                            controller: _passwordController,
                            isPassword: true,
                            prefixIcon: Icons.lock_outline,
                            validator: (v) => v!.length < 6 ? 'كلمة المرور ضعيفة' : null,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<ServiceType>(
                          decoration: const InputDecoration(
                            labelText: 'التخصص',
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
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'نبذة عن خبرتك',
                          controller: _bioController,
                          hint: 'مثال: متخصص في صيانة التكييفات المركزية',
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        AppButton(
                          label: isAlreadyLoggedIn ? 'حفظ وإرسال للمراجعة' : 'إنشاء الحساب وانضمام',
                          onTap: _submit,
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
