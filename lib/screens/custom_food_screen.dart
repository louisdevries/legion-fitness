import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food.dart';
import '../services/food_service.dart';

/// Form for entering a food from its nutrition label. Pops with the saved
/// [Food], or null if cancelled.
class CustomFoodScreen extends StatefulWidget {
  final String? barcode;
  const CustomFoodScreen({super.key, this.barcode});

  @override
  State<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends State<CustomFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _salt = TextEditingController();
  final _serving = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name, _brand, _kcal, _protein, _carbs,
      _fat, _fiber, _sugar, _salt, _serving,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Accept both "4.5" and "4,5" — the app runs in en_ZA.
  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final brand = _brand.text.trim();
    final food = Food(
      source: 'user',
      barcode: widget.barcode,
      name: _name.text.trim(),
      brand: brand.isEmpty ? null : brand,
      kcal100g: _parse(_kcal.text)!,
      protein100g: _parse(_protein.text),
      carbs100g: _parse(_carbs.text),
      fat100g: _parse(_fat.text),
      fiber100g: _parse(_fiber.text),
      sugar100g: _parse(_sugar.text),
      salt100g: _parse(_salt.text),
      servingG: _parse(_serving.text),
    );

    try {
      final saved = await FoodService.createCustomFood(food);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.code == '23505'
              ? 'You already saved a food for this barcode.'
              : 'Could not save food: ${e.message}'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  String? _requiredNumber(String? v) {
    final n = _parse(v ?? '');
    if (n == null) return 'Required';
    if (n < 0) return 'Must be 0 or more';
    return null;
  }

  String? _optionalNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = _parse(v);
    if (n == null) return 'Not a number';
    if (n < 0) return 'Must be 0 or more';
    return null;
  }

  Widget _numberField(
    TextEditingController c,
    String label, {
    String suffix = 'g',
    bool required = false,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        suffixText: suffix,
      ),
      validator: required ? _requiredNumber : _optionalNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Food'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.barcode != null) ...[
              Text(
                'Barcode ${widget.barcode}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brand,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Brand',
              ),
            ),
            const SizedBox(height: 24),
            Text('Per 100 g', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _numberField(_kcal, 'Energy', suffix: 'kcal', required: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField(_protein, 'Protein')),
                const SizedBox(width: 12),
                Expanded(child: _numberField(_carbs, 'Carbs')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField(_fat, 'Fat')),
                const SizedBox(width: 12),
                Expanded(child: _numberField(_fiber, 'Fibre')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField(_sugar, 'Sugar')),
                const SizedBox(width: 12),
                Expanded(child: _numberField(_salt, 'Salt')),
              ],
            ),
            const SizedBox(height: 24),
            _numberField(_serving, 'Serving size'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Food'),
            ),
          ],
        ),
      ),
    );
  }
}
