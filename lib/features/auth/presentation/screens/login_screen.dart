import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_screen_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(loginLoadingProvider.notifier).state = true;

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // حفظ دور المسؤول لضمان التوجيه الصحيح في المرات القادمة
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'admin');

      if (mounted) context.go('/admin');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تسجيل الدخول: $e')),
        );
      }
    } finally {
      if (mounted) ref.read(loginLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(loginLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('دخول الإدارة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('user_role');
            if (context.mounted) context.go('/welcome');
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_person_outlined, size: 64, color: AppColors.gold),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'مرحباً بك مجدداً',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMed,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'سجل دخولك لإدارة الطلبات والفنيين',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppTextField(
                      label: 'البريد الإلكتروني',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      autofocus: true,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'يرجى إدخال البريد الإلكتروني' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'كلمة المرور',
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: Icons.lock_outlined,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'يرجى إدخال كلمة المرور' : null,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppButton(
                      label: 'تسجيل الدخول',
                      onTap: _login,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
