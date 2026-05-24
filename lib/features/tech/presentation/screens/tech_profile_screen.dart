import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/domain/dtos/technician_dtos.dart';

class TechProfileScreen extends ConsumerWidget {
  const TechProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techAsync = ref.watch(currentTechnicianProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي والمهني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.textMuted),
            tooltip: 'تبديل نوع الحساب',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_role');
              await ref.read(currentTechnicianProvider.notifier).clearCache();
              if (context.mounted) context.go('/welcome');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      body: techAsync.when(
        data: (tech) {
          if (tech == null) return const _NoProfileError();
          return _ProfileContent(tech: tech);
        },
        loading: () => const LoadingWidget(),
        error: (e, s) => Center(child: Text('خطأ في تحميل البيانات: $e')),
      ),
    );
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
}

class _ProfileContent extends ConsumerStatefulWidget {
  final Technician tech;
  const _ProfileContent({required this.tech});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _visitPriceController;
  final _storageService = StorageService();
  final _picker = ImagePicker();
  
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tech.name);
    _bioController = TextEditingController(text: widget.tech.bio);
    _visitPriceController = TextEditingController(text: widget.tech.visitPrice.toString());
    _selectedArea = widget.tech.area ?? AppConstants.areas[1];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _visitPriceController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    
    final dto = UpdateTechnicianDto(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      visitPrice: int.tryParse(_visitPriceController.text),
      area: _selectedArea,
    );

    await ref.read(techsRepositoryProvider).updateTechnician(widget.tech.id, dto);
    ref.invalidate(techniciansProvider);
    
    setState(() {
      _isEditing = false;
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source, bool isAvatar) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: isAvatar ? 500 : 1200,
    );

    if (image == null) return;

    if (isAvatar) {
      setState(() => _isUploadingAvatar = true);
      final url = await _storageService.uploadImage(
        image: image, 
        path: 'avatars', 
        fileName: widget.tech.id,
      );
      if (url != null) {
        await ref.read(techsRepositoryProvider).update(widget.tech.id, {'photo_url': url});
        ref.invalidate(techniciansProvider);
      }
      setState(() => _isUploadingAvatar = false);
    } else {
      final url = await _storageService.uploadImage(
        image: image, 
        path: 'portfolios', 
        fileName: '${widget.tech.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (url != null) {
        final newImages = [...widget.tech.portfolioImages, url];
        await ref.read(techsRepositoryProvider).update(widget.tech.id, {'portfolio_images': newImages});
        ref.invalidate(techniciansProvider);
      }
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
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('اختر مصدر الصورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.gold),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isAvatar);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: const Text('اختيار من معرض الصور'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isAvatar);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.xxl),
              _buildQuickStats(),
              const SizedBox(height: AppSpacing.xxl),
              _buildGallerySection(),
              const SizedBox(height: AppSpacing.xxl),
              _buildInfoForm(),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
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
                backgroundImage: widget.tech.photoUrl != null ? NetworkImage(widget.tech.photoUrl!) : null,
                child: widget.tech.photoUrl == null 
                    ? Text(widget.tech.spec.icon, style: const TextStyle(fontSize: 48))
                    : null,
              ),
            ),
            if (_isUploadingAvatar)
              const Positioned.fill(child: CircularProgressIndicator(color: AppColors.gold))
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.tech.name, style: AppTextStyles.displayMedium),
            if (widget.tech.isVerified) ...[
              const SizedBox(width: 8),
              const Icon(Icons.verified, color: AppColors.info, size: 24),
            ],
          ],
        ),
        Text(widget.tech.spec.label, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('معرض سابقة أعمالك', style: AppTextStyles.titleLarge),
            IconButton(
              onPressed: () => _showImageSourceSheet(false),
              icon: const Icon(Icons.add_a_photo_outlined, color: AppColors.gold),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.tech.portfolioImages.isEmpty)
          const Text('لم تقم بإضافة صور لأعمالك بعد.')
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.tech.portfolioImages.length,
              itemBuilder: (context, index) {
                final url = widget.tech.portfolioImages[index];
                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildInfoForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('البيانات المهنية', style: AppTextStyles.titleLarge),
              AppButton(
                label: _isEditing ? 'حفظ' : 'تعديل',
                size: ButtonSize.sm,
                variant: _isEditing ? ButtonVariant.primary : ButtonVariant.ghost,
                onTap: () => _isEditing ? _updateProfile() : setState(() => _isEditing = true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'الاسم الميداني',
            controller: _nameController,
            enabled: _isEditing,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'سعر الزيارة (ج.م)',
                  controller: _visitPriceController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedArea,
                  decoration: const InputDecoration(labelText: 'منطقة العمل'),
                  dropdownColor: AppColors.surface2,
                  items: AppConstants.areas.where((a) => a != 'الكل').map((area) => DropdownMenuItem(
                    value: area,
                    child: Text(area),
                  )).toList(),
                  onChanged: _isEditing ? (val) => setState(() => _selectedArea = val) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'تكلم عن خبرتك',
            controller: _bioController,
            enabled: _isEditing,
            prefixIcon: Icons.history_edu_outlined,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'إيراداتك', value: '${widget.tech.totalEarnings} ج.م', icon: Icons.payments, color: AppColors.success)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(label: 'عملياتك', value: '${widget.tech.totalJobs}', icon: Icons.build_circle, color: AppColors.info)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(label: 'تقييمك', value: widget.tech.rating.toStringAsFixed(1), icon: Icons.star, color: Colors.amber)),
      ],
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
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.8), size: 24),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.labelMed, textAlign: TextAlign.center),
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('لم يتم العثور على بيانات فني لهذا الحساب.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AppButton(label: 'العودة للرئيسية', onTap: () => context.go('/')),
          ],
        ),
      ),
    );
  }
}
