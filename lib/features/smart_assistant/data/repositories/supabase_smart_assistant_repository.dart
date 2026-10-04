import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/smart_diagnosis.dart';
import '../../domain/repositories/smart_assistant_repository.dart';
import '../models/smart_diagnosis_model.dart';

class SupabaseSmartAssistantRepository implements SmartAssistantRepository {
  final SupabaseClient _client;

  SupabaseSmartAssistantRepository(this._client);

  @override
  Future<String?> getOrCreateActiveSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final existingSessions = await _client
          .from('chat_sessions')
          .select('id')
          .eq('user_id', user.id)
          .order('last_message_at', ascending: false)
          .limit(1);

      if (existingSessions.isNotEmpty) {
        return existingSessions.first['id'] as String;
      }

      final newSession = await _client
          .from('chat_sessions')
          .insert({
            'user_id': user.id,
            'title': 'محادثة صيانة جارية',
          })
          .select('id')
          .single();

      return newSession['id'] as String;
    } catch (e) {
      debugPrint('Error getting or creating chat session: $e');
      return null;
    }
  }

  @override
  Future<List<ChatMessage>> loadSessionMessages(String sessionId) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select('*')
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return (response as List).map((map) {
        final role = map['role'] as String? ?? 'user';
        final isUser = role == 'user';
        final emergencyStepsList = (map['emergency_steps'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final quickRepliesList = (map['quick_replies'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        SmartDiagnosis? diagnosis;
        if (map['diagnosis'] != null && map['diagnosis'] is Map) {
          try {
            diagnosis = SmartDiagnosisModel.fromJson(
              Map<String, dynamic>.from(map['diagnosis'] as Map),
            );
          } catch (_) {}
        }

        return ChatMessage(
          id: map['id'].toString(),
          text: map['content'] as String? ?? '',
          sender: isUser ? ChatSender.user : ChatSender.assistant,
          timestamp: map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
          imageUrl: map['image_url'] as String?,
          isEmergency: (map['intent'] as String?) == 'emergency',
          emergencySteps: emergencyStepsList,
          quickReplies: quickRepliesList,
          contactPhone: map['contact_phone'] as String?,
          diagnosis: diagnosis,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading chat session messages: $e');
      return [];
    }
  }

  @override
  Future<AgentChatResponse> sendAgentMessage({
    String? sessionId,
    required String message,
    File? image,
    Map<String, dynamic>? context,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (sessionId != null) 'session_id': sessionId,
        'message': message,
        if (context != null) 'context': context,
      };

      if (image != null) {
        payload['image_base64'] = base64Encode(await image.readAsBytes());
      }

      final response = await _client.functions.invoke(
        'agent-chat',
        body: payload,
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);

        final returnedSessionId = data['session_id'] as String?;
        final returnedMsgId = data['message_id'] as int?;
        final reply = data['reply'] as String? ?? '';
        final intent = data['intent'] as String? ?? 'general_query';

        final emergencySteps = (data['emergency_steps'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final quickReplies = (data['quick_replies'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final contactPhone = data['contact_phone'] as String?;

        return AgentChatResponse(
          sessionId: returnedSessionId,
          messageId: returnedMsgId,
          reply: reply,
          intent: intent,
          emergencySteps: emergencySteps,
          quickReplies: quickReplies,
          contactPhone: contactPhone,
        );
      }
    } catch (e) {
      debugPrint('agent-chat Edge Function error: $e');
    }

    // Fallback to legacy analyzeProblem if agent-chat function is uninvokable
    final legacyDiagnosis = await analyzeProblem(
      description: message,
      image: image,
    );

    return AgentChatResponse(
      sessionId: sessionId,
      reply: legacyDiagnosis.problemSummary,
      intent: legacyDiagnosis.needsTechnician ? 'diagnosis' : 'general_query',
      quickReplies: legacyDiagnosis.followUpQuestions,
      diagnosis: legacyDiagnosis,
    );
  }

  @override
  Future<void> submitMessageFeedback({
    required int messageId,
    required int rating,
  }) async {
    try {
      await _client
          .from('chat_messages')
          .update({'feedback': rating})
          .eq('id', messageId);
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
    }
  }

  @override
  Future<SmartDiagnosis> analyzeProblem({
    required String description,
    File? image,
    List<FollowUpAnswer> answers = const [],
  }) async {
    try {
      final payload = <String, dynamic>{
        'description': description.trim(),
        'answers': answers
            .map((a) => {'question': a.question, 'answer': a.answer})
            .toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (image != null) {
        payload['image_base64'] = base64Encode(await image.readAsBytes());
        payload['image_name'] = image.path.split(Platform.pathSeparator).last;
      }

      final response = await _client.functions.invoke(
        'analyze-problem',
        body: payload,
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
        final diagnosis = SmartDiagnosisModel.fromJson(data);
        if (diagnosis.possibleIssue.isNotEmpty &&
            !diagnosis.possibleIssue.contains('نحتاج تفاصيل أكثر')) {
          return diagnosis;
        }
      }
    } catch (e) {
      debugPrint('AI Agent Edge Function call error: $e');
    }

    return _buildLocalOfflineDiagnosis(description);
  }

  SmartDiagnosis _buildLocalOfflineDiagnosis(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('غسال')) {
      return SmartDiagnosis(
        detectedCategory: 'washing_machine',
        categoryNameAr: 'غسالات',
        confidence: 0.75,
        confidenceLevel: 'medium',
        problemSummary: 'عطل محتمل في طلمبة الطرد أو سير الموتور والغسيل',
        possibleIssue: 'انسداد مصفاة الفلتر السفلية أو تلف طلمبة طرد المياه أو تآكل سير الغسالة.',
        diyTip: 'قم بفتح غطاء الفلتر الأسفل وتنظيف الرواسب والعملات المعدنية المحشورة ثم أعد تشغيل برنامج العصر.',
        estimatedPartsCost: 'من 180 إلى 320 ج.م (طلمبة طرد أو سير أصلي)',
        recommendedAction: 'طلب فني صيانة غسالات لفحص الطلمبة والكارتة الإلكترونية.',
        needsTechnician: true,
        urgency: 'normal',
        analysisSource: 'fallback',
        safetyNotes: ['افصل القابس الكهربائي قبل تنظيف الفلتر أو فك أي جزء حماية.'],
        followUpQuestions: ['هل الغسالة أوتوماتيك أم فوق أوتوماتيك؟', 'هل تظهر أي رموز خطأ مثل E3 أو E4؟'],
      );
    } else if (lower.contains('تكييف') || lower.contains('مكيف')) {
      return SmartDiagnosis(
        detectedCategory: 'air_conditioning',
        categoryNameAr: 'تكييفات',
        confidence: 0.75,
        confidenceLevel: 'medium',
        problemSummary: 'انخفاض كفاءة التبريد أو تسريب مية من الوحدة الداخلية',
        possibleIssue: 'انسداد فلاتر الهواء الداخلية، أو انسداد خرطوم الصرف، أو نقص شحنة فريون R22/R410a.',
        diyTip: 'قم بفك الفلاتر البلاستيكية واغسلها بالماء المعتدل وافحص خرطوم التكثيف الخارجي.',
        estimatedPartsCost: 'من 350 إلى 750 ج.م (شحن فريون أصلي أو مكثف كباش)',
        recommendedAction: 'طلب فني تكييفات لقياس الضغط وشحن الفريون وتنظيف الحوض.',
        needsTechnician: true,
        urgency: 'normal',
        analysisSource: 'fallback',
        safetyNotes: ['لا تلمس كباش التكييف الخارجي أثناء التشغيل.'],
        followUpQuestions: ['هل التكييف ينقط مية داخل الغرفة؟', 'هل الكباش الخارجي يعمل بصوت طبيعي؟'],
      );
    }

    return SmartDiagnosis(
      confidence: 0.0,
      problemSummary: 'تعذر الاتصال بالخادم، تم تفعيل الوضع المحلي',
      possibleIssue: 'يرجى كتابة نوع الجهاز بدقة (مثل: غسالة، تكييف، ثلاجة، سباكة) أو التأكد من الاتصال بالإنترنت.',
      diyTip: 'حدد اسم الجهاز والعرض الملاحظ في رسالتك للحصول على تشخيص فوري.',
      diySteps: [
        'اكتب نوع الجهاز وموديله (مثل: غسالة توشيبا فوق أوتوماتيك)',
        'صف الأعراض بدقة (صوت، تسريب، عدم دوران)',
      ],
      estimatedPartsCost: 'سيتم تقدير التكلفة فور الاتصال بالسيرفر',
      recommendedAction: 'إعادة محاولة الإرسال أو اختيار أحد الخيارات السريعة',
      needsTechnician: true,
      urgency: 'normal',
      analysisSource: 'fallback',
      safetyNotes: ['في حالة الطوارئ (كهرباء / غاز) قم بفصل القاطع أو المحبس فوراً'],
      followUpQuestions: ['ما هو نوع الجهاز المعطل؟', 'هل تظهر أي علامة طوارئ؟'],
    );
  }
}
