import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_actions_provider.dart';
import '../providers/techs_provider.dart';
import '../widgets/tech_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/dtos/technician_dtos.dart';
import '../../domain/enums/service_type.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/technician.dart';

class TechniciansScreen extends ConsumerStatefulWidget {
  const TechniciansScreen({super.key});

  @override
  ConsumerState<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends ConsumerState<TechniciansScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final techsAsync = ref.watch(techsStreamProvider);
    final width = MediaQuery.of(context).size.width;
    final sidePadding = width > 1200 ? AppSpacing.xl : AppSpacing.lg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفنيين والخبراء'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => _showTechnicianForm(context, ref),
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text('إضافة فني'),
            ),
          ),
        ],
      ),
      body: techsAsync.when(
        data: (allTechs) {
          final techs = allTechs.where((t) => 
            t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.phone.contains(_searchQuery)
          ).toList();

          if (allTechs.isEmpty) {
            return const Center(child: Text('لا يوجد فنيين مسجلين حالياً'));
          }

          final pendingTechs = techs.where((t) => t.status == TechStatus.pending).toList();
          final approvedTechs = techs.where((t) => t.status != TechStatus.pending).toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 24),
                sliver: SliverToBoxAdapter(
                  child: SearchBar(
                    hintText: 'بحث باسم الفني أو رقم الهاتف...',
                    onChanged: (v) => setState(() => _searchQuery = v),
                    leading: const Icon(Icons.search, color: AppColors.textMuted),
                    backgroundColor: MaterialStateProperty.all(AppColors.surface1),
                    elevation: MaterialStateProperty.all(0),
                    shape: MaterialStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.borderDefault),
                    )),
                  ),
                ),
              ),

              if (pendingTechs.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('طلبات انضمام جديدة', pendingTechs.length, AppColors.gold),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(sidePadding),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 320,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => TechCard(
                        tech: pendingTechs[index],
                        onEdit: () => _showTechnicianForm(context, ref, technician: pendingTechs[index]),
                      ),
                      childCount: pendingTechs.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],

              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionHeader('الفنيين المعتمدين', approvedTechs.length, AppColors.success),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.all(sidePadding),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 300,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => TechCard(
                      tech: approvedTechs[index],
                      onEdit: () => _showTechnicianForm(context, ref, technician: approvedTechs[index]),
                    ),
                    childCount: approvedTechs.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => AppErrorWidget(
          message: 'حدث خطأ في تحميل بيانات الفنيين',
          error: err,
          onRetry: () => ref.invalidate(techsStreamProvider),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(right: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.titleLarge.copyWith(color: color)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showTechnicianForm(BuildContext context, WidgetRef ref, {Technician? technician}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: technician?.name);
    final phoneController = TextEditingController(text: technician?.phone);
    final bioController = TextEditingController(text: technician?.bio);
    final visitPriceController = TextEditingController(text: technician?.visitPrice.toString() ?? '50');
    final areaController = TextEditingController(text: technician?.area);
    
    ServiceType selectedSpec = technician?.spec ?? ServiceType.plumbing;
    TechStatus selectedStatus = technician?.status ?? TechStatus.available;
    bool isVerified = technician?.isVerified ?? false;

    final width = MediaQuery.of(context).size.width;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface1,
      constraints: BoxConstraints(maxWidth: width > 900 ? 550 : width),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        technician == null ? 'إضافة فني جديد' : 'تعديل بيانات الفني',
                        style: AppTextStyles.headlineMed,
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  if (technician != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.surface2, 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDefault)
                      ),
                      child: SwitchListTile(
                        title: const Text('توثيق الحساب (Verified)'),
                        subtitle: const Text('تفعيل العلامة الزرقاء للفني لزيادة الثقة'),
                        secondary: Icon(Icons.verified, color: isVerified ? AppColors.info : AppColors.textMuted),
                        value: isVerified,
                        activeColor: AppColors.info,
                        onChanged: (val) => setModalState(() => isVerified = val),
                      ),
                    ),
                  
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف (واتساب)', prefixIcon: Icon(Icons.phone_outlined)),
                    keyboardType: TextInputType.phone,
                    enabled: technician == null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ServiceType>(
                    value: selectedSpec,
                    decoration: const InputDecoration(labelText: 'التخصص المهني', prefixIcon: Icon(Icons.home_repair_service_outlined)),
                    items: ServiceType.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                    onChanged: (v) => selectedSpec = v!,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: visitPriceController,
                          decoration: const InputDecoration(labelText: 'سعر الزيارة', prefixIcon: Icon(Icons.monetization_on_outlined)),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<TechStatus>(
                          value: selectedStatus == TechStatus.pending ? TechStatus.available : selectedStatus,
                          decoration: const InputDecoration(labelText: 'الحالة الحالية'),
                          items: TechStatus.values.where((s) => s != TechStatus.pending).map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                          onChanged: (v) => selectedStatus = v!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: areaController,
                    decoration: const InputDecoration(labelText: 'منطقة التغطية', prefixIcon: Icon(Icons.map_outlined)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: bioController,
                    decoration: const InputDecoration(labelText: 'نبذة مختصرة عن الخبرة'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    label: technician?.status == TechStatus.pending ? 'اعتماد الحساب الآن' : 'حفظ التعديلات',
                    onTap: () async {
                        if (!formKey.currentState!.validate()) return;

                        if (technician != null && isVerified != technician.isVerified) {
                          await ref.read(adminActionsProvider).toggleVerification(technician.id, isVerified);
                        }

                        final dto = UpdateTechnicianDto(
                          name: nameController.text.trim(),
                          spec: selectedSpec,
                          visitPrice: int.tryParse(visitPriceController.text),
                          area: areaController.text.trim(),
                          bio: bioController.text.trim(),
                          status: selectedStatus,
                        );

                        final result = technician == null 
                          ? await ref.read(adminActionsProvider).addTechnician(CreateTechnicianDto(
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                              spec: selectedSpec,
                              bio: bioController.text.trim(),
                              visitPrice: int.tryParse(visitPriceController.text) ?? 50,
                              area: areaController.text.trim(),
                            ))
                          : await ref.read(adminActionsProvider).updateTechnician(technician.id, dto);

                        if (context.mounted) {
                          result.when(
                            left: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
                            right: (_) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات الفني بنجاح ✅')));
                            },
                          );
                        }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (technician != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      onPressed: () => _confirmDelete(context, ref, technician),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف الفني نهائياً'),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Technician tech) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف فني'),
        content: Text('هل أنت متأكد من حذف الفني "${tech.name}"؟ سيتم مسح كافة بياناته نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final result = await ref.read(adminActionsProvider).deleteTechnician(tech.id);
      if (context.mounted) {
        result.when(
          left: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
          right: (_) {
            Navigator.pop(context); // Close form
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الفني بنجاح')));
          },
        );
      }
    }
  }
}
