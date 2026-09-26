import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_screen_providers.dart';

class TechLoginScreen extends ConsumerStatefulWidget {
  const TechLoginScreen({super.key});

  @override
  ConsumerState<TechLoginScreen> createState() => _TechLoginScreenState();
}

class _TechLoginScreenState extends ConsumerState<TechLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(techLoginLoadingProvider.notifier).state = true;
    try {
      final cleanPhone = _phoneController.text.trim();
      final dummyEmail = '$cleanPhone@harafi.com';

      await Supabase.instance.client.auth.signInWithPassword(
        email: dummyEmail,
        password: _passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'tech');

      if (mounted) context.go('/tech/dashboard');
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSnackBar(context, e);
      }
    } finally {
      if (mounted) ref.read(techLoginLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(techLoginLoadingProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ─── Ambient Glow Background Animations ────────────────────────
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = _pulseController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -100 + (pulse * 25),
                      right: -80 + (pulse * 15),
                      child: Container(
                        width: 480,
                        height: 480,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.gold.withValues(alpha: 0.14 + (pulse * 0.06)),
                              AppColors.gold.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -120 + (pulse * 30),
                      left: -80 + (pulse * 20),
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.accentCyan.withValues(alpha: 0.10 + (pulse * 0.05)),
                              AppColors.accentCyan.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ─── Main Content Layout ─────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // ─── Header Navbar ─────────────────────────────────────────
                  _buildHeaderNavBar(context),

                  // ─── Center Hero Body ──────────────────────────────────────
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 64 : (isTablet ? 32 : 20),
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Left Column: Brand & Value Showcase
                                    Expanded(
                                      flex: 11,
                                      child: _buildShowcaseColumn(),
                                    ),
                                    const SizedBox(width: 56),

                                    // Right Column: Premium Login Form Card
                                    Expanded(
                                      flex: 9,
                                      child: _buildLoginFormCard(isLoading),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildMobileHeaderBadge(),
                                    const SizedBox(height: 24),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 450),
                                      child: _buildLoginFormCard(isLoading),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header Navbar ───────────────────────────────────────────────────────────

  Widget _buildHeaderNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo2.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'حرفي',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'بوابة الفنيين 🛠️',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => context.go('/landing'),
            icon: const Icon(Icons.language_rounded, size: 16),
            label: const Text('الرئيسية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.borderDefault),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Showcase Column (Desktop Only) ──────────────────────────────────────────

  Widget _buildShowcaseColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.gold),
              SizedBox(width: 6),
              Text(
                'منصة المحترفين الأولى لحرفيي مصر 🏆',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        RichText(
          text: TextSpan(
            style: AppTextStyles.displayMedium.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 1.3,
            ),
            children: [
              const TextSpan(text: 'سجل دخولك لمتابعة '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ShaderMask(
                  shaderCallback: (bounds) => AppGradients.goldButton.createShader(bounds),
                  child: Text(
                    'أعمالك وأرباحك اليومية',
                    style: AppTextStyles.displayMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'احصل على طلبات الصيانة المباشرة في منطقتك، در فيش أرباحك، وتابع تقييمات العملاء بضغطة زر واحدة.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        // Value Cards Grid
        _buildValueFeatureTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'محفظة مالية شفافة',
          subtitle: 'تابع أرباحك، رصيدك المتبقي، وسدد عمولة الطلبات بكل سهولة 💰',
        ),
        const SizedBox(height: 14),
        _buildValueFeatureTile(
          icon: Icons.near_me_outlined,
          title: 'طلبات في نطاقك الجغرافي',
          subtitle: 'اختر طلبات الصيانة التي تناسب تخصصك ومنطقتك بحرية كاملة 📍',
        ),
        const SizedBox(height: 14),
        _buildValueFeatureTile(
          icon: Icons.verified_user_outlined,
          title: 'توثيق الحساب الذهبي',
          subtitle: 'احصل على شارات الثقة وارفع مستنداتك لزيادة ثقة العملاء بك 🛡️',
        ),
      ],
    );
  }

  Widget _buildValueFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMed.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.labelMed.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile Header Badge ─────────────────────────────────────────────────────

  Widget _buildMobileHeaderBadge() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.goldButton,
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF090D16),
              ),
              child: const Icon(Icons.handyman_rounded, color: AppColors.gold, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('بوابة الفنيين', style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w900, fontSize: 24)),
        const SizedBox(height: 4),
        Text('سجل دخولك لمتابعة لوحة التحكم والأعمال', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary, fontSize: 13.5)),
      ],
    );
  }

  // ─── Premium Login Form Card ─────────────────────────────────────────────────

  Widget _buildLoginFormCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 32,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.engineering_rounded, color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تسجيل دخول الفني',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'أدخل بياناتك المسجلة للمتابعة',
                        style: AppTextStyles.labelMed.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Phone Field
            AppTextField(
              label: 'رقم الهاتف (المحمول)',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_android_rounded,
              hint: '01xxxxxxxxx',
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال رقم الهاتف';
                final clean = v.trim();
                if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(clean)) {
                  return 'أدخل رقم هاتف مصري صحيح (11 رقم يبدأ بـ 010, 011, 012, 015)';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Password Field
            AppTextField(
              label: 'كلمة المرور',
              controller: _passwordController,
              isPassword: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال كلمة المرور' : null,
            ),

            const SizedBox(height: 28),

            // Submit Button
            AppButton(
              label: 'دخول لحساب الفني 🚀',
              onTap: _login,
              isLoading: isLoading,
            ),

            const SizedBox(height: 24),

            const Divider(color: AppColors.borderSubtle),

            const SizedBox(height: 16),

            // New User Registration Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ليس لديك حساب فني؟',
                  style: AppTextStyles.labelMed.copyWith(color: AppColors.textSecondary),
                ),
                TextButton(
                  onPressed: () {
                    context.go('/tech/register', extra: _phoneController.text.trim());
                  },
                  child: const Text(
                    'انضم كفني جديد 🌟',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),

            // Back to Role Selection
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('user_role');
                  if (mounted) context.go('/welcome');
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.textMuted),
                label: const Text(
                  'العودة لاختيار الدور',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
