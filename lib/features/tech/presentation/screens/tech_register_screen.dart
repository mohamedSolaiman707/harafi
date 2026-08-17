import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/storage_service.dart';
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
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _pickIdImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
    );
    if (image != null) {
      ref.read(techRegisterIdProofProvider.notifier).state = image;
    }
  }

  void _showImageSourceSheet() {
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
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'صورة إثبات الهوية (بطاقة/كارنيه)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.gold,
              ),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () {
                Navigator.pop(context);
                _pickIdImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.gold,
              ),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickIdImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final selectedSpec = ref.read(techRegisterSpecProvider);
    final idProofImage = ref.read(techRegisterIdProofProvider);
    final selectedCity = ref.read(techRegisterCityProvider);

    if (!_formKey.currentState!.validate() || selectedSpec == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى ملء جميع البيانات')));
      return;
    }
    if (idProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى رفع صورة إثبات الهوية للتوثيق')),
      );
      return;
    }

    ref.read(techRegisterLoadingProvider.notifier).state = true;
    try {
      final phone = _phoneController.text.trim();
      final dummyEmail = '$phone@harafi.com';

      // 1. إنشاء حساب Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: dummyEmail,
        password: _passwordController.text.trim(),
      );

      if (authResponse.user == null) throw 'فشل إنشاء الحساب';
      String userId = authResponse.user!.id;

      // 2. رفع صورة إثبات الهوية
      final imageUrl = await _storageService.uploadImage(
        image: idProofImage,
        path: 'tech_photos',
        fileName: userId,
      );

      // 3. حفظ بيانات الفني مع المسميات الصحيحة للأعمدة
      final technicianData = {
        'id': userId,
        'name': _nameController.text.trim(),
        'phone': phone,
        'spec': selectedSpec.label,
        'bio': _bioController.text.trim(),
        'visit_price': int.tryParse(_visitPriceController.text) ?? 50,
        'area': selectedCity,
        'photo_url': imageUrl,
        'status': TechStatus.available.label, // متاح فور التسجيل
        'is_verified': false,
        'total_earnings': 0,
        'total_jobs': 0,
        'wallet_balance': 100, // هدية انضمام 100 ج.م فور التسجيل
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في التسجيل: $e')));
      }
    } finally {
      if (mounted) ref.read(techRegisterLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(techRegisterLoadingProvider);
    final selectedGov = ref.watch(techRegisterGovProvider);
    final selectedCity = ref.watch(techRegisterCityProvider);
    final idProofImage = ref.watch(techRegisterIdProofProvider);
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
                  const Icon(
                    Icons.handyman_rounded,
                    size: 64,
                    color: AppColors.gold,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('سجل بياناتك المهنية', style: AppTextStyles.headlineMed),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'الاسم الكامل',
                          controller: _nameController,
                          prefixIcon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'رقم الهاتف',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_android,
                          validator: (v) =>
                              v!.length < 11 ? 'رقم غير صحيح' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'كلمة المرور',
                          controller: _passwordController,
                          isPassword: true,
                          prefixIcon: Icons.lock_outline,
                          validator: (v) => v!.length < 6
                              ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // قسم رفع الهوية
                        InkWell(
                          onTap: _showImageSourceSheet,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: idProofImage != null
                                    ? AppColors.success
                                    : AppColors.borderDefault,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  idProofImage != null
                                      ? Icons.check_circle
                                      : Icons.badge_outlined,
                                  color: idProofImage != null
                                      ? AppColors.success
                                      : AppColors.gold,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    idProofImage != null
                                        ? 'تم اختيار صورة الهوية'
                                        : 'ارفع صورة البطاقة أو كارنيه المهنة',
                                  ),
                                ),
                                const Icon(Icons.upload_file, size: 18),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<ServiceType>(
                          decoration: const InputDecoration(
                            labelText: 'التخصص المهني',
                            prefixIcon: Icon(Icons.build_circle_outlined),
                          ),
                          dropdownColor: AppColors.surface2,
                          items: ServiceType.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.label),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              ref.read(techRegisterSpecProvider.notifier).state = val,
                          validator: (v) =>
                              v == null ? 'يرجى اختيار التخصص' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'سعر الزيارة (ج.م)',
                          controller: _visitPriceController,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.monetization_on_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // اختيار المحافظة والمدينة
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedGov,
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
                                    ref.read(techRegisterCityProvider.notifier).state =
                                        AppConstants.governoratesAndCities[val]!.first;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: AppConstants.governoratesAndCities[selectedGov]!.contains(selectedCity)
                                    ? selectedCity
                                    : AppConstants.governoratesAndCities[selectedGov]!.first,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'المدينة / منطقة العمل',
                                  prefixIcon: Icon(Icons.location_city_outlined),
                                ),
                                dropdownColor: AppColors.surface2,
                                items: (AppConstants.governoratesAndCities[selectedGov] ?? [])
                                    .map((city) => DropdownMenuItem(value: city, child: Text(city, overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    ref.read(techRegisterCityProvider.notifier).state = val;
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        AppButton(
                          label: 'إنشاء الحساب والبدء',
                          onTap: _submit,
                          isLoading: isLoading,
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
