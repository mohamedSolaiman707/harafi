import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/tech_status.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../providers/tech_screen_providers.dart';

class TechRegisterScreen extends ConsumerStatefulWidget {
  final String? initialPhone;
  const TechRegisterScreen({super.key, this.initialPhone});

  @override
  ConsumerState<TechRegisterScreen> createState() => _TechRegisterScreenState();
}

class _TechRegisterScreenState extends ConsumerState<TechRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  final _visitPriceController = TextEditingController(text: '50');

  final _picker = ImagePicker();
  final _storageService = StorageService();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController(text: widget.initialPhone);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _visitPriceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentImage(ImageSource source, String docType) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 75,
    );
    if (image != null) {
      if (docType == 'avatar') {
        ref.read(techRegisterAvatarProvider.notifier).state = image;
      } else if (docType == 'front') {
        ref.read(techRegisterIdFrontProvider.notifier).state = image;
        ref.read(techRegisterIdProofProvider.notifier).state = image;
      } else if (docType == 'back') {
        ref.read(techRegisterIdBackProvider.notifier).state = image;
      } else if (docType == 'criminal') {
        ref.read(techRegisterCriminalRecordProvider.notifier).state = image;
      }
    }
  }

  void _removeDocumentImage(String docType) {
    if (docType == 'avatar') ref.read(techRegisterAvatarProvider.notifier).state = null;
    if (docType == 'front') {
      ref.read(techRegisterIdFrontProvider.notifier).state = null;
      ref.read(techRegisterIdProofProvider.notifier).state = null;
    }
    if (docType == 'back') ref.read(techRegisterIdBackProvider.notifier).state = null;
    if (docType == 'criminal') ref.read(techRegisterCriminalRecordProvider.notifier).state = null;
  }

  void _showImageSourceSheet(String docType, String docTitle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'اختيار $docTitle',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.gold),
              title: const Text('التقاط صورة بالكاميرا (مباشرة)'),
              subtitle: const Text('يُفضل التقاط صورة واضحة ومباشرة'),
              onTap: () {
                Navigator.pop(context);
                _pickDocumentImage(ImageSource.camera, docType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickDocumentImage(ImageSource.gallery, docType);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool _validateStep1() {
    return _step1FormKey.currentState?.validate() ?? false;
  }

  bool _validateStep2() {
    final selectedSpec = ref.read(techRegisterSpecProvider);
    if (selectedSpec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى اختيار تخصصك المهني الرئيسي قبل المتابعة'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
    return _step2FormKey.currentState?.validate() ?? false;
  }

  Future<void> _submit() async {
    final selectedSpec = ref.read(techRegisterSpecProvider);
    if (selectedSpec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى العودة للخطوة 2 واختيار تخصصك المهني الرئيسي'),
          backgroundColor: AppColors.error,
        ),
      );
      ref.read(techRegisterStepProvider.notifier).state = 1;
      return;
    }

    final avatarImage = ref.read(techRegisterAvatarProvider);
    final idFrontImage = ref.read(techRegisterIdFrontProvider) ?? ref.read(techRegisterIdProofProvider);
    final idBackImage = ref.read(techRegisterIdBackProvider);
    final criminalRecordImage = ref.read(techRegisterCriminalRecordProvider);
    final selectedCity = ref.read(techRegisterCityProvider);

    if (idFrontImage == null || idBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى رفع صورة وجه وظهر البطاقة الشخصية للتحقق الهوية'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    ref.read(techRegisterLoadingProvider.notifier).state = true;
    try {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();
      final dummyEmail = '$phone@harafi.com';

      String userId;
      try {
        final authResponse = await Supabase.instance.client.auth.signUp(
          email: dummyEmail,
          password: password,
        );

        if (authResponse.user == null) {
          throw 'فشل إنشاء الحساب، يرجى المحاولة برقم هاتف آخر 📱';
        }
        userId = authResponse.user!.id;
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('already registered') ||
            errStr.contains('already_exists') ||
            errStr.contains('user_already_exists') ||
            errStr.contains('user already exists') ||
            errStr.contains('already exists')) {
          throw 'هذا الرقم مسجل بالفعل في نظام حرفي! يرجى تسجيل الدخول بدلاً من التسجيل الجديد ⚠️';
        }
        rethrow;
      }

      if (Supabase.instance.client.auth.currentSession == null) {
        try {
          await Supabase.instance.client.auth.signInWithPassword(
            email: dummyEmail,
            password: password,
          );
        } catch (_) {}
      }

      String? avatarUrl;
      if (avatarImage != null) {
        avatarUrl = await _storageService.uploadImage(
          image: avatarImage,
          path: 'avatars',
          fileName: '${userId}_avatar',
        );
      }

      final frontUrl = await _storageService.uploadImage(
        image: idFrontImage,
        path: 'tech_photos',
        fileName: '${userId}_id_front',
      );
      if (frontUrl == null) throw 'فشل رفع صورة وجه البطاقة، يرجى المحاولة مجدداً 📸';

      final backUrl = await _storageService.uploadImage(
        image: idBackImage,
        path: 'tech_photos',
        fileName: '${userId}_id_back',
      );
      if (backUrl == null) throw 'فشل رفع صورة ظهر البطاقة، يرجى المحاولة مجدداً 📸';
      String? criminalUrl;
      if (criminalRecordImage != null) {
        criminalUrl = await _storageService.uploadImage(
          image: criminalRecordImage,
          path: 'tech_photos',
          fileName: '${userId}_criminal',
        );
      }

      final technicianData = {
        'id': userId,
        'name': _nameController.text.trim(),
        'phone': phone,
        'spec': selectedSpec.label,
        'bio': _bioController.text.trim(),
        'visit_price': int.tryParse(_visitPriceController.text) ?? 50,
        'area': selectedCity,
        'photo_url': avatarUrl,
        'identity_proof_url': frontUrl,
        'national_id_front_url': frontUrl,
        'national_id_back_url': backUrl,
        'criminal_record_url': criminalUrl,
        'status': TechStatus.pending.label,
        'is_verified': false,
        'total_earnings': 0,
        'total_jobs': 0,
        'wallet_balance': 100,
        'rating': 0.0,
        'created_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('technicians').upsert(technicianData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'tech');

      if (mounted) {
        ref.invalidate(currentTechnicianProvider);
        context.go('/tech/dashboard');
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSnackBar(context, e);
      }
    } finally {
      if (mounted) ref.read(techRegisterLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> _onWillPop() async {
    final currentStep = ref.read(techRegisterStepProvider);
    if (currentStep > 0) {
      ref.read(techRegisterStepProvider.notifier).state = currentStep - 1;
      return false;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء التسجيل؟'),
        content: const Text('هل أنت متأكد من الخروج؟ ستفقد البيانات والمستندات المرفوعة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('متابعة التسجيل'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(techRegisterStepProvider);
    final isLoading = ref.watch(techRegisterLoadingProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;
    final isTablet = screenWidth >= 650 && screenWidth < 950;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final exit = await _onWillPop();
        if (exit && mounted && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Directionality(
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
                        top: -120 + (pulse * 25),
                        right: -100 + (pulse * 15),
                        child: Container(
                          width: 520,
                          height: 520,
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
                        bottom: -140 + (pulse * 30),
                        left: -100 + (pulse * 20),
                        child: Container(
                          width: 550,
                          height: 550,
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
                    // Top Navbar
                    _buildHeaderNavBar(context),

                    // Scrollable Hero Body
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 64 : (isTablet ? 32 : 16),
                            vertical: 24,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1150),
                            child: isDesktop
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Left Column: Brand Benefits & Live Stepper Indicator
                                      Expanded(
                                        flex: 10,
                                        child: _buildShowcaseColumn(currentStep),
                                      ),
                                      const SizedBox(width: 48),

                                      // Right Column: Active Step Form Card
                                      Expanded(
                                        flex: 12,
                                        child: _buildRegisterFormCard(currentStep, isLoading),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildMobileHeaderBadge(currentStep),
                                      const SizedBox(height: 20),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 600),
                                        child: _buildRegisterFormCard(currentStep, isLoading),
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
                  'انضمام المحترفين 🛠️',
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

  Widget _buildShowcaseColumn(int currentStep) {
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
              Icon(Icons.stars_rounded, size: 16, color: AppColors.gold),
              SizedBox(width: 6),
              Text(
                '🎁 هدية انضمام: 100 ج.م رصيد ترحيبي مجاني بمحفظتك!',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        RichText(
          text: TextSpan(
            style: AppTextStyles.displayMedium.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1.3,
            ),
            children: [
              const TextSpan(text: 'انضم لمجتمع '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ShaderMask(
                  shaderCallback: (bounds) => AppGradients.goldButton.createShader(bounds),
                  child: Text(
                    '+150 فني محترف',
                    style: AppTextStyles.displayMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: '\nوابدأ استقبال الطلبات اليوم'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'خطوات بسيطة وشفافة للتسجيل واعتماد حسابك. اختر تخصصك وارفع مستنداتك للانطلاق مع منصة حرفي.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 28),

        // Live Step Progress Cards
        _buildStepGuideTile(
          stepIndex: 0,
          currentStep: currentStep,
          icon: Icons.person_pin_rounded,
          title: 'الخطوة 1: البيانات الشخصية',
          subtitle: 'الاسم الكامل الثلاثي، رقم الواتساب، وكلمة المرور الآمنة.',
        ),
        const SizedBox(height: 12),
        _buildStepGuideTile(
          stepIndex: 1,
          currentStep: currentStep,
          icon: Icons.handyman_rounded,
          title: 'الخطوة 2: المجال والمنطقة',
          subtitle: 'تحديد التخصص الرئيسي، المحافظة والمنطقة، وسعر المعاينة.',
        ),
        const SizedBox(height: 12),
        _buildStepGuideTile(
          stepIndex: 2,
          currentStep: currentStep,
          icon: Icons.verified_user_rounded,
          title: 'الخطوة 3: التوثيق والهوية',
          subtitle: 'رفع صور وجه وظهر البطاقة للحصول على شارة التوثيق المعتمدة.',
        ),
      ],
    );
  }

  Widget _buildStepGuideTile({
    required int stepIndex,
    required int currentStep,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isActive = currentStep == stepIndex;
    final isDone = currentStep > stepIndex;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.gold.withValues(alpha: 0.12)
            : (isDone ? AppColors.success.withValues(alpha: 0.08) : AppColors.surface1.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.gold
              : (isDone ? AppColors.success : AppColors.borderSubtle),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AppColors.success : (isActive ? AppColors.gold : AppColors.surface2),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 20)
                  : Icon(icon, color: isActive ? Colors.black : AppColors.textMuted, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isActive ? AppColors.gold : (isDone ? AppColors.success : Colors.white),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mobile Header Badge ─────────────────────────────────────────────────────

  Widget _buildMobileHeaderBadge(int currentStep) {
    return Column(
      children: [
        _buildStepperHeader(currentStep),
      ],
    );
  }

  // ─── Registration Form Card Widget ───────────────────────────────────────────

  Widget _buildRegisterFormCard(int currentStep, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A).withValues(alpha: 0.92),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Progress Stepper for Card
          _buildStepperHeader(currentStep),
          const SizedBox(height: 24),

          // Step Switcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (currentStep) {
              0 => _buildStep1AccountInfo(),
              1 => _buildStep2ProfessionalDetails(),
              2 => _buildStep3IdentityVerification(isLoading),
              _ => _buildStep1AccountInfo(),
            },
          ),
        ],
      ),
    );
  }

  // ─── Stepper Progress Header ─────────────────────────────────────────────────

  Widget _buildStepperHeader(int currentStep) {
    final stepTitles = ['الأساسية', 'المجال', 'التوثيق'];
    final progress = (currentStep + 1) / 3;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (index) {
            final isCompleted = index < currentStep;
            final isActive = index == currentStep;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? AppColors.success
                                : (isActive ? AppColors.gold : AppColors.surface2),
                            border: Border.all(
                              color: isActive ? AppColors.gold : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isCompleted
                                ? const Icon(Icons.check_rounded, size: 20, color: Colors.black)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? Colors.black : AppColors.textMuted,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stepTitles[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isActive ? AppColors.gold : AppColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (index < 2)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 18),
                        color: index < currentStep ? AppColors.success : AppColors.surface3,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppColors.surface2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
      ],
    );
  }

  // ─── Step 1: Account Info ────────────────────────────────────────────────────

  Widget _buildStep1AccountInfo() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline_rounded, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 10),
              Text('بيانات الحساب الشخصي', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'أدخل معلوماتك الشخصية لتسجيل الحساب والتواصل مع العملاء',
            style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),

          AppTextField(
            label: 'الاسم الكامل الثلاثي',
            controller: _nameController,
            prefixIcon: Icons.person_outline,
            hint: 'مثال: أحمد محمد علي',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'يرجى إدخال الاسم الكامل';
              final parts = v.trim().split(RegExp(r'\s+'));
              if (parts.length < 3) {
                return 'يرجى كتابة الاسم الثلاثي على الأقل (مثال: أحمد محمد علي)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            label: 'رقم الهاتف (المحمول)',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_android,
            hint: '01xxxxxxxxx',
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'يرجى إدخال رقم الهاتف';
              final clean = v.trim();
              if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(clean)) {
                return 'يرجى إدخال رقم هاتف مصري صحيح (11 رقم يبدأ بـ 010, 011, 012, 015)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            label: 'كلمة المرور',
            controller: _passwordController,
            isPassword: true,
            prefixIcon: Icons.lock_outline,
            validator: (v) => v == null || v.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
          ),
          const SizedBox(height: 24),

          AppButton(
            label: 'التالي: المجال والمنطقة ➡️',
            onTap: () {
              if (_validateStep1()) {
                ref.read(techRegisterStepProvider.notifier).state = 1;
              }
            },
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'لديك حساب بالفعل؟',
                style: AppTextStyles.labelMed.copyWith(color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: () => context.go('/tech/login'),
                child: const Text(
                  'تسجيل الدخول',
                  style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Professional Details ────────────────────────────────────────────

  Widget _buildStep2ProfessionalDetails() {
    final selectedSpec = ref.watch(techRegisterSpecProvider);
    final selectedGov = ref.watch(techRegisterGovProvider);
    final selectedCity = ref.watch(techRegisterCityProvider);

    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.handyman_rounded, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 10),
              Text('التخصص المهني ومجال العمل', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'اختر تخصصك الرئيسي والمنطقة التي تقدم فيها خدماتك',
            style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),

          const Text(
            'اختر تخصصك الرئيسي *',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.gold),
          ),
          const SizedBox(height: 10),

          // Real Service Photo Cards Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemCount: ServiceType.values.length,
            itemBuilder: (context, index) {
              final spec = ServiceType.values[index];
              final isSelected = selectedSpec == spec;
              final imageAsset = switch (spec) {
                ServiceType.plumbing => 'assets/images/sbak.jpg',
                ServiceType.electrical => 'assets/images/khrba.jpg',
                ServiceType.carpentry => 'assets/images/negara.jpg',
                ServiceType.ac => 'assets/images/takyeefat.jpg',
                ServiceType.refrigerators => 'assets/images/fridge.jpg',
                ServiceType.washingMachines => 'assets/images/washing.jpg',
                ServiceType.screens => 'assets/images/tv.jpg',
                ServiceType.stoves => 'assets/images/gas.jpg',
              };

              return InkWell(
                onTap: () => ref.read(techRegisterSpecProvider.notifier).state = spec,
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 8)]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          imageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surface2),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: isSelected ? 0.65 : 0.85),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 10,
                          left: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                spec.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppColors.gold : Colors.white,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.gold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, size: 12, color: Colors.black),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          AppTextField(
            label: 'سعر الزيارة المعاينية (ج.م)',
            controller: _visitPriceController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.monetization_on_outlined,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'يرجى تحديد سعر الزيارة';
              final val = int.tryParse(v.trim());
              if (val == null || val < 0 || val > 5000) {
                return 'أدخل سعر زيارة منطقي بين 0 و 5000 ج.م';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedGov,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  dropdownColor: AppColors.surface2,
                  items: AppConstants.governoratesAndCities.keys
                      .map((gov) => DropdownMenuItem(value: gov, child: Text(gov, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(techRegisterGovProvider.notifier).state = val;
                      final cities = AppConstants.governoratesAndCities[val];
                      if (cities != null && cities.isNotEmpty) {
                        ref.read(techRegisterCityProvider.notifier).state = cities.first;
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: (AppConstants.governoratesAndCities[selectedGov] ?? []).contains(selectedCity)
                      ? selectedCity
                      : AppConstants.governoratesAndCities[selectedGov]?.first,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المدينة / المنطقة',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  dropdownColor: AppColors.surface2,
                  items: (AppConstants.governoratesAndCities[selectedGov] ?? [])
                      .map((city) => DropdownMenuItem(value: city, child: Text(city, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) ref.read(techRegisterCityProvider.notifier).state = val;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(techRegisterStepProvider.notifier).state = 0,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('السابق'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'التالي: توثيق الحساب ➡️',
                  onTap: () {
                    if (_validateStep2()) {
                      ref.read(techRegisterStepProvider.notifier).state = 2;
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Identity & Avatar Upload ────────────────────────────────────────

  Widget _buildStep3IdentityVerification(bool isLoading) {
    final avatarImage = ref.watch(techRegisterAvatarProvider);
    final idFrontImage = ref.watch(techRegisterIdFrontProvider) ?? ref.watch(techRegisterIdProofProvider);
    final idBackImage = ref.watch(techRegisterIdBackProvider);
    final criminalRecordImage = ref.watch(techRegisterCriminalRecordProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 22),
            ),
            const SizedBox(width: 10),
            Text('التوثيق والتحقق 🛡️', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'قم بمعاينة ورفع المستندات المطلوبة للتأكد من صحتها قبل التفعيل',
          style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 18),

        _buildDocTileWithPreview(
          docType: 'avatar',
          title: 'الصورة الشخصية (صورة ملامح الوجه)',
          subtitle: 'اختياري - تظهر للعملاء والمستخدمين كرمز لملفك الشخصي',
          image: avatarImage,
          isRequired: false,
        ),
        const SizedBox(height: 10),
        _buildDocTileWithPreview(
          docType: 'front',
          title: 'وجه البطاقة الشخصية (صورة الأمام)',
          subtitle: 'مطلوبة - صورة واضحة ومباشرة من الأمام (سرية للتوثيق فقط)',
          image: idFrontImage,
          isRequired: true,
        ),
        const SizedBox(height: 10),
        _buildDocTileWithPreview(
          docType: 'back',
          title: 'ظهر البطاقة الشخصية (صورة الخلف)',
          subtitle: 'مطلوبة - صورة واضحة ومباشرة من الخلف (سرية للتوثيق فقط)',
          image: idBackImage,
          isRequired: true,
        ),
        const SizedBox(height: 10),
        _buildDocTileWithPreview(
          docType: 'criminal',
          title: 'صحيفة الحالة الجنائية (الفيش والتشبيه)',
          subtitle: 'اختياري - يمنحك شارة التوثيق الذهبي المباشرة 🏆',
          image: criminalRecordImage,
          isRequired: false,
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : () => ref.read(techRegisterStepProvider.notifier).state = 1,
                icon: const Icon(Icons.arrow_back),
                label: const Text('السابق'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'إنشاء الحساب والبدء 🚀',
                onTap: isLoading ? null : _submit,
                isLoading: isLoading,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Doc Tile Builder With Visual Thumbnail ──────────────────────────────────

  Widget _buildDocTileWithPreview({
    required String docType,
    required String title,
    required String subtitle,
    required XFile? image,
    bool isRequired = true,
  }) {
    final bool uploaded = image != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uploaded ? AppColors.success.withValues(alpha: 0.08) : AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: uploaded ? AppColors.success : AppColors.borderDefault,
          width: uploaded ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (uploaded)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  border: Border.all(color: AppColors.success, width: 1),
                ),
                child: kIsWeb
                    ? Image.network(image.path, fit: BoxFit.cover)
                    : Image.file(File(image.path), fit: BoxFit.cover),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isRequired ? Icons.badge_outlined : Icons.portrait_rounded,
                color: AppColors.gold,
                size: 22,
              ),
            ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold, fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRequired)
                      Text(' *', style: AppTextStyles.titleMed.copyWith(color: AppColors.error)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  uploaded ? 'تم تحديد الصورة بنجاح ✅ (عاينها للتأكد)' : subtitle,
                  style: AppTextStyles.labelMed.copyWith(
                    color: uploaded ? AppColors.success : AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          if (!uploaded)
            ElevatedButton.icon(
              onPressed: () => _showImageSourceSheet(docType, title),
              icon: const Icon(Icons.upload_file_rounded, size: 15),
              label: const Text('رفع', style: TextStyle(fontSize: 11.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.change_circle_outlined, color: AppColors.gold, size: 22),
                  tooltip: 'تغيير الصورة',
                  onPressed: () => _showImageSourceSheet(docType, title),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  tooltip: 'حذف',
                  onPressed: () => _removeDocumentImage(docType),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
