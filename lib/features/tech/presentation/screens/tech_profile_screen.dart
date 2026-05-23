import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
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
            icon: const Icon(Icons.logout, color: AppColors.error),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go('/');
            },
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
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tech.name);
    _bioController = TextEditingController(text: widget.tech.bio);
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    final dto = UpdateTechnicianDto(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
    );
    
    final result = await ref.read(techsRepositoryProvider).updateTechnician(widget.tech.id, dto);
    
    result.when(
      left: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
      right: (_) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: AppSpacing.xl),
          _buildQuickStats(),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('البيانات الأساسية', style: AppTextStyles.titleLarge),
                    IconButton(
                      icon: Icon(_isEditing ? Icons.close : Icons.edit, size: 20),
                      onPressed: () => setState(() => _isEditing = !_isEditing),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildField('الاسم', _nameController, Icons.person_outline),
                const SizedBox(height: AppSpacing.md),
                _buildField('رقم الهاتف (موثق)', TextEditingController(text: widget.tech.phone), Icons.phone_android, enabled: false),
                const SizedBox(height: AppSpacing.md),
                _buildField('نبذة عنك', _bioController, Icons.description_outlined, maxLines: 3),
                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(label: 'حفظ التغييرات', onTap: _saveChanges, isLoading: _isLoading),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.gold.withOpacity(0.1),
          child: Text(widget.tech.spec.icon, style: const TextStyle(fontSize: 40)),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'الأرباح', value: '${widget.tech.totalEarnings} ج.م', icon: Icons.payments, color: AppColors.success)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(label: 'العمليات', value: '${widget.tech.totalJobs}', icon: Icons.task_alt, color: AppColors.info)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _StatCard(label: 'التقييم', value: '${widget.tech.rating}', icon: Icons.star, color: Colors.amber)),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {bool enabled = true, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing && enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: _isEditing && enabled ? null : InputBorder.none,
        filled: _isEditing && enabled,
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
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleLarge),
          Text(label, style: AppTextStyles.labelMed),
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
          const Text('لم يتم العثور على بيانات فني لهذا الحساب'),
          const SizedBox(height: 16),
          AppButton(label: 'إكمال التسجيل', onTap: () => context.go('/tech/register')),
        ],
      ),
    );
  }
}
