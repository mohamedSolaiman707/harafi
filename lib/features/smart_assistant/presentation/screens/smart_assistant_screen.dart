import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/smart_assistant_providers.dart';
import '../../domain/entities/smart_diagnosis.dart';

class SmartAssistantScreen extends ConsumerStatefulWidget {
  const SmartAssistantScreen({super.key});

  @override
  ConsumerState<SmartAssistantScreen> createState() =>
      _SmartAssistantScreenState();
}

class _SmartAssistantScreenState extends ConsumerState<SmartAssistantScreen> {
  final _textController = TextEditingController();
  final _followUpController = TextEditingController();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _textController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(source: source);
    if (pickedFile != null) {
      ref.read(smartAssistantProvider.notifier).setImage(File(pickedFile.path));
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('الكاميرا'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartAssistantProvider);
    final notifier = ref.read(smartAssistantProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مساعد حرفي الذكي'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: AppSpacing.xxl),
            if (state.diagnosis == null) ...[
              _buildInputSection(state, notifier),
            ] else ...[
              _buildResultSection(state.diagnosis!, state),
            ],
            if (state.isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مش لازم تعرف العطل تبع أنهي تخصص.',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'احكي اللي حصل، اكتب المشكلة أو ابعت صورة، وحرفي هيساعدك تحدد الفني المناسب.',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection(
    SmartAssistantState state,
    SmartAssistantNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'اكتب اللي حصل أو وصف المشكلة',
          controller: _textController,
          hint: 'مثال: الغسالة بتعمل صوت عالي ومش بتعصر',
          maxLines: 4,
          onChanged: notifier.setDescription,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_a_photo_rounded,
                label: 'صوّر أو ارفع صورة',
                onTap: _showImagePickerOptions,
                isSelected: state.selectedImage != null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildActionCard(
                icon: Icons.mic_none_rounded,
                label: 'احكي المشكلة بصوتك',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ميزة التسجيل الصوتي ستتوفر قريباً'),
                    ),
                  );
                },
                isSelected: false,
              ),
            ),
          ],
        ),
        if (state.selectedImage != null) ...[
          const SizedBox(height: AppSpacing.md),
          _buildSelectedImagePreview(state.selectedImage!, notifier),
        ],
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'حلّل المشكلة',
          onTap: notifier.analyze,
          isLoading: state.isLoading,
          icon: Icons.auto_awesome,
        ),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(state.error!, style: const TextStyle(color: AppColors.error)),
        ],
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: isSelected ? AppColors.gold.withOpacity(0.1) : AppColors.surface1,
      child: Column(
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.gold : AppColors.textSecondary,
            size: 32,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: AppTextStyles.labelLarge.copyWith(
              color: isSelected ? AppColors.gold : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImagePreview(
    File image,
    SmartAssistantNotifier notifier,
  ) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Image.file(image, height: 100, width: 100, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => notifier.setImage(null),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(
    SmartDiagnosis diagnosis,
    SmartAssistantState state,
  ) {
    if (diagnosis.followUpQuestions.isNotEmpty &&
        state.answers.length < 3 &&
        diagnosis.confidence < 0.75) {
      return _buildFollowUpSection(diagnosis.followUpQuestions.first, state);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDiagnosisResultCard(diagnosis),
        const SizedBox(height: AppSpacing.xl),
        if (diagnosis.safetyNotes.isNotEmpty) ...[
          _buildSafetyNotes(diagnosis.safetyNotes),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (diagnosis.urgency == 'high' ||
            diagnosis.detectedCategory == 'electricity' ||
            diagnosis.detectedCategory == 'stove')
          _buildSafetyWarning(),
        const SizedBox(height: AppSpacing.xxl),
        if (diagnosis.needsTechnician && diagnosis.serviceType != null)
          AppButton(
            label:
                'اطلب فني ${diagnosis.categoryNameAr ?? diagnosis.serviceType!.label}',
            onTap: () => _navigateToRequest(diagnosis, state),
            icon: Icons.check_circle_outline,
          )
        else
          AppButton(
            label: 'اختيار الخدمة بنفسي',
            onTap: () => context.push('/request'),
          ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => ref.read(smartAssistantProvider.notifier).reset(),
          child: const Center(
            child: Text(
              'إعادة التحليل',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosisResultCard(SmartDiagnosis diagnosis) {
    final confidenceText = diagnosis.confidence > 0.85
        ? 'واثق جداً'
        : 'يبدو مناسباً';

    return AppCard(
      color: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'نتيجة التحليل الذكي',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  confidenceText,
                  style: AppTextStyles.labelMed.copyWith(color: AppColors.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: diagnosis.analysisSource == 'openai'
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.textMuted.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diagnosis.analysisSource == 'openai'
                  ? 'التحليل تم بواسطة OpenAI'
                  : 'التحليل تم بواسطة fallback محلي',
              style: AppTextStyles.labelMed.copyWith(
                color: diagnosis.analysisSource == 'openai'
                    ? AppColors.success
                    : AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('من وصفك، يبدو أنك تحتاج إلى:', style: AppTextStyles.bodyLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '🔧 ${diagnosis.categoryNameAr ?? diagnosis.serviceType?.label ?? 'فني مختص'}',
            style: AppTextStyles.headlineMed.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 32, color: AppColors.borderSubtle),
          Text('المشكلة المحتملة:', style: AppTextStyles.titleMed),
          const SizedBox(height: 4),
          Text(diagnosis.possibleIssue, style: AppTextStyles.bodyLarge),
          if (diagnosis.recommendedAction.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('الإجراء المقترح:', style: AppTextStyles.titleMed),
            const SizedBox(height: 4),
            Text(diagnosis.recommendedAction, style: AppTextStyles.bodyLarge),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetyNotes(List<String> notes) {
    return AppCard(
      color: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تنبيهات الأمان',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note, style: AppTextStyles.bodyMed)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyWarning() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '⚠️ لأمانك، لا تحاول إصلاح العطل بنفسك. افصل مصدر الكهرباء أو الغاز إذا كان ذلك آمنًا، واطلب فنيًا مختصًا.',
              style: AppTextStyles.bodyMed.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowUpSection(String question, SmartAssistantState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سؤال متابعة لمساعدتنا:',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          color: AppColors.surface1,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question, style: AppTextStyles.headlineMed),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'إجابتك',
                controller: _followUpController,
                hint: 'أجب هنا...',
                onSubmitted: (val) {
                  if (val.isNotEmpty) {
                    ref.read(smartAssistantProvider.notifier).addAnswer(question, val);
                    _followUpController.clear();
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'إرسال الإجابة',
                onTap: () {
                  if (_followUpController.text.isNotEmpty) {
                    ref.read(smartAssistantProvider.notifier).addAnswer(question, _followUpController.text);
                    _followUpController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.gold),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'جاري فهم المشكلة وتحديد التخصص المناسب...',
              style: AppTextStyles.bodyMed,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRequest(SmartDiagnosis diagnosis, SmartAssistantState state) {
    final service = diagnosis.serviceType;
    if (service == null) {
      context.push('/request');
      return;
    }

    String fullDescription = state.description;
    if (state.answers.isNotEmpty) {
      fullDescription += '\n\nأسئلة إضافية:';
      for (var a in state.answers) {
        fullDescription += '\n- ${a.question}: ${a.answer}';
      }
    }
    fullDescription += '\n\nتحليل المساعد: ${diagnosis.problemSummary}';

    context.push(
      '/request',
      extra: {
        'service': service,
        'description': fullDescription,
        'aiDiagnosis': diagnosis,
      },
    );
  }
}
