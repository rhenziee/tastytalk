class RecipeModel {
  final String title;
  final String image;
  final List<String> ingredients;
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

    List<String> parseList(dynamic list) {
      if (list == null) return [];
      if (list is List) {
        return list.map((item) {
          if (item is Map) {
            final quantity = item['quantity'] ?? '';
            final unit = item['unit'] ?? '';
            final name = item['name'] ?? '';
            return "$quantity $unit $name".trim();
          } else if (item is String) {
            return item;
          } else {
            return item.toString();
          }
        }).toList();
      }
      return [];
    }

    return RecipeModel(
      title: map['name']?.toString().trim() ?? '',
      image: map['imageUrl']?.toString().trim() ?? '',
      ingredients: parseList(map['ingredients']),
      procedures: parseList(map['procedures']),
      duration: map['duration']?.toString().trim() ?? '0',
      archived: map['archived'] ?? false,
      ingredientsFil: map['ingredientsFil']?.toString().trim() ?? '',
      proceduresFil: map['proceduresFil']?.toString().trim() ?? '',
      rating: double.tryParse(map['rating']?.toString() ?? '0') ?? 0.0,
    );
  }
}
