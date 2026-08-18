import 'dart:convert';
import 'dart:io';
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
      };

      if (image != null) {
        payload['image_base64'] = base64Encode(await image.readAsBytes());
        payload['image_name'] = image.path.split(Platform.pathSeparator).last;
      }

      final response = await _client.functions.invoke(
        'analyze-problem',
        body: payload,
      );

      if (response.status == 200) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
        return SmartDiagnosisModel.fromJson(data);
      } else {
        throw Exception('Failed to analyze problem: ${response.status}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
