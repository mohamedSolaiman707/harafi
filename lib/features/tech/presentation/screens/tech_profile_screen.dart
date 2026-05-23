import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
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
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () => _showLogoutDialog(context),
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

  void _showLogoutDialog(BuildContext context) {
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
              if (context.mounted) context.go('/');
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
  final _passwordController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tech.name);
    _bioController = TextEditingController(text: widget.tech.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    
    final dto = UpdateTechnicianDto(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
    );

    final result = await ref.read(techsRepositoryProvider).updateTechnician(
      widget.tech.id, 
      dto,
    );

    if (_passwordController.text.isNotEmpty) {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
    }

    result.when(
      left: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
      right: (_) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
          _passwordController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الملف الشخصي بنجاح')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.xxl),
          _buildQuickStats(),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('البيانات الشخصية', style: AppTextStyles.titleLarge),
                    IconButton(
                      icon: Icon(_isEditing ? Icons.close : Icons.edit, size: 20, color: AppColors.gold),
                      onPressed: () => setState(() => _isEditing = !_isEditing),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'الاسم الكامل',
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'نبذة عن خبرتك',
                  controller: _bioController,
                  prefixIcon: Icons.description_outlined,
                  maxLines: 3,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  Text('تغيير كلمة المرور (اختياري)', style: AppTextStyles.titleMed),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'كلمة المرور الجديدة',
                    controller: _passwordController,
                    isPassword: true,
                    prefixIcon: Icons.lock_reset,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'حفظ التغييرات',
                    onTap: _updateProfile,
                    isLoading: _isLoading,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildInfoNote(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.surface2,
            child: Text(widget.tech.spec.icon, style: const TextStyle(fontSize: 40)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(widget.tech.name, style: AppTextStyles.displayMedium),
        Text(widget.tech.spec.label, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.gold, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'إجمالي الأرباح', value: '${widget.tech.totalEarnings} ج.م', icon: Icons.payments, color: AppColors.success)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(label: 'المهمات', value: '${widget.tech.totalJobs}', icon: Icons.build_circle, color: AppColors.info)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(label: 'التقييم', value: widget.tech.rating.toStringAsFixed(1), icon: Icons.star, color: Colors.amber)),
      ],
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لا يمكن تغيير التخصص أو رقم الهاتف الموثق إلا من خلال التواصل مع الإدارة.',
              style: AppTextStyles.bodyMed.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
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
