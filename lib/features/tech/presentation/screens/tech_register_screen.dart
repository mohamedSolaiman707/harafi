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
import '../../../../shared/widgets/app_card.dart';
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

class _TechRegisterScreenState extends ConsumerState<TechRegisterScreen> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  final _visitPriceController = TextEditingController(text: '50');

  final _picker = ImagePicker();
  final _storageService = StorageService();

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
    _visitPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickDocumentImage(ImageSource source, String docType) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 70,
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
                'رفع $docTitle',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.gold),
              title: const Text('التقاط صورة بالكاميرا'),
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
        const SnackBar(content: Text('يرجى اختيار التخصص المهني قبل المتابعة 🛠️')),
      );
      return false;
    }
    return _step2FormKey.currentState?.validate() ?? false;
  }

  Future<void> _submit() async {
    final selectedSpec = ref.read(techRegisterSpecProvider);
    final avatarImage = ref.read(techRegisterAvatarProvider);
    final idFrontImage = ref.read(techRegisterIdFrontProvider) ?? ref.read(techRegisterIdProofProvider);
    final idBackImage = ref.read(techRegisterIdBackProvider);
    final criminalRecordImage = ref.read(techRegisterCriminalRecordProvider);
    final selectedCity = ref.read(techRegisterCityProvider);

    if (idFrontImage == null || idBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى رفع صورة وجه وظهر البطاقة الشخصية لتوثيق حسابك 🛡️')),
      );
      return;
    }

    ref.read(techRegisterLoadingProvider.notifier).state = true;
    try {
      final phone = _phoneController.text.trim();
      final dummyEmail = '$phone@harafi.com';

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: dummyEmail,
        password: _passwordController.text.trim(),
      );

      if (authResponse.user == null) throw 'فشل إنشاء الحساب';
      String userId = authResponse.user!.id;

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
      final backUrl = await _storageService.uploadImage(
        image: idBackImage,
        path: 'tech_photos',
        fileName: '${userId}_id_back',
      );
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
        'spec': selectedSpec!.label,
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

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(techRegisterStepProvider);
    final isLoading = ref.watch(techRegisterLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('انضم لفريق المحترفين'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                // ─── Header & Stepper Progress ─────────────────────────────────
                _buildStepperHeader(currentStep),
                const SizedBox(height: AppSpacing.xl),

                // ─── Animated Step Content ────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: AppCard(
                    key: ValueKey<int>(currentStep),
                    child: switch (currentStep) {
                      0 => _buildStep1AccountInfo(),
                      1 => _buildStep2ProfessionalDetails(),
                      2 => _buildStep3IdentityVerification(isLoading),
                      _ => _buildStep1AccountInfo(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Stepper Header Widget ───────────────────────────────────────────────────

  Widget _buildStepperHeader(int currentStep) {
    final stepTitles = ['البيانات الأساسية', 'المجال والمنطقة', 'التوثيق والأمان'];
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
                                ? const Icon(Icons.check, size: 20, color: Colors.black)
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? Colors.black : AppColors.textMuted,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
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
                        margin: const EdgeInsets.only(bottom: 20),
                        color: index < currentStep ? AppColors.success : AppColors.surface3,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.surface2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
          ),
        ),
      ],
    );
  }

  // ─── Step 1: Account Information ────────────────────────────────────────────

  Widget _buildStep1AccountInfo() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, color: AppColors.gold, size: 28),
              const SizedBox(width: 10),
              Text('بيانات الحساب الشخصي', style: AppTextStyles.headlineMed),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'أدخل معلوماتك الشخصية لتسهيل تسجيل الدخول والتواصل',
            style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'الاسم الكامل',
            controller: _nameController,
            prefixIcon: Icons.person_outline,
            validator: (v) => v == null || v.trim().isEmpty ? 'يرجى إدخال الاسم الكامل' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'رقم الهاتف',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_android,
            validator: (v) => v == null || v.length < 11 ? 'أدخل رقم هاتف صحيح مكون من 11 رقم' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'كلمة المرور',
            controller: _passwordController,
            isPassword: true,
            prefixIcon: Icons.lock_outline,
            validator: (v) => v == null || v.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'التالي: المجال والمنطقة ➡️',
            onTap: () {
              if (_validateStep1()) {
                ref.read(techRegisterStepProvider.notifier).state = 1;
              }
            },
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
              const Icon(Icons.handyman_rounded, color: AppColors.gold, size: 28),
              const SizedBox(width: 10),
              Text('التخصص المهني ومجال العمل', style: AppTextStyles.headlineMed),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'اختر تخصصك الرئيسي والمنطقة التي تقدم فيها خدماتك',
            style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ─── Visual Specialty Selector Grid ───
          const Text(
            'اختر تخصصك الرئيسي *',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gold),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.15,
            ),
            itemCount: ServiceType.values.length,
            itemBuilder: (context, index) {
              final spec = ServiceType.values[index];
              final isSelected = selectedSpec == spec;
              return InkWell(
                onTap: () => ref.read(techRegisterSpecProvider.notifier).state = spec,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.gold : AppColors.borderSubtle,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(spec.icon, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(
                        spec.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.gold : Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          AppTextField(
            label: 'سعر الزيارة المعاينية (ج.م)',
            controller: _visitPriceController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.monetization_on_outlined,
            validator: (v) => v == null || v.isEmpty ? 'يرجى تحديد سعر المعاينة' : null,
          ),
          const SizedBox(height: AppSpacing.md),

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
                      ref.read(techRegisterCityProvider.notifier).state = AppConstants.governoratesAndCities[val]!.first;
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.xxl),

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
              const SizedBox(width: AppSpacing.md),
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
            const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 28),
            const SizedBox(width: 10),
            Text('التوثيق والتحقق 🛡️', style: AppTextStyles.headlineMed),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'قم برفع المستندات المطلوبة لتفعيل حسابك كـ فني موثق',
          style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),

        _buildDocTile(
          title: 'الصورة الشخصية (صورة ملامح الوجه)',
          subtitle: 'اختياري - تُعرض للعملاء في نتائج البحث والطلبات',
          image: avatarImage,
          onTap: () => _showImageSourceSheet('avatar', 'الصورة الشخصية'),
          isRequired: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildDocTile(
          title: 'وجه البطاقة الشخصية',
          subtitle: 'صورة واضحة من الأمام (سرية للتوثيق فقط)',
          image: idFrontImage,
          onTap: () => _showImageSourceSheet('front', 'وجه البطاقة الشخصية'),
          isRequired: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildDocTile(
          title: 'ظهر البطاقة الشخصية',
          subtitle: 'صورة واضحة من الخلف (سرية للتوثيق فقط)',
          image: idBackImage,
          onTap: () => _showImageSourceSheet('back', 'ظهر البطاقة الشخصية'),
          isRequired: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildDocTile(
          title: 'صحيفة الحالة الجنائية (الفيش والتشبيه)',
          subtitle: 'اختياري - يمنحك التوثيق الذهبي المباشر',
          image: criminalRecordImage,
          onTap: () => _showImageSourceSheet('criminal', 'الفيش والتشبيه'),
          isRequired: false,
        ),
        const SizedBox(height: AppSpacing.xxl),

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
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: AppButton(
                label: 'إنشاء الحساب والبدء 🚀',
                onTap: _submit,
                isLoading: isLoading,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Document Tile Builder Helper ────────────────────────────────────────────

  Widget _buildDocTile({
    required String title,
    required String subtitle,
    required XFile? image,
    required VoidCallback onTap,
    bool isRequired = true,
  }) {
    final bool uploaded = image != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: uploaded ? AppColors.success.withValues(alpha: 0.08) : AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: uploaded ? AppColors.success : AppColors.borderDefault),
        ),
        child: Row(
          children: [
            Icon(
              uploaded ? Icons.check_circle_rounded : (isRequired ? Icons.badge_outlined : Icons.description_outlined),
              color: uploaded ? AppColors.success : AppColors.gold,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (isRequired)
                        Text(' *', style: AppTextStyles.titleMed.copyWith(color: AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uploaded ? 'تم اختيار المستند (${image.name})' : subtitle,
                    style: AppTextStyles.labelMed.copyWith(color: uploaded ? AppColors.success : AppColors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              uploaded ? Icons.task_alt_rounded : Icons.upload_file_rounded,
              size: 20,
              color: uploaded ? AppColors.success : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
