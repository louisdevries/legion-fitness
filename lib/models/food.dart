class Food {
  final int? id;
  final String source; // 'off' = Open Food Facts, 'usda' = USDA FDC, 'user' = custom
  final String? barcode;
  final int? fdcId; // USDA FoodData Central id
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
  final String? servingLabel; // e.g. "1 egg, whole without shell"
  final String? imageUrl;
  final String? createdBy;

  Food({
    this.id,
    required this.source,
    this.barcode,
    this.fdcId,
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
    this.servingLabel,
    this.imageUrl,
    this.createdBy,
  });

  bool get isFromOpenFoodFacts => source == 'off';
  bool get isFromUsda => source == 'usda';

  double kcalFor(double grams) => kcal100g * grams / 100;

  Food withServing(double? grams, String? label) => Food(
        id: id,
        source: source,
        barcode: barcode,
        fdcId: fdcId,
        name: name,
        brand: brand,
        kcal100g: kcal100g,
        protein100g: protein100g,
        carbs100g: carbs100g,
        fat100g: fat100g,
        fiber100g: fiber100g,
        sugar100g: sugar100g,
        salt100g: salt100g,
        servingG: grams,
        servingLabel: label,
        imageUrl: imageUrl,
        createdBy: createdBy,
      );

  factory Food.fromMap(Map<String, dynamic> map) {
    double? d(String key) => (map[key] as num?)?.toDouble();
    return Food(
      id: (map['id'] as num?)?.toInt(),
      source: map['source'] as String,
      barcode: map['barcode'] as String?,
      fdcId: (map['fdc_id'] as num?)?.toInt(),
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
      servingLabel: map['serving_label'] as String?,
      imageUrl: map['image_url'] as String?,
      createdBy: map['created_by'] as String?,
    );
  }

  /// Columns for insert — id and created_by are filled in by the database.
  Map<String, dynamic> toInsertMap() => {
        'source': source,
        'barcode': barcode,
        'fdc_id': fdcId,
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
        'serving_label': servingLabel,
        'image_url': imageUrl,
      };
}
