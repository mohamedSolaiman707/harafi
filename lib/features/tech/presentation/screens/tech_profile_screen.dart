import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/dtos/technician_dtos.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../providers/tech_screen_providers.dart';

class TechProfileScreen extends ConsumerStatefulWidget {
  const TechProfileScreen({super.key});

  @override
  ConsumerState<TechProfileScreen> createState() => _TechProfileScreenState();
}

class _TechProfileScreenState extends ConsumerState<TechProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final techAsync = ref.watch(currentTechnicianProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, ref),

          )
        ],
      ),
      body: techAsync.when(
        data: (tech) => tech == null 
            ? const _NoProfileError() 
            : _ProfileContent(tech: tech, isDesktop: MediaQuery.of(context).size.width > 900),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}

void _showLogoutDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('تسجيل الخروج'),
      content: const Text('هل أنت متأكد أنك تريد الخروج من حسابك؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        TextButton(
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            await ref.read(currentTechnicianProvider.notifier).clearCache();
            if (context.mounted) {
              Navigator.pop(context);
              context.go('/welcome');
            }
          },
          child: const Text('خروج', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );
}

class _ProfileContent extends ConsumerStatefulWidget {
  final Technician tech;
  final bool isDesktop;
  const _ProfileContent({required this.tech, required this.isDesktop});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _visitPriceController;
  final _storageService = StorageService();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tech.name);
    _bioController = TextEditingController(text: widget.tech.bio);
    _visitPriceController = TextEditingController(text: widget.tech.visitPrice.toString());

    // تحديد المحافظة تلقائياً من المدينة المحفوظة للفني
    String? selectedGov;
    String? selectedArea;
    final savedArea = widget.tech.area;
    if (savedArea != null) {
      for (final entry in AppConstants.governoratesAndCities.entries) {
        if (entry.value.contains(savedArea)) {
          selectedGov = entry.key;
          selectedArea = savedArea;
          break;
        }
      }
    }
    selectedGov ??= AppConstants.governoratesAndCities.keys.first;
    selectedArea ??= AppConstants.governoratesAndCities[selectedGov]!.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(techProfileGovProvider.notifier).state = selectedGov;
        ref.read(techProfileAreaProvider.notifier).state = selectedArea;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _visitPriceController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    ref.read(techProfileLoadingProvider.notifier).state = true;
    final selectedArea = ref.read(techProfileAreaProvider);
    
    final dto = UpdateTechnicianDto(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      visitPrice: int.tryParse(_visitPriceController.text),
      area: selectedArea,
    );

    final result = await ref.read(techsRepositoryProvider).updateTechnician(widget.tech.id, dto);
    result.when(
      left: (f) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${f.message}')));
      },
      right: (updatedTech) {
        ref.read(currentTechnicianProvider.notifier).updateTech(updatedTech);
      },
    );
    
    if (mounted) {
      ref.read(techProfileEditingProvider.notifier).state = false;
      ref.read(techProfileLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _pickImage(ImageSource source, bool isAvatar) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: isAvatar ? 500 : 1200,
    );

    if (image == null) return;

    if (isAvatar) {
      ref.read(techProfileAvatarUploadingProvider.notifier).state = true;
      final url = await _storageService.uploadImage(
        image: image, 
        path: 'avatars', 
        fileName: widget.tech.id,
      );
      if (url != null) {
        final updatedTech = await ref.read(techsRepositoryProvider).update(widget.tech.id, {'photo_url': url});
        ref.read(currentTechnicianProvider.notifier).updateTech(updatedTech);
      }
      if (mounted) ref.read(techProfileAvatarUploadingProvider.notifier).state = false;
    } else {
      ref.read(techProfilePortfolioUploadingProvider.notifier).state = true;
      final url = await _storageService.uploadImage(
        image: image, 
        path: 'portfolios', 
        fileName: '${widget.tech.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (url != null) {
        final newImages = [...widget.tech.portfolioImages, url];
        final updatedTech = await ref.read(techsRepositoryProvider).update(widget.tech.id, {'portfolio_images': newImages});
        ref.read(currentTechnicianProvider.notifier).updateTech(updatedTech);
      }
      if (mounted) ref.read(techProfilePortfolioUploadingProvider.notifier).state = false;
    }
  }

  void _showImageSourceSheet(bool isAvatar) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.gold),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera, isAvatar); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: const Text('اختيار من معرض الصور'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery, isAvatar); },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width > 1200 ? (width - 1100) / 2 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: AppSpacing.xl),
      child: widget.isDesktop 
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildQuickStats(isRow: false),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xxxl),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildInfoForm(),
                      const SizedBox(height: AppSpacing.xxxl),
                      _buildGallerySection(),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.xxl),
                _buildQuickStats(isRow: true),
                const SizedBox(height: AppSpacing.xxl),
                _buildInfoForm(),
                const SizedBox(height: AppSpacing.xxl),
                _buildGallerySection(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final isUploadingAvatar = ref.watch(techProfileAvatarUploadingProvider);
    return AppCard(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.surface2,
                  backgroundImage: widget.tech.photoUrl != null && widget.tech.photoUrl!.isNotEmpty 
                      ? NetworkImage(widget.tech.photoUrl!) : null,
                  child: widget.tech.photoUrl == null || widget.tech.photoUrl!.isEmpty
                      ? Text(widget.tech.spec.icon, style: const TextStyle(fontSize: 48))
                      : null,
                ),
              ),
              if (isUploadingAvatar)
                const Positioned.fill(child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
              else
                GestureDetector(
                  onTap: () => _showImageSourceSheet(true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(widget.tech.name, style: AppTextStyles.headlineLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.tech.spec.label, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold)),
              if (widget.tech.isVerified) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified, color: AppColors.info, size: 18),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // شارة الرتبة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.tech.rankColor.withValues(alpha: 0.25), widget.tech.rankColor.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: widget.tech.rankColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.tech.rankEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  widget.tech.rank,
                  style: TextStyle(
                    color: widget.tech.rankColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (widget.tech.isVerified) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: AppColors.info, size: 16),
                  SizedBox(width: 6),
                  Text('فني موثق', style: TextStyle(color: AppColors.info, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          // شريط التقدم نحو الرتبة التالية
          if (widget.tech.jobsToNextRank > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تبقى ${widget.tech.jobsToNextRank} طلب',
                        style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted),
                      ),
                      Text(
                        widget.tech.nextRankTitle,
                        style: TextStyle(color: widget.tech.rankColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: widget.tech.nextRankProgress.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.surface3,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.tech.rankColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    final isUploadingPortfolio = ref.watch(techProfilePortfolioUploadingProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('معرض سابقة أعمالك', style: AppTextStyles.headlineMed),
            isUploadingPortfolio 
              ? const CircularProgressIndicator(strokeWidth: 2)
              : FilledButton.icon(
                  onPressed: () => _showImageSourceSheet(false),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('إضافة صورة'),
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (widget.tech.portfolioImages.isEmpty)
          AppCard(
            color: AppColors.surface2,
            child: const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('لم تقم بإضافة صور لأعمالك السابقة بعد، أضف صوراً لجذب العملاء!'),
            )),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.isDesktop ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widget.tech.portfolioImages.length,
            itemBuilder: (context, index) {
              final imageUrl = widget.tech.portfolioImages[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.surface2,
                    child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppColors.surface2,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInfoForm() {
    final isEditing = ref.watch(techProfileEditingProvider);
    final isLoading = ref.watch(techProfileLoadingProvider);
    final selectedGov = ref.watch(techProfileGovProvider) ?? AppConstants.governoratesAndCities.keys.first;
    final selectedArea = ref.watch(techProfileAreaProvider) ?? AppConstants.governoratesAndCities[selectedGov]?.first;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('البيانات المهنية', style: AppTextStyles.headlineMed),
              isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton.icon(
                    onPressed: () => isEditing ? _updateProfile() : ref.read(techProfileEditingProvider.notifier).state = true,
                    icon: Icon(isEditing ? Icons.check : Icons.edit),
                    label: Text(isEditing ? 'حفظ التغييرات' : 'تعديل البيانات'),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(label: 'الاسم الميداني', controller: _nameController, enabled: isEditing, prefixIcon: Icons.person_outline),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'سعر الزيارة (ج.م)',
            controller: _visitPriceController,
            enabled: isEditing,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.payments_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
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
                  onChanged: isEditing
                      ? (val) {
                          if (val != null) {
                            ref.read(techProfileGovProvider.notifier).state = val;
                            ref.read(techProfileAreaProvider.notifier).state =
                                AppConstants.governoratesAndCities[val]!.first;
                          }
                        }
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: (AppConstants.governoratesAndCities[selectedGov] ?? []).contains(selectedArea)
                      ? selectedArea
                      : AppConstants.governoratesAndCities[selectedGov]?.first,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'المدينة / منطقة العمل',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  dropdownColor: AppColors.surface2,
                  items: (AppConstants.governoratesAndCities[selectedGov] ?? [])
                      .map((city) => DropdownMenuItem(value: city, child: Text(city, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: isEditing
                      ? (val) {
                          if (val != null) ref.read(techProfileAreaProvider.notifier).state = val;
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(label: 'نبذة عن خبرتك', controller: _bioController, enabled: isEditing, prefixIcon: Icons.history_edu_outlined, maxLines: 5),
        ],
      ),
    );
  }

  Widget _buildQuickStats({required bool isRow}) {
    final stats = [
      _StatCard(label: 'إجمالي الأرباح', value: '${widget.tech.totalEarnings} ج.م', icon: Icons.payments_rounded, color: AppColors.success),
      _StatCard(label: 'مهام مكتملة', value: '${widget.tech.totalJobs}', icon: Icons.task_alt_rounded, color: AppColors.info),
      _StatCard(label: 'التقييم العام', value: '${widget.tech.rating.toStringAsFixed(1)} ★', icon: Icons.star_rounded, color: AppColors.gold),
      _StatCard(label: 'رصيد المحفظة', value: '${widget.tech.walletBalance} ج.م', icon: Icons.account_balance_wallet_rounded, color: AppColors.primary),
    ];

    // شبكة 2×2 تعمل على الموبايل وعمود 4 على الديسكتوب
    if (isRow) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: stats,
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 1,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 3.5,
      children: stats,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(value, style: AppTextStyles.titleMed.copyWith(fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoProfileError extends StatelessWidget {
  const _NoProfileError();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('لم يتم العثور على بيانات الفني'),
          const SizedBox(height: 24),
          AppButton(label: 'تسجيل الخروج', onTap: () => Supabase.instance.client.auth.signOut()),
        ],
      ),
    );
  }
}
