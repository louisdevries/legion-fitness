import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
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
    final c = AppColors.of(context);
    if (bmi < 18.5) return const Color(0xFF7FD1C2);
    if (bmi < 25) return c.accent;
    if (bmi < 30) return c.premium;
    return AppTheme.danger;
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy range';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Health profile")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bmi = _calculateBMI();
    final c = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Health profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= BMI CARD =================
              if (bmi != null)
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('BMI', style: TextStyle(color: c.muted)),
                              Text(bmi.toStringAsFixed(1),
                                  style: appDisplay(context, 44)),
                            ],
                          ),
                          const Spacer(),
                          AppPill(_bmiLabel(bmi),
                              filled: true, color: _bmiColor(bmi)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppProgressBar(
                        (bmi.clamp(10, 40) - 10) / 30,
                        height: 8,
                        color: _bmiColor(bmi),
                      ),
                    ],
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
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const AppIconBadge(Icons.monitor_weight_outlined),
                      const SizedBox(width: 12),
                      Text('Current weight', style: TextStyle(color: c.muted)),
                      const Spacer(),
                      Text(
                        weightUnit == 'lbs'
                            ? '${(latestWeightKg! * 2.20462).toStringAsFixed(1)} lbs'
                            : '${latestWeightKg!.toStringAsFixed(1)} kg',
                        style: appDisplay(context, 26),
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

              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
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
