/// نموذج إجابة واستشارة المدرب الذكي في CoachMint.
class CoachAdvice {
  const CoachAdvice({
    required this.answer,
    required this.recommendation,
    this.alternativeExercise = '',
    this.warning,
  });

  final String answer;
  final String recommendation;
  final String alternativeExercise;
  final String? warning;

  factory CoachAdvice.fromJson(Map<String, dynamic> json) {
    return CoachAdvice(
      answer: json['answer']?.toString() ?? '',
      recommendation: json['recommendation']?.toString() ?? '',
      alternativeExercise: json['alternativeExercise']?.toString() ?? '',
      warning: json['warning']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'answer': answer,
        'recommendation': recommendation,
        'alternativeExercise': alternativeExercise,
        if (warning != null) 'warning': warning,
      };
}
