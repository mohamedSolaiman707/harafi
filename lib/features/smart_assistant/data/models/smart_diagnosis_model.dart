import '../../domain/entities/smart_diagnosis.dart';

class SmartDiagnosisModel extends SmartDiagnosis {
  SmartDiagnosisModel({
    super.detectedCategory,
    super.categoryNameAr,
    required super.confidence,
    super.confidenceLevel,
    required super.problemSummary,
    required super.possibleIssue,
    super.secondaryIssue,
    super.recommendedAction,
    super.diyTip,
    super.estimatedPartsCost,
    super.analysisSource,
    required super.needsTechnician,
    required super.urgency,
    super.safetyLevel,
    super.safetyNotes,
    super.followUpQuestions,
  });

  factory SmartDiagnosisModel.fromJson(Map<String, dynamic> json) {
    return SmartDiagnosisModel(
      detectedCategory: json['detectedCategory']?.toString(),
      categoryNameAr: json['categoryNameAr']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      confidenceLevel: json['confidenceLevel']?.toString() ?? 'medium',
      problemSummary: json['problemSummary']?.toString() ?? '',
      possibleIssue: json['possibleIssue']?.toString() ?? '',
      secondaryIssue: json['secondaryIssue']?.toString(),
      recommendedAction: json['recommendedAction']?.toString() ?? '',
      diyTip: json['diyTip']?.toString() ?? json['diy_tip']?.toString(),
      estimatedPartsCost: json['estimatedPartsCost']?.toString() ?? json['estimated_parts_cost']?.toString(),
      analysisSource: json['analysisSource']?.toString() ?? 'openai',
      needsTechnician: json['needsTechnician'] == true,
      urgency: json['urgency']?.toString() ?? 'normal',
      safetyLevel: json['safetyLevel']?.toString(),
      safetyNotes: (json['safetyNotes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      followUpQuestions: (json['followUpQuestions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detectedCategory': detectedCategory,
      'categoryNameAr': categoryNameAr,
      'confidence': confidence,
      'confidenceLevel': confidenceLevel,
      'problemSummary': problemSummary,
      'possibleIssue': possibleIssue,
      'secondaryIssue': secondaryIssue,
      'recommendedAction': recommendedAction,
      'diyTip': diyTip,
      'estimatedPartsCost': estimatedPartsCost,
      'analysisSource': analysisSource,
      'needsTechnician': needsTechnician,
      'urgency': urgency,
      'safetyLevel': safetyLevel,
      'safetyNotes': safetyNotes,
      'followUpQuestions': followUpQuestions,
    };
  }
}
