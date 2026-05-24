import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_actions_provider.dart';
import '../providers/techs_provider.dart';
import '../widgets/tech_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/dtos/technician_dtos.dart';
import '../../domain/enums/service_type.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/technician.dart';

class TechniciansScreen extends ConsumerWidget {
  const TechniciansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techsAsync = ref.watch(techsStreamProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 1100;
    final sidePadding = width > 1200 ? width * 0.05 : AppSpacing.xl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفنيين والخبراء'),
        centerTitle: !isDesktop,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => _showTechnicianForm(context, ref),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('إضافة فني'),
            ),
          ),
        ],
      ),
      body: techsAsync.when(
        data: (techs) {
          if (techs.isEmpty) {
            return const Center(child: Text('لا يوجد فنيين مسجلين حالياً'));
          }

          final pendingTechs = techs.where((t) => t.status == TechStatus.pending).toList();
          final approvedTechs = techs.where((t) => t.status != TechStatus.pending).toList();
          
          final crossAxisCount = width > 1400 ? 3 : (width > 800 ? 2 : 1);

          return CustomScrollView(
            slivers: [
              // قسم طلبات الانضمام
              if (pendingTechs.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(sidePadding, 24, sidePadding, 16),
                  sliver: SliverToBoxAdapter(
                    child: _buildSectionHeader('طلبات انضمام جديدة (${pendingTechs.length})', AppColors.gold),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                      mainAxisExtent: 340, // ارتفاع بطاقة الفني
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
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],

              // قسم الفنيين المعتمدين
              SliverPadding(
                padding: EdgeInsets.fromLTRB(sidePadding, 24, sidePadding, 16),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionHeader('الفنيين المعتمدين (${approvedTechs.length})', AppColors.success),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: sidePadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: 320,
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
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
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

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Text(title, style: AppTextStyles.headlineMed.copyWith(color: color)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.2))),
      ],
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
      backgroundColor: AppColors.surface2,
      constraints: BoxConstraints(maxWidth: width > 900 ? 600 : width),
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
                      decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(12)),
                      child: SwitchListTile(
                        title: const Text('توثيق الحساب (Verified)'),
                        subtitle: const Text('تفعيل العلامة الزرقاء للفني'),
                        secondary: Icon(Icons.verified, color: isVerified ? AppColors.info : AppColors.textMuted),
                        value: isVerified,
                        activeColor: AppColors.info,
                        onChanged: (val) => setModalState(() => isVerified = val),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
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
                          decoration: const InputDecoration(labelText: 'سعر الزيارة (ج.م)', prefixIcon: Icon(Icons.monetization_on_outlined)),
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
                    decoration: const InputDecoration(labelText: 'نبذة مختصرة عن الفني'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
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
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ البيانات بنجاح')));
                            },
                          );
                        }
                      },
                      child: Text(technician?.status == TechStatus.pending ? 'اعتماد الحساب وتفعيله' : 'تحديث البيانات'),
                    ),
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
}
