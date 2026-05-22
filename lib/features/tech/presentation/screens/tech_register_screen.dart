import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/dtos/technician_dtos.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/presentation/providers/techs_provider.dart';

class TechRegisterScreen extends ConsumerStatefulWidget {
  const TechRegisterScreen({super.key});

  @override
  ConsumerState<TechRegisterScreen> createState() => _TechRegisterScreenState();
}

class _TechRegisterScreenState extends ConsumerState<TechRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  ServiceType? _selectedSpec;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedSpec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع البيانات واختيار التخصص')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final dto = CreateTechnicianDto(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      spec: _selectedSpec!,
      bio: _bioController.text.trim(),
      visitPrice: 50, // سعر افتراضي
    );

    final result = await ref.read(techsRepositoryProvider).addTechnician(dto);

    result.when(
      left: (failure) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${failure.message}')),
        );
      },
      right: (tech) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('تم استلام طلبك'),
            content: const Text(
              'شكراً لاهتمامك بالانضمام لحرافي. طلبك الآن قيد المراجعة من قبل الإدارة، وسنتواصل معك قريباً بمجرد الموافقة عليه.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/');
                },
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلب انضمام فني')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.engineering_outlined, size: 64, color: AppColors.gold),
                  const SizedBox(height: AppSpacing.lg),
                  Text('كن جزءاً من فريق حرافي', style: AppTextStyles.headlineMed),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'الاسم الكامل',
                          controller: _nameController,
                          hint: 'أدخل اسمك كما في البطاقة',
                          prefixIcon: Icons.person_outline,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'رقم الهاتف',
                          controller: _phoneController,
                          hint: '01xxxxxxxxx',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_android,
                          validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        DropdownButtonFormField<ServiceType>(
                          decoration: const InputDecoration(
                            labelText: 'التخصص',
                            prefixIcon: Icon(Icons.build_circle_outlined),
                          ),
                          dropdownColor: AppColors.surface2,
                          items: ServiceType.values.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedSpec = val),
                          validator: (v) => v == null ? 'يرجى اختيار التخصص' : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'نبذة عن خبرتك (اختياري)',
                          controller: _bioController,
                          hint: 'مثال: خبرة 10 سنوات في صيانة السباكة المنزلية',
                          maxLines: 3,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        AppButton(
                          label: 'إرسال طلب الانضمام',
                          onTap: _submitRequest,
                          isLoading: _isLoading,
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
