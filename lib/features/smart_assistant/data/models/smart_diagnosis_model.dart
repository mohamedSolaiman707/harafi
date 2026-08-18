import '../../domain/entities/smart_diagnosis.dart';

class SmartDiagnosisModel extends SmartDiagnosis {
  SmartDiagnosisModel({
    super.detectedCategory,
    super.categoryNameAr,
    required super.confidence,
    required super.problemSummary,
    required super.possibleIssue,
    super.recommendedAction,
    super.analysisSource,
    required super.needsTechnician,
    required super.urgency,
    super.safetyNotes,
    super.followUpQuestions,
  });

  factory SmartDiagnosisModel.fromJson(Map<String, dynamic> json) {
    return SmartDiagnosisModel(
      detectedCategory: json['detectedCategory']?.toString(),
      categoryNameAr: json['categoryNameAr']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      problemSummary: json['problemSummary']?.toString() ?? '',
      possibleIssue: json['possibleIssue']?.toString() ?? '',
      recommendedAction: json['recommendedAction']?.toString() ?? '',
      analysisSource: json['analysisSource']?.toString() ?? 'openai',
      needsTechnician: json['needsTechnician'] == true,
      urgency: json['urgency']?.toString() ?? 'normal',
      safetyNotes: (json['safetyNotes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      followUpQuestions: (json['followUpQuestions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detectedCategory': detectedCategory,
      'categoryNameAr': categoryNameAr,
      'confidence': confidence,
      'problemSummary': problemSummary,
      'possibleIssue': possibleIssue,
      'recommendedAction': recommendedAction,
      'analysisSource': analysisSource,
      'needsTechnician': needsTechnician,
      'urgency': urgency,
      'safetyNotes': safetyNotes,
      'followUpQuestions': followUpQuestions,
    };
  }
}
