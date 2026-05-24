import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/whatsapp_utils.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../admin/presentation/providers/orders_provider.dart';
import '../../../admin/domain/models/order.dart';
import '../../../admin/domain/enums/order_status.dart';
import '../../../admin/presentation/providers/admin_actions_provider.dart';

class TechOrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const TechOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(ordersStreamProvider).whenData(
      (orders) => orders.where((o) => o.id == orderId).firstOrNull,
    );

    return orderAsync.when(
      data: (order) {
        if (order == null) return const Scaffold(body: Center(child: Text('الطلب غير موجود')));

        return Scaffold(
          appBar: AppBar(title: Text('طلب #${order.trackingCode}')),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(ordersStreamProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusBanner(status: order.status),
                  const SizedBox(height: AppSpacing.lg),
                  _buildClientInfo(order),
                  const SizedBox(height: AppSpacing.xl),
                  _buildOrderDescription(order),
                  
                  if (order.completionImages.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _buildCompletionImages(context, order.completionImages),
                  ],

                  if (order.techNotes != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _buildTechReport(order),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _buildActionButtons(context, ref, order),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, s) => Scaffold(
        body: AppErrorWidget(
          message: 'خطأ في تحميل البيانات',
          error: e,
          onRetry: () => ref.invalidate(ordersStreamProvider),
        ),
      ),
    );
  }

  Widget _buildCompletionImages(BuildContext context, List<String> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('صور إثبات العمل', style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _showFullScreenImage(context, images[index]),
              child: Container(
                width: 120,
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(image: NetworkImage(images[index]), fit: BoxFit.cover),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context, 
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent, 
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  Widget _buildClientInfo(Order order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('بيانات العميل', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
          const SizedBox(height: AppSpacing.md),
          Text(order.clientName, style: AppTextStyles.displayMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(order.area ?? 'كفر الزيات', style: AppTextStyles.bodyLarge),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'اتصال',
                  icon: Icons.phone,
                  variant: ButtonVariant.ghost,
                  onTap: () => launchUrl(Uri.parse('tel:${order.clientPhone}')),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'واتساب',
                  icon: Icons.chat,
                  variant: ButtonVariant.whatsapp,
                  onTap: () {
                    final uri = WhatsAppUtils.buildUri(order.clientPhone, 'السلام عليكم يا ${order.clientName}');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDescription(Order order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تفاصيل المشكلة', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
          const SizedBox(height: AppSpacing.md),
          Text(
            order.description ?? 'لا يوجد وصف مضاف',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: AppColors.gold),
                const SizedBox(width: 12),
                Text(order.service.label, style: AppTextStyles.titleMed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechReport(Order order) {
    return AppCard(
      color: AppColors.success.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تقرير الإنجاز الخاص بك', style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
          const SizedBox(height: 8),
          Text(order.techNotes!, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 12),
          Text('المبلغ الإجمالي: ${order.finalPrice} ج.م', style: AppTextStyles.titleMed),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Order order) {
    if (order.status == OrderStatus.completed) {
      return const AppCard(
        color: AppColors.success,
        child: Center(child: Text('تم إنجاز هذا الطلب بنجاح', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
      );
    }

    if (order.status == OrderStatus.cancelled) {
      return const AppCard(
        color: AppColors.error,
        child: Center(child: Text('هذا الطلب ملغي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
      );
    }

    return Column(
      children: [
        if (order.status == OrderStatus.assigned)
          AppButton(
            label: 'أنا في الطريق للعميل',
            icon: Icons.directions_bike,
            onTap: () => ref.read(adminActionsProvider).updateOrderStatus(
              order, 
              OrderStatus.onTheWay,
              logMessage: 'الفني تحرك الآن وفي طريقه إليك',
            ),
          ),

        if (order.status == OrderStatus.onTheWay)
          AppButton(
            label: 'وصلت للعميل (بدء العمل)',
            icon: Icons.play_arrow,
            onTap: () => ref.read(adminActionsProvider).updateOrderStatus(
              order, 
              OrderStatus.started,
              logMessage: 'وصل الفني لموقع العميل وبدأ في تنفيذ المهمة',
            ),
          ),

        if (order.status == OrderStatus.started)
          AppButton(
            label: 'تم الإنجاز (إغلاق الطلب)',
            icon: Icons.check_circle,
            variant: ButtonVariant.success,
            onTap: () => _showCompletionSheet(context, ref, order),
          ),
      ],
    );
  }

  void _showCompletionSheet(BuildContext context, WidgetRef ref, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (context) => _CompletionSheet(order: order),
    );
  }
}

class _CompletionSheet extends ConsumerStatefulWidget {
  final Order order;
  const _CompletionSheet({required this.order});

  @override
  ConsumerState<_CompletionSheet> createState() => _CompletionSheetState();
}

class _CompletionSheetState extends ConsumerState<_CompletionSheet> {
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 70, maxWidth: 1000);
    if (images.isNotEmpty) {
      setState(() => _selectedImages.addAll(images));
    }
  }

  Future<void> _submit() async {
    final price = int.tryParse(_priceController.text);
    if (price == null || _notesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى ملء السعر ووصف العمل')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = StorageService();
      final List<String> imageUrls = [];

      // رفع الصور باستخدام الميثود المحدثة uploadImage
      for (var image in _selectedImages) {
        final url = await storage.uploadImage(
          image: image, 
          path: 'order_completions', 
          fileName: '${widget.order.id}_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (url != null) imageUrls.add(url);
      }

      await ref.read(adminActionsProvider).completeOrder(
        widget.order,
        finalPrice: price,
        techNotes: _notesController.text.trim(),
        logMessage: 'تم إنجاز المهمة بنجاح، شكراً لتعاملكم مع حرافي',
      );

      // تحديث إضافي للصور في جدول الطلبات
      await ref.read(ordersRepositoryProvider).update(widget.order.id, {
        'completion_images': imageUrls,
      });

      if (mounted) {
        Navigator.pop(context); 
        context.pop(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('إغلاق الطلب وإثبات العمل', style: AppTextStyles.headlineMed),
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ماذا تم في هذه المهمة؟', hintText: 'تم إصلاح العطل وتغيير قطع الغيار...'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر النهائي المحصل (ج.م)'),
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('صور إثبات العمل (اختياري)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo), label: const Text('إضافة صور')),
              ],
            ),
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length, // تم التعديل هنا من .size إلى .length
                  itemBuilder: (context, index) => Container(
                    width: 80,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: FileImage(File(_selectedImages[index].path)), fit: BoxFit.cover)),
                  ),
                ),
              ),
              
            const SizedBox(height: 32),
            AppButton(
              label: 'تأكيد الإنجاز النهائي',
              onTap: _submit,
              isLoading: _isLoading,
              icon: Icons.done_all,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final OrderStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.gold;
    if (status == OrderStatus.completed) color = AppColors.success;
    if (status == OrderStatus.cancelled) color = AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            'الحالة الحالية: ${status.label}',
            style: AppTextStyles.titleMed.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
