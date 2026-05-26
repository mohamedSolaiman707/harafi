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
  
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingPortfolio = false;
  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tech.name);
    _bioController = TextEditingController(text: widget.tech.bio);
    _visitPriceController = TextEditingController(text: widget.tech.visitPrice.toString());
    _selectedArea = widget.tech.area ?? (AppConstants.areas.isNotEmpty ? AppConstants.areas[1] : null);
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
    ref.invalidate(currentTechnicianProvider);
    
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
        ref.invalidate(currentTechnicianProvider);
      }
      setState(() => _isUploadingAvatar = false);
    } else {
      setState(() => _isUploadingPortfolio = true);
      final url = await _storageService.uploadImage(
        image: image, 
        path: 'portfolios', 
        fileName: '${widget.tech.id}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (url != null) {
        final newImages = [...widget.tech.portfolioImages, url];
        await ref.read(techsRepositoryProvider).update(widget.tech.id, {'portfolio_images': newImages});
        ref.invalidate(currentTechnicianProvider);
      }
      setState(() => _isUploadingPortfolio = false);
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
    final horizontalPadding = width > 1200 ? (width - 1100) / 2 : AppSpacing.xl;

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
              if (_isUploadingAvatar)
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
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('معرض سابقة أعمالك', style: AppTextStyles.headlineMed),
            _isUploadingPortfolio 
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('البيانات المهنية', style: AppTextStyles.headlineMed),
              _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton.icon(
                    onPressed: () => _isEditing ? _updateProfile() : setState(() => _isEditing = true),
                    icon: Icon(_isEditing ? Icons.check : Icons.edit),
                    label: Text(_isEditing ? 'حفظ التغييرات' : 'تعديل البيانات'),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(label: 'الاسم الميداني', controller: _nameController, enabled: _isEditing, prefixIcon: Icons.person_outline),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: AppTextField(label: 'سعر الزيارة (ج.م)', controller: _visitPriceController, enabled: _isEditing, keyboardType: TextInputType.number, prefixIcon: Icons.payments_outlined)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedArea,
                  decoration: const InputDecoration(labelText: 'منطقة العمل'),
                  dropdownColor: AppColors.surface2,
                  items: AppConstants.areas.where((a) => a != 'الكل').map((area) => DropdownMenuItem(value: area, child: Text(area))).toList(),
                  onChanged: _isEditing ? (val) => setState(() => _selectedArea = val) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(label: 'نبذة عن خبرتك', controller: _bioController, enabled: _isEditing, prefixIcon: Icons.history_edu_outlined, maxLines: 5),
        ],
      ),
    );
  }

  Widget _buildQuickStats({required bool isRow}) {
    final stats = [
      _StatCard(label: 'إجمالي الأرباح', value: '${widget.tech.totalEarnings} ج.م', icon: Icons.payments, color: AppColors.success),
      _StatCard(label: 'المهمات المنجزة', value: '${widget.tech.totalJobs}', icon: Icons.build_circle, color: AppColors.info),
      _StatCard(label: 'تقييمك العام', value: widget.tech.rating.toStringAsFixed(1), icon: Icons.star, color: Colors.amber),
    ];

    if (isRow) return Row(children: stats.map((s) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: s))).toList());
    
    return Column(children: stats.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: s)).toList());
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.headlineLarge.copyWith(fontSize: 22)),
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
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            const Text('لم نتمكن من العثور على بروفايل فني لهذا الحساب.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            AppButton(label: 'العودة للرئيسية', onTap: () => context.go('/')),
          ],
        ),
      ),
    );
  }
}
