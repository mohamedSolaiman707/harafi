import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';

class TechLoginScreen extends ConsumerStatefulWidget {
  const TechLoginScreen({super.key});

  @override
  ConsumerState<TechLoginScreen> createState() => _TechLoginScreenState();
}

class _TechLoginScreenState extends ConsumerState<TechLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم الهاتف وكلمة المرور')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final dummyEmail = '${_phoneController.text.trim()}@harafi.com';

      await Supabase.instance.client.auth.signInWithPassword(
        email: dummyEmail,
        password: _passwordController.text.trim(),
      );

      // حفظ دور الفني لضمان التوجيه الصحيح مستقبلاً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'tech');

      if (mounted) context.go('/tech/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ في الدخول: تأكد من البيانات أو اضغط على انضم كفني إذا لم يكن لديك حساب')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.engineering, size: 80, color: AppColors.gold),
                const SizedBox(height: AppSpacing.xl),
                Text('بوابة الفنيين', style: AppTextStyles.displayMedium),
                const SizedBox(height: AppSpacing.sm),
                const Text('سجل دخول لمتابعة أعمالك', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xxl),
                AppCard(
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'رقم الهاتف',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_android,
                        hint: '01xxxxxxxxx',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'كلمة المرور',
                        controller: _passwordController,
                        isPassword: true,
                        prefixIcon: Icons.lock_outline,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'دخول',
                        onTap: _login,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ليس لديك حساب؟'),
                    TextButton(
                      onPressed: () {
                        context.push('/tech/register', extra: _phoneController.text);
                      },
                      child: const Text('انضم كفني الآن', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/welcome'),
                  child: const Text('العودة لاختيار الدور'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
