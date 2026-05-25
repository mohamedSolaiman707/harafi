import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/models/technician.dart';
import '../../../admin/presentation/providers/techs_provider.dart';
import '../../../admin/presentation/providers/admin_actions_provider.dart';

class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({super.key});

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();
  ServiceType? _selectedService;
  String? _preSelectedTechId;
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedClientData();
  }

  Future<void> _loadSavedClientData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('client_name') ?? '';
      _phoneController.text = prefs.getString('client_phone') ?? '';
      _areaController.text = prefs.getString('client_area') ?? '';
    });
  }

  Future<void> _saveClientData(String trackingCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('client_name', _nameController.text.trim());
    await prefs.setString('client_phone', _phoneController.text.trim());
    await prefs.setString('client_area', _areaController.text.trim());
    await prefs.setString('last_tracked_code', trackingCode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final extra = GoRouterState.of(context).extra;
      if (extra is ServiceType) {
        _selectedService = extra;
      } else if (extra is Map<String, dynamic>) {
        _selectedService = extra['service'] as ServiceType?;
        _preSelectedTechId = extra['techId'] as String?;
      }
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار نوع الخدمة أولاً')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final order = Order(
        id: '',
        trackingCode: '',
        clientName: _nameController.text.trim(),
        clientPhone: _phoneController.text.trim(),
        service: _selectedService!,
        area: _areaController.text.trim(),
        description: _descriptionController.text.trim(),
        techId: _preSelectedTechId,
        status: _preSelectedTechId != null ? OrderStatus.assigned : OrderStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await ref.read(adminActionsProvider).createOrder(order);

      result.when(
        left: (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${f.message}'))),
        right: (createdOrder) async {
          await _saveClientData(createdOrder.trackingCode);
          if (mounted) _showSuccessDialog(createdOrder);
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ غير متوقع: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(Order result) {
    Technician? tech;
    if (_preSelectedTechId != null) {
      final techs = ref.read(techniciansProvider).valueOrNull ?? [];
      tech = techs.where((t) => t.id == _preSelectedTechId).firstOrNull;
    }

    final width = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface1,
        insetPadding: EdgeInsets.symmetric(horizontal: width > 600 ? (width - 500) / 2 : 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.gold, width: 0.5)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 80),
            const SizedBox(height: 20),
            Text('تم استلام طلبك بنجاح!', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 24),
            if (tech != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface2, 
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(color: AppColors.gold.withOpacity(0.2))
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 25, backgroundColor: AppColors.surface3, child: Text(tech.spec.icon, style: const TextStyle(fontSize: 24))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الفني المختار:', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
                          Text(tech.name, style: AppTextStyles.titleLarge),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('كود التتبع الخاص بك:', style: AppTextStyles.labelLarge),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: result.trackingCode));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود')));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.background, 
                  borderRadius: BorderRadius.circular(12), 
                  border: Border.all(color: AppColors.gold.withOpacity(0.5))
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(result.trackingCode, style: AppTextStyles.displayMedium.copyWith(color: AppColors.gold, fontSize: 28, letterSpacing: 3)),
                    const SizedBox(width: 16),
                    const Icon(Icons.copy, size: 20, color: AppColors.gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tech != null ? 'الفني سيتواصل معك قريباً لتأكيد الموعد.' : 'سنقوم بتعيين أفضل فني متاح والتواصل معك عبر الواتساب.', 
              textAlign: TextAlign.center, 
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary)
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/'), 
            child: Text('الرئيسية', style: TextStyle(color: AppColors.textMuted))
          ),
          SizedBox(
            width: 140,
            child: AppButton(
              label: 'تتبع الطلب', 
              size: ButtonSize.sm, 
              onTap: () => context.go('/track/${result.trackingCode}')
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب خدمة منزلية'), 
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStepHeader('1', 'تأكيد نوع الخدمة'),
                  const SizedBox(height: AppSpacing.lg),
                  _buildServiceGrid(width),
                  const SizedBox(height: AppSpacing.xxxl),
                  _buildStepHeader('2', 'بيانات التواصل والعنوان'),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      children: [
                        AppTextField(label: 'الاسم الكامل', controller: _nameController, prefixIcon: Icons.person_outline, validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'رقم الهاتف (واتساب)', controller: _phoneController, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_android_outlined, validator: (v) => v!.length < 11 ? 'يرجى إدخال رقم صحيح' : null),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'العنوان بالتفصيل (المنطقة والشارع)', controller: _areaController, prefixIcon: Icons.location_on_outlined, validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(label: 'وصف المشكلة (اختياري)', controller: _descriptionController, hint: 'اشرح لنا المشكلة باختصار لنساعدك بشكل أفضل', maxLines: 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppButton(
                    label: 'إرسال طلب الخدمة الآن', 
                    onTap: _submit, 
                    isLoading: _isLoading, 
                    icon: Icons.check_circle_rounded
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String step, String title) {
    return Row(
      children: [
        Container(
          width: 32, 
          height: 32, 
          decoration: BoxDecoration(
            color: AppColors.gold, 
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
            ]
          ), 
          child: Center(child: Text(step, style: const TextStyle(color: AppColors.background, fontWeight: FontWeight.bold)))
        ),
        const SizedBox(width: 16),
        Text(title, style: AppTextStyles.headlineMed.copyWith(letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildServiceGrid(double width) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: width > 600 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 70, // زيادة الارتفاع لراحة أكبر
      ),
      itemCount: ServiceType.values.length,
      itemBuilder: (context, index) {
        final type = ServiceType.values[index];
        final isSelected = _selectedService == type;
        final isEnabled = _preSelectedTechId == null;
        
        return InkWell(
          onTap: isEnabled ? () => setState(() => _selectedService = type) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.gold.withOpacity(0.08) : AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected ? AppColors.gold : AppColors.borderDefault, 
                width: isSelected ? 2 : 1
              ),
              boxShadow: isSelected ? [
                BoxShadow(color: AppColors.gold.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
              ] : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.gold.withOpacity(0.2) : AppColors.surface2,
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(type.icon, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    type.label, 
                    style: AppTextStyles.titleMed.copyWith(
                      color: isSelected ? AppColors.gold : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ), 
                    overflow: TextOverflow.ellipsis
                  )
                ),
                if (isSelected) 
                  const Icon(Icons.check_circle, color: AppColors.gold, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
