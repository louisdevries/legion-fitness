class Program {
  final int id;
  final String name;
  final bool isForMen;
  final bool isForWomen;
  final String imageUrl;
  final String description;
  final int weeks;

  Program({
    required this.id,
    required this.name,
    required this.isForMen,
    required this.isForWomen,
    required this.imageUrl,
    required this.description,
    required this.weeks,
  });

  factory Program.fromMap(Map<String, dynamic> map) {
    return Program(
      id: map['id'] as int,
      name: map['name'] as String,
      isForMen: map['is_for_men'] as bool,
      isForWomen: map['is_for_women'] as bool,
      imageUrl: map['image_url'] as String? ?? 'https://via.placeholder.com/150',
      description: map['description'] as String? ?? '',
      weeks: map['weeks'] as int? ?? 0,
    );
  }
}
