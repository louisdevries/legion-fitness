import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import '../main.dart'; // Import AppSettings for universal loading

class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime? dateOfBirth;
  TextEditingController heightController = TextEditingController();
  TextEditingController newWeightController = TextEditingController();

  String heightUnit = 'cm';
  String weightUnit = 'kg';

  bool isLoading = true;

  double? latestWeightKg;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ================= DATE FORMAT =================
  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/"
        "${date.month.toString().padLeft(2, '0')}/"
        "${date.year}";
  }

  // ================= LOAD PROFILE + LATEST WEIGHT =================
  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Load profile
      final profile = await Supabase.instance.client
          .from('health_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          dateOfBirth = DateTime.parse(profile['date_of_birth']);
          heightController.text = (profile['height_cm'] as num).toString();
        });
      }

      // Load latest weight
      final latestWeight = await Supabase.instance.client
          .from('weight_logs')
          .select('weight_kg')
          .eq('user_id', user.id)
          .order('logged_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (latestWeight != null && mounted) {
        setState(() {
          latestWeightKg = (latestWeight['weight_kg'] as num).toDouble();
        });
      }
    } catch (e) {
      developer.log("Load error", error: e);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ================= SAVE PROFILE =================
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    AppSettings.showLoading(); // Show universal loading overlay

    final heightValue = double.tryParse(heightController.text) ?? 0;
    final heightCm = heightUnit == 'ft/in' ? heightValue * 30.48 : heightValue;

    try {
      final existing = await Supabase.instance.client
          .from('health_profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
        await Supabase.instance.client.from('health_profiles').update({
          'date_of_birth': dateOfBirth!.toIso8601String(),
          'height_cm': heightCm,
        }).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('health_profiles').insert({
          'user_id': user.id,
          'date_of_birth': dateOfBirth!.toIso8601String(),
          'height_cm': heightCm,
        });
      }

      // Save new weight if entered
      if (newWeightController.text.isNotEmpty) {
        double w = double.parse(newWeightController.text);
        double weightKg = weightUnit == 'lbs' ? w * 0.453592 : w;

        await Supabase.instance.client.from('weight_logs').insert({
          'user_id': user.id,
          'weight_kg': weightKg,
        });

        if (mounted) {
          setState(() {
            latestWeightKg = weightKg;
            newWeightController.clear();
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile saved successfully")),
        );
        setState(() {});
      }
    } catch (e, stack) {
      developer.log("Save error", error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save profile: $e")),
        );
      }
    } finally {
      AppSettings.hideLoading(); // Hide universal loading overlay
    }
  }

  // ================= BMI =================
  double? _calculateBMI() {
    final height = double.tryParse(heightController.text);
    if (height == null || height <= 0 || latestWeightKg == null) return null;

    double heightM = heightUnit == 'cm' ? height / 100 : height * 0.3048;
    return latestWeightKg! / (heightM * heightM);
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    final bmi = _calculateBMI();

    return Scaffold(
      appBar: AppBar(title: const Text("Health Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ================= BMI CARD =================
              if (bmi != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text("BMI: ${bmi.toStringAsFixed(1)}",
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: ((bmi.clamp(10, 40) - 10) / 30),
                          color: _bmiColor(bmi),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ================= DOB =================
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dateOfBirth ?? DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && mounted) {
                    setState(() => dateOfBirth = picked);
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: "Date of Birth"),
                    controller: TextEditingController(
                      text: dateOfBirth != null ? _formatDate(dateOfBirth!) : "",
                    ),
                    readOnly: true,
                    validator: (_) => dateOfBirth == null ? "Required" : null,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ================= HEIGHT =================
              TextFormField(
                controller: heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "Height (cm)"),
                validator: (v) => v == null || v.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 24),

              // ================= CURRENT WEIGHT =================
              if (latestWeightKg != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.monitor_weight_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Weight',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            weightUnit == 'lbs'
                                ? '${(latestWeightKg! * 2.20462).toStringAsFixed(1)} lbs'
                                : '${latestWeightKg!.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ================= NEW WEIGHT =================
              TextFormField(
                controller: newWeightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Log New Weight",
                  hintText: "Adds a new entry to history",
                ),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text("Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
