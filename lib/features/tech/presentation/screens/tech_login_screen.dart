import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _showOtpField = false; // هل ننتظر إدخال الكود؟

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // المرحلة 1: إرسال كود OTP
  Future<void> _sendOtp() async {
    if (_phoneController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      // تنسيق الرقم ليكون دولياً (مثال: +201012345678)
      String phone = _phoneController.text.trim();
      if (!phone.startsWith('+')) {
        if (phone.startsWith('0')) {
          phone = '+2$phone';
        } else {
          phone = '+20$phone';
        }
      }

      await Supabase.instance.client.auth.signInWithOtp(
        phone: phone,
      );

      setState(() => _showOtpField = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال كود التحقق بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إرسال الكود: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // المرحلة 2: التحقق من الكود
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      String phone = _phoneController.text.trim();
      if (!phone.startsWith('+')) {
        if (phone.startsWith('0')) {
          phone = '+2$phone';
        } else {
          phone = '+20$phone';
        }
      }

      final response = await Supabase.instance.client.auth.verifyOTP(
        phone: phone,
        token: _otpController.text.trim(),
        type: OtpType.sms,
      );

      if (response.session != null) {
        if (mounted) context.go('/tech/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('كود التحقق غير صحيح: $e')),
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
                Text(
                  _showOtpField 
                    ? 'أدخل الكود المرسل إلى هاتفك' 
                    : 'سجل دخول لمتابعة شغلك وإدارة طلباتك',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppCard(
                  child: Column(
                    children: [
                      if (!_showOtpField)
                        AppTextField(
                          label: 'رقم الهاتف',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_android,
                          hint: '01xxxxxxxxx',
                        )
                      else
                        AppTextField(
                          label: 'كود التحقق (OTP)',
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.lock_outline,
                          hint: '------',
                          autofocus: true,
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: _showOtpField ? 'تحقق ودخول' : 'إرسال كود التحقق',
                        onTap: _showOtpField ? _verifyOtp : _sendOtp,
                        isLoading: _isLoading,
                      ),
                      if (_showOtpField)
                        TextButton(
                          onPressed: () => setState(() => _showOtpField = false),
                          child: const Text('تغيير رقم الهاتف'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('العودة للرئيسية'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
