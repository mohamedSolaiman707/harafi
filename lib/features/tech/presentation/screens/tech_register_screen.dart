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
  final String? initialPhone; // استلام الرقم من صفحة الدخول
  const TechRegisterScreen({super.key, this.initialPhone});

  @override
  ConsumerState<TechRegisterScreen> createState() => _TechRegisterScreenState();
}

class _TechRegisterScreenState extends ConsumerState<TechRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  ServiceType? _selectedSpec;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

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
      final phone = _phoneController.text.trim();
      final dummyEmail = '$phone@harafi.com';

      // 1. فحص هل الفني مضاف مسبقاً من الأدمن؟
      final existingTechs = await Supabase.instance.client
          .from('technicians')
          .select()
          .eq('phone', phone);

      // 2. إنشاء حساب Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: dummyEmail,
        password: _passwordController.text.trim(),
      );

      if (authResponse.user == null) throw 'فشل إنشاء الحساب';

      String userId = authResponse.user!.id;

      // 3. الربط الذكي: إذا وجدنا سجل قديم بنفس الرقم، نقوم بتحديثه وربطه بالـ Auth ID
      if (existingTechs.isNotEmpty) {
        final existingId = existingTechs.first['id'];
        await Supabase.instance.client
            .from('technicians')
            .update({
          'id': userId, // تحديث المعرف ليتوافق مع Auth
          'name': _nameController.text.trim(),
          'spec': _selectedSpec!.label,
          'bio': _bioController.text.trim(),
        })
            .eq('id', existingId);
      } else {
        // إذا كان فني جديد تماماً
        final dto = CreateTechnicianDto(
          id: userId,
          name: _nameController.text.trim(),
          phone: phone,
          spec: _selectedSpec!,
          bio: _bioController.text.trim(),
        );
        await ref.read(techsRepositoryProvider).addTechnician(dto);
      }

      if (mounted) {
        ref.invalidate(currentTechnicianProvider);
        context.go('/tech/dashboard');
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('انضم لفريق المحترفين')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.handyman_rounded, size: 64, color: AppColors.gold),
                  const SizedBox(height: AppSpacing.lg),
                  Text('سجل بياناتك مرة واحدة فقط', style: AppTextStyles.headlineMed),
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
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'رقم الهاتف',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_android,
                          // قفل الحقل إذا جاء الرقم من صفحة الدخول لضمان "المظبوطية"
                          hint: '01xxxxxxxxx',
                          validator: (v) => v!.length < 11 ? 'رقم غير صحيح' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'كلمة المرور',
                          controller: _passwordController,
                          isPassword: true,
                          prefixIcon: Icons.lock_outline,
                          hint: 'ستستخدمها للدخول لاحقاً',
                          validator: (v) => v!.length < 6 ? 'كلمة المرور ضعيفة' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<ServiceType>(
                          decoration: const InputDecoration(
                            labelText: 'التخصص المهني',
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
                          label: 'نبذة قصيرة عن خبرتك',
                          controller: _bioController,
                          hint: 'مثال: خبرة 10 سنوات في صيانة التكييفات',
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        AppButton(
                          label: 'إنشاء الحساب والبدء',
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
