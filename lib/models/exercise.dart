import 'exercise.dart';

class Exercise {
  final String name;
  final String description;
  final String mediaUrl; // image or video
  final int sets;
  final int reps;
  final int duration; // seconds for timed exercises, 0 if not timed

  Exercise({
    required this.name,
    required this.description,
    required this.mediaUrl,
    required this.sets,
    required this.reps,
    required this.duration,
  });
}



final List<Exercise> mockExercises = [
  Exercise(
    name: "Push Ups",
    description: "Standard push-ups to build chest and triceps.",
    mediaUrl: "https://via.placeholder.com/150",
    sets: 3,
    reps: 12,
    duration: 0,
  ),
  Exercise(
    name: "Plank",
    description: "Hold a plank to strengthen your core.",
    mediaUrl: "https://via.placeholder.com/150",
    sets: 3,
    reps: 0,
    duration: 60,
  ),
  Exercise(
    name: "Squats",
    description: "Bodyweight squats for legs and glutes.",
    mediaUrl: "https://via.placeholder.com/150",
    sets: 3,
    reps: 15,
    duration: 0,
  ),
];
