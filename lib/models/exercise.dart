class Exercise {
  final int id;
  final String name;
  final String coachingCues;
  final String? mediaUrl;

  Exercise({
    required this.id,
    required this.name,
    required this.coachingCues,
    this.mediaUrl,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'],
      name: map['name'],
      coachingCues: map['coaching_cues'] ?? '',
      mediaUrl: map['media_url'],
    );
  }
}
