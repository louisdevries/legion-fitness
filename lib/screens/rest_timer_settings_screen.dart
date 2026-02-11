import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class RestTimerSettingsScreen extends StatefulWidget {
  const RestTimerSettingsScreen({super.key});

  @override
  State<RestTimerSettingsScreen> createState() =>
      _RestTimerSettingsScreenState();
}

class _RestTimerSettingsScreenState extends State<RestTimerSettingsScreen> {
  int restSeconds = 60;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    restSeconds = await SettingsService.getRestSeconds();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rest Timer")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "$restSeconds seconds",
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 24),

            Slider(
              min: 15,
              max: 180,
              divisions: 11,
              value: restSeconds.toDouble(),
              label: "$restSeconds",
              onChanged: (v) =>
                  setState(() => restSeconds = v.round()),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                await SettingsService.setRestSeconds(restSeconds);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}
