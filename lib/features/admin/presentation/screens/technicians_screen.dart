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

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الفنيين'),
        actions: [
          IconButton(
            onPressed: () => _showTechnicianForm(context, ref),
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: techsAsync.when(
        data: (techs) {
          if (techs.isEmpty) {
            return const Center(child: Text('لا يوجد فنيين حالياً'));
          }

          final pendingTechs = techs.where((t) => t.status == TechStatus.pending).toList();
          final approvedTechs = techs.where((t) => t.status != TechStatus.pending).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              if (pendingTechs.isNotEmpty) ...[
                _buildSectionHeader('طلبات انضمام جديدة (${pendingTechs.length})', AppColors.gold),
                ...pendingTechs.map((tech) => TechCard(
                  tech: tech,
                  onEdit: () => _showTechnicianForm(context, ref, technician: tech),
                )),
                const SizedBox(height: AppSpacing.xxl),
                const Divider(),
                const SizedBox(height: AppSpacing.xxl),
              ],
              _buildSectionHeader('الفنيين المعتمدين (${approvedTechs.length})', AppColors.success),
              ...approvedTechs.map((tech) => TechCard(
                tech: tech,
                onEdit: () => _showTechnicianForm(context, ref, technician: tech),
              )),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => AppErrorWidget(
          message: 'حدث خطأ في تحميل البيانات',
          onRetry: () => ref.refresh(techsStreamProvider),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Text(title, style: AppTextStyles.headlineMed.copyWith(color: color)),
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

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (context) => Padding(
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
                Text(
                  technician == null ? 'إضافة فني جديد' : (technician.status == TechStatus.pending ? 'مراجعة واعتماد الفني' : 'تعديل بيانات الفني'),
                  style: AppTextStyles.headlineMed,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                  enabled: technician == null, // لا نغير الرقم الموثق إلا من خلال نظام الدخول
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ServiceType>(
                  value: selectedSpec,
                  decoration: const InputDecoration(labelText: 'التخصص المهني', prefixIcon: Icon(Icons.build)),
                  items: ServiceType.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                  onChanged: (v) => selectedSpec = v!,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: visitPriceController,
                        decoration: const InputDecoration(labelText: 'سعر الزيارة', prefixIcon: Icon(Icons.payments)),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<TechStatus>(
                        value: selectedStatus,
                        decoration: const InputDecoration(labelText: 'الحالة الآن'),
                        items: TechStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                        onChanged: (v) => selectedStatus = v!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'منطقة العمل (اختياري)', prefixIcon: Icon(Icons.location_on)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bioController,
                  decoration: const InputDecoration(labelText: 'نبذة عن الخبرة'),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final dto = UpdateTechnicianDto(
                      name: nameController.text.trim(),
                      spec: selectedSpec,
                      visitPrice: int.tryParse(visitPriceController.text),
                      area: areaController.text.trim(),
                      bio: bioController.text.trim(),
                      status: selectedStatus == TechStatus.pending ? TechStatus.available : selectedStatus,
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت العملية بنجاح')));
                        },
                      );
                    }
                  },
                  child: Text(technician?.status == TechStatus.pending ? 'اعتماد الفني وتفعيل حسابه' : 'حفظ التغييرات'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
