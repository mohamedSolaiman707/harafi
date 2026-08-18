import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/supabase_smart_assistant_repository.dart';
import '../../domain/entities/smart_diagnosis.dart';
import '../../domain/repositories/smart_assistant_repository.dart';
import '../../domain/usecases/analyze_problem_usecase.dart';

final smartAssistantRepositoryProvider = Provider<SmartAssistantRepository>((ref) {
  return SupabaseSmartAssistantRepository(Supabase.instance.client);
});

final analyzeProblemUseCaseProvider = Provider<AnalyzeProblemUseCase>((ref) {
  final repository = ref.watch(smartAssistantRepositoryProvider);
  return AnalyzeProblemUseCase(repository);
});

class SmartAssistantState {
  static const Object _unset = Object();
  static const Object _imageUnset = Object();

  final bool isLoading;
  final String? error;
  final SmartDiagnosis? diagnosis;
  final List<FollowUpAnswer> answers;
  final File? selectedImage;
  final String description;

  SmartAssistantState({
    this.isLoading = false,
    this.error,
    this.diagnosis,
    this.answers = const [],
    this.selectedImage,
    this.description = '',
  });

  SmartAssistantState copyWith({
    bool? isLoading,
    Object? error = _unset,
    SmartDiagnosis? diagnosis,
    List<FollowUpAnswer>? answers,
    Object? selectedImage = _imageUnset,
    String? description,
  }) {
    return SmartAssistantState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      diagnosis: diagnosis ?? this.diagnosis,
      answers: answers ?? this.answers,
      selectedImage: identical(selectedImage, _imageUnset)
          ? this.selectedImage
          : selectedImage as File?,
      description: description ?? this.description,
    );
  }
}

class SmartAssistantNotifier extends StateNotifier<SmartAssistantState> {
  final AnalyzeProblemUseCase _analyzeUseCase;

  SmartAssistantNotifier(this._analyzeUseCase) : super(SmartAssistantState());

  void setDescription(String desc) => state = state.copyWith(description: desc);
  void setImage(File? image) => state = state.copyWith(selectedImage: image);

  Future<void> analyze() async {
    if (state.description.isEmpty && state.selectedImage == null) {
      state = state.copyWith(error: 'يرجى كتابة المشكلة أو إرفاق صورة أولاً');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _analyzeUseCase(
        description: state.description,
        image: state.selectedImage,
        answers: state.answers,
      );
      state = state.copyWith(isLoading: false, diagnosis: result, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'عذراً، حدث خطأ أثناء التحليل. حاول مرة أخرى.');
    }
  }

  void addAnswer(String question, String answer) {
    final newAnswers = [...state.answers, FollowUpAnswer(question, answer)];
    state = state.copyWith(answers: newAnswers);
    analyze(); // Re-analyze with new information
  }

  void reset() {
    state = SmartAssistantState();
  }
}

final smartAssistantProvider = StateNotifierProvider.autoDispose<SmartAssistantNotifier, SmartAssistantState>((ref) {
  final useCase = ref.watch(analyzeProblemUseCaseProvider);
  return SmartAssistantNotifier(useCase);
});
