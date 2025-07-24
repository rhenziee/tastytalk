class RecipeModel {
  final String title;
  final String image;
  final List<Map<String, dynamic>> ingredients;
  final List<String> procedures;
  final String duration;
  final bool archived;
  final String ingredientsFil;
  final String proceduresFil;
  final double rating;

  RecipeModel({
    required this.title,
    required this.image,
    required this.ingredients,
    required this.procedures,
    required this.duration,
    this.archived = false,
    required this.ingredientsFil,
    required this.proceduresFil,
    required this.rating,
  });

  factory RecipeModel.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('name') || !map.containsKey('imageUrl')) {
      throw Exception('Missing required fields in recipe data');
    }

    List<Map<String, dynamic>> parseIngredients(dynamic list) {
      if (list == null || list is! List) return [];

      return list.map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) {
          return {
            'name': item['name'] ?? '',
            'quantity': item['quantity'] ?? '',
            'unit': item['unit'] ?? '',
            'substitutes': List<String>.from(item['substitutes'] ?? []),
          };
        }
        return {'name': item.toString()};
      }).toList();
    }

    List<String> parseProcedures(dynamic list) {
      if (list == null || list is! List) return [];
      return list.map((item) => item.toString()).toList();
    }

    return RecipeModel(
      title: map['name']?.toString().trim() ?? '',
      image: map['imageUrl']?.toString().trim() ?? '',
      ingredients: parseIngredients(map['ingredients']),
      procedures: parseProcedures(map['procedures']),
      duration: map['duration']?.toString().trim() ?? '0',
      archived: map['archived'] ?? false,
      ingredientsFil: map['ingredientsFil']?.toString().trim() ?? '',
      proceduresFil: map['proceduresFil']?.toString().trim() ?? '',
      rating: double.tryParse(map['rating']?.toString() ?? '0') ?? 0.0,
    );
  }
}
