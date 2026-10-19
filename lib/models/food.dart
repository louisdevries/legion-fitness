class Food {
  final int? id;
  final String source; // 'off' = Open Food Facts, 'user' = custom
  final String? barcode;
  final String name;
  final String? brand;
  final double kcal100g;
  final double? protein100g;
  final double? carbs100g;
  final double? fat100g;
  final double? fiber100g;
  final double? sugar100g;
  final double? salt100g;
  final double? servingG;
  final String? imageUrl;
  final String? createdBy;

  Food({
    this.id,
    required this.source,
    this.barcode,
    required this.name,
    this.brand,
    required this.kcal100g,
    this.protein100g,
    this.carbs100g,
    this.fat100g,
    this.fiber100g,
    this.sugar100g,
    this.salt100g,
    this.servingG,
    this.imageUrl,
    this.createdBy,
  });

  bool get isFromOpenFoodFacts => source == 'off';

  double kcalFor(double grams) => kcal100g * grams / 100;

  factory Food.fromMap(Map<String, dynamic> map) {
    double? d(String key) => (map[key] as num?)?.toDouble();
    return Food(
      id: (map['id'] as num?)?.toInt(),
      source: map['source'] as String,
      barcode: map['barcode'] as String?,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      kcal100g: d('kcal_100g')!,
      protein100g: d('protein_100g'),
      carbs100g: d('carbs_100g'),
      fat100g: d('fat_100g'),
      fiber100g: d('fiber_100g'),
      sugar100g: d('sugar_100g'),
      salt100g: d('salt_100g'),
      servingG: d('serving_g'),
      imageUrl: map['image_url'] as String?,
      createdBy: map['created_by'] as String?,
    );
  }

  /// Columns for insert — id and created_by are filled in by the database.
  Map<String, dynamic> toInsertMap() => {
        'source': source,
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'kcal_100g': kcal100g,
        'protein_100g': protein100g,
        'carbs_100g': carbs100g,
        'fat_100g': fat100g,
        'fiber_100g': fiber100g,
        'sugar_100g': sugar100g,
        'salt_100g': salt100g,
        'serving_g': servingG,
        'image_url': imageUrl,
      };
}
