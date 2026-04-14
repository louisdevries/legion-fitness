import 'package:flutter/material.dart';
import '../../../utils/exercise_category_utils.dart';

class CategoryBadge extends StatelessWidget {
  final String category;

  const CategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ExerciseCategoryUtils.getColor(category),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          ExerciseCategoryUtils.getLabel(category),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}