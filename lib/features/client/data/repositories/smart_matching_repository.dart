import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../smart_assistant/domain/entities/smart_diagnosis.dart';

final smartMatchingRepositoryProvider = Provider<SmartMatchingRepository>((ref) {
  return SmartMatchingRepository(Supabase.instance.client);
});

class SmartMatchResult {
  final String analysisSource;
  final List<Map<String, dynamic>> topTechnicians;
  final String? recommendedTechnicianId;
  final List<String> fallbackTechnicianIds;
  final double autoPickThreshold;
  final String reasoning;

  const SmartMatchResult({
    required this.analysisSource,
    required this.topTechnicians,
    required this.recommendedTechnicianId,
    required this.fallbackTechnicianIds,
    required this.autoPickThreshold,
    required this.reasoning,
  });

  factory SmartMatchResult.fromJson(Map<String, dynamic> json) {
    return SmartMatchResult(
      analysisSource: json['analysisSource']?.toString() ?? 'heuristic',
      topTechnicians: (json['topTechnicians'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      recommendedTechnicianId: json['recommendedTechnicianId']?.toString(),
      fallbackTechnicianIds: (json['fallbackTechnicianIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      autoPickThreshold: (json['autoPickThreshold'] as num?)?.toDouble() ?? 60,
      reasoning: json['reasoning']?.toString() ?? '',
    );
  }
}

class SmartMatchingRepository {
  final SupabaseClient _client;

  SmartMatchingRepository(this._client);

  Future<SmartMatchResult> rankTechnicians({
    required String service,
    String? area,
    String? description,
    SmartDiagnosis? diagnosis,
  }) async {
    final payload = {
      'service': service,
      'area': area,
      'description': description,
      'diagnosis': diagnosis == null
          ? null
          : {
              'detectedCategory': diagnosis.detectedCategory,
              'categoryNameAr': diagnosis.categoryNameAr,
              'confidence': diagnosis.confidence,
              'problemSummary': diagnosis.problemSummary,
              'possibleIssue': diagnosis.possibleIssue,
              'recommendedAction': diagnosis.recommendedAction,
              'needsTechnician': diagnosis.needsTechnician,
              'urgency': diagnosis.urgency,
              'safetyNotes': diagnosis.safetyNotes,
            },
    };

    final response = await _client.functions.invoke(
      'smart-match',
      body: payload,
    );

    if (response.status != 200) {
      throw Exception('Smart match failed: ${response.status}');
    }

    final data = response.data is String
        ? jsonDecode(response.data as String) as Map<String, dynamic>
        : Map<String, dynamic>.from(response.data as Map);
    return SmartMatchResult.fromJson(data);
  }
}
