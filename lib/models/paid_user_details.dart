class PaidUserDetail {
  final int? id; // optional DB primary key
  final String userId; // UUID from Supabase auth
  final int? age;
  final String? gender;
  final String? experience;
  final String? goals;
  final String? fitnessType;
  final String? injuries;

  PaidUserDetail({
    this.id,
    required this.userId,
    this.age,
    this.gender,
    this.experience,
    this.goals,
    this.fitnessType,
    this.injuries,
  });

  /// Convert Dart object → Supabase insert/update
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'age': age,
      'gender': gender,
      'experience': experience,
      'goals': goals,
      'fitness_type': fitnessType,
      'injuries': injuries,
    };
  }

  /// Convert Supabase row → Dart object
  factory PaidUserDetail.fromMap(Map<String, dynamic> map) {
    return PaidUserDetail(
      id: map['id'] as int?,
      userId: map['user_id'] as String, // ✅ FIXED
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      experience: map['experience'] as String?,
      goals: map['goals'] as String?,
      fitnessType: map['fitness_type'] as String?,
      injuries: map['injuries'] as String?,
    );
  }
}
