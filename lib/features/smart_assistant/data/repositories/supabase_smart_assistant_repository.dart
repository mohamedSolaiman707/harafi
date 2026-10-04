import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/smart_diagnosis.dart';
import '../../domain/repositories/smart_assistant_repository.dart';
import '../models/smart_diagnosis_model.dart';

class SupabaseSmartAssistantRepository implements SmartAssistantRepository {
  final SupabaseClient _client;

  SupabaseSmartAssistantRepository(this._client);

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

    // Dynamic fallback when AI Agent call fails, inviting clearer user input
    return SmartDiagnosis(
      confidence: 0.0,
      problemSummary: 'تعذر الاتصال بـ Agent التشخيص الذكي حالياً',
      possibleIssue:
          'يرجى التأكد من الاتصال بالشبكة أو كتابة تفاصيل دقيقة حول العطل الملاحظ لإجراء تحليل دقيق عبر الـ Agent.',
      diyTip: 'أعد المحاولة مع كتابة نوع الجهاز وإعادة الوصف بتفاصيل أكثر.',
      diySteps: [
        'اكتب نوع الجهاز وموديله (مثل: غسالة توشيبا فوق أوتوماتيك)',
        'صف الأعراض بدقة (صوت، تسريب، عدم دوران)',
        'يمكنك إرفاق صورة لوحة التحكم أو مكان العطل',
      ],
      estimatedPartsCost: 'سيتم الحساب ديناميكياً عند وصول استجابة الـ Agent',
      partsBreakdown: [],
      repairVsReplace: 'تحليل الجدوى الاقتصادية يعتمد على تقرير الـ Agent الفوري',
      recommendedAction: 'إعادة إرسال الاستفسار لتنشيط استجابة الـ Agent',
      needsTechnician: true,
      urgency: 'normal',
      safetyNotes: [
        'في حالة الطوارئ (كهرباء / غاز) قم بفصل القاطع أو المحبس فوراً'
      ],
      followUpQuestions: [
        'ما هي ماركة وموديل الجهاز؟',
        'هل يوجد رمز خطأ يظهر على الشاشة؟',
      ],
    );
  }
}
