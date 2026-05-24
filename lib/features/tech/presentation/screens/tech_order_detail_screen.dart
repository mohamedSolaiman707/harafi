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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
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
                      const SizedBox(height: AppSpacing.xxxl),
                      _buildActionButtons(context, ref, order),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
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
        Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text('صور إثبات العمل', style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => _showFullScreenImage(context, images[index]),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(image: NetworkImage(images[index]), fit: BoxFit.cover),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                ],
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
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(url)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfo(Order order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('بيانات العميل', style: AppTextStyles.labelLarge.copyWith(color: AppColors.gold)),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: AppColors.textMuted),
                onPressed: () {
                  // Clipboard logic here if needed
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(order.clientName, style: AppTextStyles.displayMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(order.area ?? 'كفر الزيات', style: AppTextStyles.bodyLarge)),
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
                    final uri = WhatsAppUtils.buildUri(order.clientPhone, 'السلام عليكم يا ${order.clientName}، أنا الفني من حرفي وبخصوص طلبك...');
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Text(
              order.description ?? 'لا يوجد وصف مضاف',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary, height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.build_circle_outlined, color: AppColors.gold, size: 20),
              const SizedBox(width: 12),
              Text('نوع الخدمة: ', style: AppTextStyles.labelLarge),
              Text(order.service.label, style: AppTextStyles.titleMed.copyWith(color: AppColors.gold)),
            ],
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
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined, color: AppColors.success, size: 20),
              const SizedBox(width: 12),
              Text('تقرير الإنجاز المالي', style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          Text(order.techNotes!, style: AppTextStyles.bodyLarge.copyWith(height: 1.5)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المبلغ الإجمالي المحصل:', style: AppTextStyles.bodyLarge),
              Text('${order.finalPrice} ج.م', style: AppTextStyles.headlineLarge.copyWith(color: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Order order) {
    if (order.status == OrderStatus.completed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 12),
              Text('تم إنجاز هذا الطلب وإغلاقه بنجاح', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
            ],
          ),
        ),
      );
    }

    if (order.status == OrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('هذا الطلب ملغي من قبل الإدارة أو العميل', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error))),
      );
    }

    return Column(
      children: [
        if (order.status == OrderStatus.assigned)
          AppButton(
            label: 'أنا في الطريق للعميل الآن',
            icon: Icons.directions_bike,
            onTap: () => ref.read(adminActionsProvider).updateOrderStatus(
              order, 
              OrderStatus.onTheWay,
              logMessage: 'الفني تحرك الآن وهو في طريقه إليك',
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
            label: 'تم الإنجاز (إغلاق المهمة)',
            icon: Icons.check_circle,
            variant: ButtonVariant.success,
            onTap: () => _showCompletionSheet(context, ref, order),
          ),
      ],
    );
  }

  void _showCompletionSheet(BuildContext context, WidgetRef ref, Order order) {
    final width = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      constraints: BoxConstraints(maxWidth: width > 900 ? 600 : width),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد السعر ووصف العمل المنجز')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = StorageService();
      final List<String> imageUrls = [];

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
        logMessage: 'تم إنجاز المهمة بنجاح، نتمنى أن نكون عند حسن ظنكم',
      );

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إغلاق الطلب وإثبات العمل', style: AppTextStyles.headlineMed),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'تقرير العمل المنجز', 
                hintText: 'اشرح للعميل ما قمت به (مثلاً: تم تغيير صنبور الحمام بقطعة غيار أصلية)...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'إجمالي المبلغ المحصل (ج.م)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إرفاق صور العمل (اختياري)', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('إضافة صور')),
              ],
            ),
            if (_selectedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) => Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        width: 100,
                        margin: const EdgeInsets.only(left: 8, top: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12), 
                          image: DecorationImage(image: FileImage(File(_selectedImages[index].path)), fit: BoxFit.cover),
                          border: Border.all(color: AppColors.borderDefault),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _selectedImages.removeAt(index)),
                        icon: const CircleAvatar(radius: 10, backgroundColor: AppColors.error, child: Icon(Icons.close, size: 12, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
              
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: AppButton(
                label: 'تأكيد إنجاز المهمة نهائياً',
                onTap: _submit,
                isLoading: _isLoading,
                icon: Icons.done_all_rounded,
              ),
            ),
            const SizedBox(height: 32),
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة الطلب: ${status.label}',
                  style: AppTextStyles.titleLarge.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
                if (status == OrderStatus.assigned)
                  Text('العميل بانتظار تحركك الآن', style: AppTextStyles.labelMed.copyWith(color: color.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
