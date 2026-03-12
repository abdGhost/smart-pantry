class RecipeStepDetails {
  final int order;
  final String text;

  const RecipeStepDetails({
    required this.order,
    required this.text,
  });

  factory RecipeStepDetails.fromJson(Map<String, dynamic> json) {
    return RecipeStepDetails(
      order: (json['order'] as num?)?.toInt() ?? 1,
      text: json['text'] as String? ?? '',
    );
  }
}

class RecipeDetails {
  final String title;
  final String summary;
  final int estimatedTimeMinutes;
  final String difficulty;
  final List<RecipeStepDetails> steps;
  final List<String> tips;

  const RecipeDetails({
    required this.title,
    required this.summary,
    required this.estimatedTimeMinutes,
    required this.difficulty,
    required this.steps,
    required this.tips,
  });

  factory RecipeDetails.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? const [];
    return RecipeDetails(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      estimatedTimeMinutes:
          (json['estimated_time_minutes'] as num?)?.toInt() ?? 20,
      difficulty: json['difficulty'] as String? ?? 'Easy',
      steps: stepsJson
          .map((e) =>
              RecipeStepDetails.fromJson(e as Map<String, dynamic>))
          .toList(),
      tips: (json['tips'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }
}

