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
  ConsumerState<SmartAssistantScreen> createState() =>
      _SmartAssistantScreenState();
}

class _SmartAssistantScreenState extends ConsumerState<SmartAssistantScreen>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  File? _selectedImage;
  Timer? _recordingTimer;
  late AnimationController _typingAnimController;

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _typingAnimController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked =
        await _imagePicker.pickImage(source: source, imageQuality: 75);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              _bottomSheetTile(
                icon: Icons.camera_alt_rounded,
                label: 'التقاط صورة بالكاميرا',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              _bottomSheetTile(
                icon: Icons.photo_library_rounded,
                label: 'اختيار من معرض الصور',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomSheetTile(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.gold, size: 20),
      ),
      title: Text(label,
          style: AppTextStyles.bodyLarge
              .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      onTap: onTap,
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

  void _startVoiceRecording() {
    final notifier = ref.read(smartAssistantProvider.notifier);
    notifier.startVoiceRecording();
    _recordingTimer?.cancel();
    int seconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds++;
      notifier.updateRecordingDuration(seconds);
      if (seconds >= 10) timer.cancel();
    });
  }

  void _stopAndSendVoiceRecording() {
    _recordingTimer?.cancel();
    final sampleQueries = [
      'التكييف بتاعي بيطلع صوت تكتكة ومش بيسقع الغرفة',
      'عندي تسريب مية في خلاط الحمام',
      'الغسالة بتعمل صوت عالي جداً في العصر',
      'فيه ريحة غاز خفيفة قريبة من البوتاجاز',
      'النور قاطع في شقتي بس',
    ];
    final randomQuery =
        sampleQueries[DateTime.now().second % sampleQueries.length];
    ref.read(smartAssistantProvider.notifier).stopVoiceRecordingAndSend(randomQuery);
    _scrollToBottom();
  }

  void _navigateToRequest(ServiceType? service, String description) {
    context.push('/request', extra: {
      'service': service ?? ServiceType.plumbing,
      'description': description,
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final state = ref.watch(smartAssistantProvider);
    final notifier = ref.read(smartAssistantProvider.notifier);

    if (state.messages.length > 1) {
      _scrollToBottom();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(notifier),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              children: [
                // ─── Messages List ──────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount:
                        state.messages.length + (state.isTyping ? 1 : 0),
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

                // ─── Image Preview ──────────────────────────────────────────
                if (_selectedImage != null) _buildImagePreview(),

                // ─── Input Area ─────────────────────────────────────────────
                if (state.isRecordingVoice)
                  _buildVoiceRecordingBar(state, notifier)
                else
                  _buildInputBar(isDesktop),

                if (isDesktop) const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(SmartAssistantNotifier notifier) {
    return AppBar(
      backgroundColor: AppColors.surface1,
      elevation: 0,
      titleSpacing: 0,
      title: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.gold, Color(0xFFB8860B)]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 10)
                        ],
                      ),
                      child: const Center(
                          child: Text('🤖', style: TextStyle(fontSize: 22))),
                    ),
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.surface1, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('مساعد حرفي الذكي',
                          style: AppTextStyles.titleLarge
                              .copyWith(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('متصل • يرد فوراً',
                              style: AppTextStyles.labelMed
                                  .copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
                  tooltip: 'محادثة جديدة',
                  onPressed: () => notifier.reset(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Typing Indicator ─────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBotAvatar(size: 32),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _typingAnimController,
                  builder: (_, __) {
                    return Row(
                      children: List.generate(3, (i) {
                        final delay = i * 0.33;
                        final anim = (_typingAnimController.value + delay) % 1.0;
                        final opacity = (anim < 0.5)
                            ? anim * 2
                            : (1 - anim) * 2;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Opacity(
                            opacity: opacity.clamp(0.2, 1.0),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text('يحلل ويفكر...',
                    style: AppTextStyles.labelMed
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar({double size = 36}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.gold, Color(0xFFB8860B)]),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25), blurRadius: 6)
        ],
      ),
      child: Center(
          child: Text('🤖',
              style: TextStyle(fontSize: size * 0.5))),
    );
  }

  // ─── Message Bubble ───────────────────────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage msg, bool isLast) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!msg.isUser) ...[
                _buildBotAvatar(),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76),
                  decoration: BoxDecoration(
                    gradient: msg.isUser
                        ? const LinearGradient(
                            colors: [AppColors.gold, Color(0xFFB8860B)])
                        : null,
                    color: msg.isUser ? null : AppColors.surface2,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: msg.isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: msg.isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: msg.isUser
                            ? AppColors.gold.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // صورة مرفقة
                      if (msg.imageFile != null) ...[
                        _buildAttachedImage(msg.imageFile!),
                        const SizedBox(height: 8),
                      ],
                      // نص المحادثة (Markdown-style)
                      _buildMessageText(msg),
                      const SizedBox(height: 4),
                      // الوقت
                      Text(
                        intl.DateFormat('HH:mm').format(msg.timestamp),
                        style: TextStyle(
                          color: msg.isUser
                              ? Colors.black54
                              : AppColors.textMuted,
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
                  decoration: const BoxDecoration(
                      color: AppColors.surface2, shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded,
                      color: AppColors.gold, size: 20),
                ),
              ],
            ],
          ),

          // 🚨 Emergency Alert
          if (msg.isEmergency && msg.emergencySteps.isNotEmpty)
            _buildEmergencyCard(msg.emergencySteps),

          // 🔬 Diagnosis Rich Card
          if (msg.diagnosis != null)
            _buildDiagnosisCard(msg.diagnosis!),

          // 💬 Quick Replies
          if (!msg.isUser && msg.quickReplies.isNotEmpty && isLast)
            _buildQuickReplies(msg.quickReplies),
        ],
      ),
    );
  }

  Widget _buildAttachedImage(File imageFile) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(imageFile,
              height: 180, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.auto_fix_high_rounded,
                    size: 12, color: AppColors.gold),
                SizedBox(width: 4),
                Text('فحص بالذكاء الاصطناعي',
                    style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageText(ChatMessage msg) {
    final text = msg.text;
    final spans = <TextSpan>[];
    final lines = text.split('\n');
    final userColor = Colors.black87;
    final botColor = AppColors.textPrimary;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final children = _parseInlineFormatting(line, msg.isUser, userColor, botColor);
      spans.add(TextSpan(children: children));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return RichText(
      textDirection: TextDirection.rtl,
      text: TextSpan(
        style: TextStyle(
          color: msg.isUser ? userColor : botColor,
          fontSize: 14.5,
          height: 1.55,
          fontFamily: 'Cairo',
        ),
        children: spans,
      ),
    );
  }

  List<TextSpan> _parseInlineFormatting(
      String line, bool isUser, Color userColor, Color botColor) {
    final spans = <TextSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    final codePattern = RegExp(r'`(.+?)`');
    int lastEnd = 0;

    final allMatches = [
      ...boldPattern.allMatches(line),
      ...codePattern.allMatches(line),
    ]..sort((a, b) => a.start.compareTo(b.start));

    for (final match in allMatches) {
      if (match.start < lastEnd) continue;

      if (match.start > lastEnd) {
        spans.add(TextSpan(text: line.substring(lastEnd, match.start)));
      }

      final isBold = match.pattern == boldPattern;
      if (isBold) {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isUser ? Colors.black : AppColors.textPrimary,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: isUser
                ? Colors.black.withValues(alpha: 0.12)
                : AppColors.gold.withValues(alpha: 0.15),
            color: isUser ? Colors.black87 : AppColors.gold,
            fontSize: 13,
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd)));
    }

    return spans.isEmpty ? [TextSpan(text: line)] : spans;
  }

  // ─── Emergency Card ───────────────────────────────────────────────────────
  Widget _buildEmergencyCard(List<String> steps) {
    return Container(
      margin: const EdgeInsets.only(top: 10, right: 44, left: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 22),
              SizedBox(width: 8),
              Text('خطوات السلامة الفورية',
                  style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1, left: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value.replaceAll('**', ''),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── Diagnosis Rich Card ──────────────────────────────────────────────────
  Widget _buildDiagnosisCard(SmartDiagnosis diagnosis) {
    final service = diagnosis.serviceType;
    return Container(
      margin: const EdgeInsets.only(top: 12, right: 44, left: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1),
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.08), blurRadius: 12)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(service?.icon ?? '🛠️',
                          style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service?.label ?? 'خدمة صيانة متخصصة',
                          style: AppTextStyles.titleLarge
                              .copyWith(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          _urgencyBadge(diagnosis.urgency),
                          const SizedBox(width: 8),
                          Text(
                            '${(diagnosis.confidence * 100).toStringAsFixed(0)}% دقة',
                            style: AppTextStyles.labelMed
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // DIY Steps (if any)
          if (diagnosis.diySteps.isNotEmpty) ...[
            _sectionDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: const [
                  Icon(Icons.build_circle_outlined,
                      color: AppColors.gold, size: 18),
                  SizedBox(width: 8),
                  Text('جرّب بنفسك أولاً (مجاناً) 🛠️',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Column(
                children: diagnosis.diySteps.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 1, left: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.gold, Color(0xFFB8860B)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('${e.key + 1}',
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Parts Breakdown Table (if any)
          if (diagnosis.partsBreakdown.isNotEmpty) ...[
            _sectionDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: const [
                  Icon(Icons.price_check_rounded,
                      color: AppColors.gold, size: 18),
                  SizedBox(width: 8),
                  Text('أسعار قطع الغيار المعتمدة',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: diagnosis.partsBreakdown.map((part) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(part['اسم القطعة'] ?? '',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600)),
                              if (part['المصدر'] != null)
                                Text(part['المصدر']!,
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                            ],
                          ),
                        ),
                        Text(
                          part['السعر'] ?? '',
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Repair vs Replace
          if (diagnosis.repairVsReplace != null &&
              diagnosis.repairVsReplace!.isNotEmpty) ...[
            _sectionDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.balance_rounded,
                      color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إصلاح أم استبدال؟',
                            style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(diagnosis.repairVsReplace!,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // CTA Button
          _sectionDivider(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: AppButton(
              label: '🚀 اطلب فني ${service?.label ?? "الصيانة"} الآن',
              onTap: () => _navigateToRequest(service, diagnosis.problemSummary),
              icon: Icons.flash_on_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _urgencyBadge(String urgency) {
    Color color;
    String label;
    switch (urgency) {
      case 'high':
        color = AppColors.error;
        label = 'عاجل 🔴';
        break;
      case 'medium':
        color = AppColors.warning;
        label = 'متوسط 🟡';
        break;
      default:
        color = AppColors.success;
        label = 'عادي 🟢';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _sectionDivider() {
    return Divider(
        height: 1,
        thickness: 1,
        color: AppColors.borderSubtle.withValues(alpha: 0.5));
  }

  // ─── Quick Replies ────────────────────────────────────────────────────────
  Widget _buildQuickReplies(List<String> replies) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 44),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: replies.map((reply) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _sendQuickReply(reply),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Text(reply,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Image Preview ────────────────────────────────────────────────────────
  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_selectedImage!,
                width: 54, height: 54, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          const Expanded(
              child: Text('صورة مرفقة للتحليل الذكي 📷',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          IconButton(
            icon:
                const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
            onPressed: () => setState(() => _selectedImage = null),
          ),
        ],
      ),
    );
  }

  // ─── Voice Recording Bar ──────────────────────────────────────────────────
  Widget _buildVoiceRecordingBar(
      SmartAssistantState state, SmartAssistantNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            onPressed: () => notifier.cancelVoiceRecording(),
          ),
          Expanded(
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  builder: (_, val, child) => Opacity(opacity: val, child: child),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: AppColors.error, shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'جاري التسجيل... 00:${state.recordingDurationSeconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('إرسال'),
            onPressed: _stopAndSendVoiceRecording,
          ),
        ],
      ),
    );
  }

  // ─── Input Bar ────────────────────────────────────────────────────────────
  Widget _buildInputBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 12, vertical: isDesktop ? 10 : 8),
      margin:
          isDesktop ? const EdgeInsets.fromLTRB(16, 0, 16, 0) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: isDesktop ? BorderRadius.circular(28) : null,
        border: isDesktop
            ? Border.all(color: AppColors.borderSubtle, width: 1.5)
            : const Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 0.8)),
        boxShadow: isDesktop
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, -2))
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Image Attach Button
          _inputIconButton(
              icon: Icons.add_a_photo_outlined, onTap: _showImageOptions),
          const SizedBox(width: 6),

          // Text Field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: TextField(
                controller: _textController,
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textPrimary),
                maxLines: 4,
                minLines: 1,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'اكتب مشكلتك أو استفسارك...',
                  hintStyle: AppTextStyles.bodyMed
                      .copyWith(color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Voice Button
          _inputIconButton(
            icon: Icons.mic_rounded,
            onTap: _startVoiceRecording,
            color: AppColors.surface2,
          ),
          const SizedBox(width: 6),

          // Send Button
          GestureDetector(
            onTap: _sendTextMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.gold, Color(0xFFB8860B)]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 10)
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputIconButton(
      {required IconData icon, required VoidCallback onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color ?? Colors.transparent,
          shape: BoxShape.circle,
          border: color != null
              ? Border.all(color: AppColors.borderSubtle)
              : null,
        ),
        child: Icon(icon, color: AppColors.gold, size: 22),
      ),
    );
  }
}
