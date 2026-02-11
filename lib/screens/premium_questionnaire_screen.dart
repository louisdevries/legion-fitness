import 'package:flutter/material.dart';
import '../models/paid_user_details.dart';
import '../services/premium_user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PremiumQuestionnaireScreen extends StatefulWidget {
  const PremiumQuestionnaireScreen({super.key});

  @override
  State<PremiumQuestionnaireScreen> createState() =>
      _PremiumQuestionnaireScreenState();
}

class _PremiumQuestionnaireScreenState
    extends State<PremiumQuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Form controllers
  final _ageController = TextEditingController();
  String? _gender;
  String? _experience;
  String? _goals;
  String? _fitnessType;
  final _injuriesController = TextEditingController();

  bool _isSubmitting = false;

  // Example options
  final List<String> genderOptions = ['Male', 'Female'];
  final List<String> experienceOptions = [
    'Beginner',
    'Intermediate',
    'Advanced'
  ];
  final List<String> goalsOptions = [
    'Lose weight',
    'Build muscle',
    'Increase endurance',
    'General fitness'
  ];
  final List<String> fitnessTypeOptions = [
    'Strength',
    'Cardio',
    'Mixed',
    'Flexibility'
  ];

  @override
  void initState() {
    super.initState();

    // Listen to age text changes so Next button updates immediately
    _ageController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _injuriesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _submitForm();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitForm() async {

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    final detail = PaidUserDetail(
      userId: user.id, // ✅ UUID string
      age: int.tryParse(_ageController.text),
      gender: _gender,
      experience: _experience,
      goals: _goals,
      fitnessType: _fitnessType,
      injuries: _injuriesController.text,
    );


    try {
      await PremiumUserService.savePaidUserDetail(detail);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium questionnaire submitted!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildStep({
    required String question,
    required Widget inputWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          inputWidget,
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                ElevatedButton(
                  onPressed: _previousStep,
                  child: const Text('Back'),
                ),
              ElevatedButton(
                onPressed: _isStepValid() ? _nextStep : null,
                child: Text(_currentStep == 5 ? 'Submit' : 'Next'),
              ),
            ],
          )
        ],
      ),
    );
  }

  bool _isStepValid() {
    switch (_currentStep) {
      case 0:
        return int.tryParse(_ageController.text) != null;
      case 1:
        return _gender != null;
      case 2:
        return _experience != null;
      case 3:
        return _goals != null;
      case 4:
        return _fitnessType != null;
      case 5:
        return true; // injuries optional
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Program Questionnaire'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep(
            question: 'How old are you?',
            inputWidget: TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Age', border: OutlineInputBorder()),
            ),
          ),
          _buildStep(
            question: 'Select your gender',
            inputWidget: Column(
              children: genderOptions
                  .map((g) => RadioListTile<String>(
                title: Text(g),
                value: g,
                groupValue: _gender,
                onChanged: (v) => setState(() => _gender = v),
              ))
                  .toList(),
            ),
          ),
          _buildStep(
            question: 'Your fitness experience level?',
            inputWidget: Column(
              children: experienceOptions
                  .map((e) => RadioListTile<String>(
                title: Text(e),
                value: e,
                groupValue: _experience,
                onChanged: (v) => setState(() => _experience = v),
              ))
                  .toList(),
            ),
          ),
          _buildStep(
            question: 'What are your goals?',
            inputWidget: Column(
              children: goalsOptions
                  .map((g) => RadioListTile<String>(
                title: Text(g),
                value: g,
                groupValue: _goals,
                onChanged: (v) => setState(() => _goals = v),
              ))
                  .toList(),
            ),
          ),
          _buildStep(
            question: 'Preferred fitness type?',
            inputWidget: Column(
              children: fitnessTypeOptions
                  .map((f) => RadioListTile<String>(
                title: Text(f),
                value: f,
                groupValue: _fitnessType,
                onChanged: (v) => setState(() => _fitnessType = v),
              ))
                  .toList(),
            ),
          ),
          _buildStep(
            question: 'Any injuries or health concerns?',
            inputWidget: TextField(
              controller: _injuriesController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Injuries / Concerns',
                  border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
    );
  }
}
