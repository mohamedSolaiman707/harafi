import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../admin/domain/enums/service_type.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/smart_diagnosis.dart';
import '../providers/smart_assistant_providers.dart';

class SmartAssistantScreen extends ConsumerStatefulWidget {
  const SmartAssistantScreen({super.key});

  @override
  ConsumerState<SmartAssistantScreen> createState() => _SmartAssistantScreenState();
}

class _SmartAssistantScreenState extends ConsumerState<SmartAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  Timer? _recordingTimer;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source, imageQuality: 75);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.gold),
              title: const Text('التقاط صورة بالمواجهة'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.gold),
              title: const Text('اختيار من معرض الصور'),
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

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    ref.read(smartAssistantProvider.notifier).sendMessage(
          text: text,
          imageFile: _selectedImage,
        );

    _textController.clear();
    setState(() => _selectedImage = null);
    _scrollToBottom();
  }

  void _sendQuickReply(String text) {
    ref.read(smartAssistantProvider.notifier).sendMessage(text: text);
    _scrollToBottom();
  }

  void _startVoiceRecordingSimulated() {
    final notifier = ref.read(smartAssistantProvider.notifier);
    notifier.startVoiceRecording();

    _recordingTimer?.cancel();
    int seconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds++;
      notifier.updateRecordingDuration(seconds);
      if (seconds >= 10) {
        timer.cancel();
      }
    });
  }

  void _stopAndSendVoiceRecordingSimulated() {
    _recordingTimer?.cancel();
    final notifier = ref.read(smartAssistantProvider.notifier);

    // محاكاة تحويل الصوت المحكي إلى نص عربي مصري حقيقي متصل بالـ AI
    final sampleVoiceQueries = [
      'التكييف بتاعي بيطلع صوت تكتكة ومش بيسقع الغرفة خالص',
      'عندي تسريب مية في خلاط الحمام وبينزل مية كتير',
      'الغسالة بتعمل صوت عالي جداً في العصر ومطبقة الهدوم',
      'فيه ريحة غاز خفيفة قريبة من البوتجاز',
      'النور قاطع في شقتي بس ومفاتيح العداد نازلة',
    ];
    final randomQuery = sampleVoiceQueries[DateTime.now().second % sampleVoiceQueries.length];

    notifier.stopVoiceRecordingAndSend(randomQuery);
    _scrollToBottom();
  }

  void _navigateToRequestScreen(ServiceType? service, String description) {
    context.push('/request', extra: {
      'service': service ?? ServiceType.plumbing,
      'description': description,
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartAssistantProvider);
    final notifier = ref.read(smartAssistantProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface1,
          elevation: 0,
          title: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFB8860B)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 8)],
                    ),
                    child: const Center(child: Text('🤖', style: TextStyle(fontSize: 20))),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface1, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مساعد حرفي الذكي 2.0', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                  Text('متصل • مهندس الصيانة التفاعلي ⚡', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
              tooltip: 'بدء محادثة جديدة',
              onPressed: () => notifier.reset(),
            ),
          ],
        ),
        body: Column(
          children: [
            // ─── Chat Messages List ───────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.messages.length && state.isTyping) {
                    return _buildTypingIndicator();
                  }
                  final msg = state.messages[index];
                  final isLast = index == state.messages.length - 1;
                  return _buildMessageBubble(msg, isLast);
                },
              ),
            ),

            // ─── Selected Image Preview ────────────────────────────────
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_selectedImage!, width: 50, height: 50, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('صورة مرفقة للتحليل 📷', style: TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ],
                ),
              ),

            // ─── Voice Recording Overlay OR Input Bar ─────────────────
            if (state.isRecordingVoice)
              _buildVoiceRecordingBar(state, notifier)
            else
              _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ─── Typing Indicator ──────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                ),
                SizedBox(width: 10),
                Text('جاري تحليل المشكلة بالذكاء الاصطناعي...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message Bubble ────────────────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage msg, bool isLast) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!msg.isUser) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFB8860B)]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.25), blurRadius: 6)],
                  ),
                  child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(
                    gradient: msg.isUser
                        ? const LinearGradient(colors: [AppColors.gold, Color(0xFFB8860B)])
                        : null,
                    color: msg.isUser ? null : AppColors.surface2,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: msg.isUser ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: msg.isUser ? AppColors.gold.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.imageFile != null) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(msg.imageFile!, height: 170, width: double.infinity, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.remove_red_eye_rounded, size: 12, color: AppColors.gold),
                                    SizedBox(width: 4),
                                    Text(
                                      'تم الفحص بالعدسة الذكية 🔍',
                                      style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: msg.isUser ? Colors.black : AppColors.textPrimary,
                          fontSize: 14.5,
                          height: 1.5,
                          fontWeight: msg.isUser ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        intl.DateFormat('HH:mm').format(msg.timestamp),
                        style: TextStyle(
                          color: msg.isUser ? Colors.black54 : AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (msg.isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, color: AppColors.gold, size: 20),
                ),
              ],
            ],
          ),

          // 🚨 Emergency Alert Banner
          if (msg.isEmergency && msg.emergencySteps.isNotEmpty)
            _buildEmergencyCard(msg.emergencySteps),

          // 🚀 Diagnosis Action Box
          if (msg.diagnosis != null)
            _buildDiagnosisActionCard(msg.diagnosis!),

          // 💬 Quick Reply Chips
          if (!msg.isUser && msg.quickReplies.isNotEmpty && isLast)
            _buildQuickReplies(msg.quickReplies),
        ],
      ),
    );
  }

  // ─── Emergency Card Widget ─────────────────────────────────────────
  Widget _buildEmergencyCard(List<String> steps) {
    return Container(
      margin: const EdgeInsets.only(top: 10, right: 44, left: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Text('🚨 إرشادات السلامة الفورية للطوارئ', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
              )),
        ],
      ),
    );
  }

  // ─── Diagnosis Action Card Widget ──────────────────────────────────
  Widget _buildDiagnosisActionCard(SmartDiagnosis diagnosis) {
    final service = diagnosis.serviceType;
    return Container(
      margin: const EdgeInsets.only(top: 10, right: 44, left: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(service?.icon ?? '🛠️', style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service?.label ?? 'خدمة صيانة متخصصة', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                    Text('مستوى الأولوية: ${diagnosis.urgency == "high" ? "عاجل 🔴" : "عادي 🟡"}', style: AppTextStyles.labelMed.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppButton(
            label: '🚀 اطلب فني ${service?.label ?? "الصيانة"} إلى كفر الزيات الآن',
            onTap: () => _navigateToRequestScreen(service, diagnosis.problemSummary),
            icon: Icons.flash_on_rounded,
          ),
        ],
      ),
    );
  }

  // ─── Quick Replies Widget ──────────────────────────────────────────
  Widget _buildQuickReplies(List<String> replies) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 44),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: replies.map((reply) {
          return ActionChip(
            backgroundColor: AppColors.surface2,
            side: const BorderSide(color: AppColors.borderSubtle),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            label: Text(reply, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _sendQuickReply(reply),
          );
        }).toList(),
      ),
    );
  }

  // ─── Voice Recording Bar Widget ────────────────────────────────────
  Widget _buildVoiceRecordingBar(SmartAssistantState state, SmartAssistantNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: const Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            onPressed: () => notifier.cancelVoiceRecording(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  'جاري التسجيل الصوتي... 00:0${state.recordingDurationSeconds}',
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('إرسال الصوت'),
            onPressed: _stopAndSendVoiceRecordingSimulated,
          ),
        ],
      ),
    );
  }

  // ─── Input Bar Widget ──────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: const Border(top: BorderSide(color: AppColors.borderSubtle, width: 0.8)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_outlined, color: AppColors.gold),
            onPressed: _showImageOptions,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: TextField(
                controller: _textController,
                style: AppTextStyles.bodyMed,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'احكي المشكلة أو اكتب استفسارك...',
                  hintStyle: AppTextStyles.bodyMed.copyWith(color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 🎙️ Voice Recording Button
          GestureDetector(
            onLongPressStart: (_) => _startVoiceRecordingSimulated(),
            onTap: _startVoiceRecordingSimulated,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(Icons.mic_rounded, color: AppColors.gold, size: 22),
            ),
          ),
          const SizedBox(width: 6),

          // 🚀 Send Button
          GestureDetector(
            onTap: _sendTextMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFB8860B)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 8)],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
