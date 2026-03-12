class Recipe {
  final String id;
  final String title;
  final String imageUrl;
  final int ownedIngredients;
  final int totalIngredients;
  final double matchPercentage;
  final List<String> tags;

  const Recipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.ownedIngredients,
    required this.totalIngredients,
    required this.matchPercentage,
    this.tags = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'].toString(),
      title: json['title'] as String,
      imageUrl: json['image_url'] as String? ?? '',
      ownedIngredients: json['owned_ingredients'] as int? ?? 0,
      totalIngredients: json['total_ingredients'] as int? ?? 0,
      matchPercentage: (json['match_percentage'] as num?)?.toDouble() ?? 0.0,
      tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'owned_ingredients': ownedIngredients,
      'total_ingredients': totalIngredients,
      'match_percentage': matchPercentage,
      'tags': tags,
    };
  }
}

