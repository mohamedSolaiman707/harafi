import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_actions_provider.dart';
import '../providers/techs_provider.dart';
import '../widgets/tech_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../domain/dtos/technician_dtos.dart';
import '../../domain/enums/service_type.dart';
import '../../domain/enums/tech_status.dart';
import '../../domain/models/technician.dart';

class TechniciansScreen extends ConsumerWidget {
  const TechniciansScreen({super.key});

  Future<void> _showTechnicianForm(
    BuildContext context,
    WidgetRef ref, {
    Technician? technician,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: technician?.name ?? '');
    final phoneController = TextEditingController(
      text: technician?.phone ?? '',
    );
    final areaController = TextEditingController(text: technician?.area ?? '');
    final priceController = TextEditingController(
      text: technician?.priceRange ?? '',
    );
    final visitPriceController = TextEditingController(
      text: technician?.visitPrice.toString() ?? '',
    );
    final photoUrlController = TextEditingController(text: technician?.photoUrl ?? '');
    final bioController = TextEditingController(text: technician?.bio ?? '');
    final earningsController = TextEditingController(text: technician?.totalEarnings.toString() ?? '0');

    ServiceType selectedSpec = technician?.spec ?? ServiceType.plumbing;
    TechStatus selectedStatus = technician?.status ?? TechStatus.available;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    technician == null
                        ? 'إضافة فني جديد'
                        : 'تعديل بيانات الفني',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'اسم الفني'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty)
                        return 'اسم الفني مطلوب';
                      if (value.trim().length < 3) return 'الاسم قصير جداً';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty)
                        return 'الرقم مطلوب';
                      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (cleaned.length < 10) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ServiceType>(
                    value: selectedSpec,
                    decoration: const InputDecoration(labelText: 'التخصص'),
                    items: ServiceType.values.map((service) {
                      return DropdownMenuItem(
                        value: service,
                        child: Text(service.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) selectedSpec = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'نطاق السعر (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: visitPriceController,
                    decoration: const InputDecoration(
                      labelText: 'سعر الزيارة (ج.م)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: areaController,
                    decoration: const InputDecoration(
                      labelText: 'المنطقة (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: photoUrlController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الصورة الشخصية',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bioController,
                    decoration: const InputDecoration(
                      labelText: 'نبذة عن الفني',
                    ),
                    maxLines: 3,
                  ),
                  if (technician != null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: earningsController,
                      decoration: const InputDecoration(
                        labelText: 'إجمالي الأرباح (ج.م)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TechStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: TechStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) selectedStatus = value;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      if (technician == null) {
                        final createDto = CreateTechnicianDto(
                          name: nameController.text.trim(),
                          phone: phoneController.text.trim(),
                          spec: selectedSpec,
                          priceRange: priceController.text.trim().isEmpty
                              ? null
                              : priceController.text.trim(),
                          visitPrice: int.tryParse(
                            visitPriceController.text.trim(),
                          ),
                          area: areaController.text.trim().isEmpty
                              ? null
                              : areaController.text.trim(),
                          photoUrl: photoUrlController.text.trim().isEmpty ? null : photoUrlController.text.trim(),
                          bio: bioController.text.trim().isEmpty ? null : bioController.text.trim(),
                        );
                        final result = await ref
                            .read(adminActionsProvider)
                            .addTechnician(createDto);
                        if (!context.mounted) return;
                        result.when(
                          left: (failure) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(failure.message)),
                            );
                          },
                          right: (_) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إضافة الفني')),
                            );
                          },
                        );
                        return;
                      }

                      final updateDto = UpdateTechnicianDto(
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        spec: selectedSpec,
                        priceRange: priceController.text.trim().isEmpty
                            ? null
                            : priceController.text.trim(),
                        visitPrice: int.tryParse(
                          visitPriceController.text.trim(),
                        ),
                        area: areaController.text.trim().isEmpty
                            ? null
                            : areaController.text.trim(),
                        status: selectedStatus,
                        photoUrl: photoUrlController.text.trim().isEmpty ? null : photoUrlController.text.trim(),
                        bio: bioController.text.trim().isEmpty ? null : bioController.text.trim(),
                        totalEarnings: int.tryParse(earningsController.text.trim()),
                      );
                      final result = await ref
                          .read(adminActionsProvider)
                          .updateTechnician(technician.id, updateDto);
                      if (!context.mounted) return;
                      result.when(
                        left: (failure) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(failure.message)),
                          );
                        },
                        right: (_) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تحديث بيانات الفني'),
                            ),
                          );
                        },
                      );
                    },
                    child: Text(
                      technician == null ? 'إضافة الفني' : 'حفظ التغييرات',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
            return const Center(child: Text('لا يوجد فنيين مسجلين حالياً'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: techs.length,
            itemBuilder: (context, index) {
              final tech = techs[index];
              return TechCard(
                tech: tech,
                onEdit: () =>
                    _showTechnicianForm(context, ref, technician: tech),
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => AppErrorWidget(
          message: 'حدث خطأ أثناء تحميل بيانات الفنيين',
          onRetry: () => ref.refresh(techsStreamProvider),
        ),
      ),
    );
  }
}
