import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../main.dart';

class RestTimerSettingsScreen extends StatefulWidget {
  const RestTimerSettingsScreen({super.key});

  @override
  State<RestTimerSettingsScreen> createState() =>
      _RestTimerSettingsScreenState();
}

class _RestTimerSettingsScreenState extends State<RestTimerSettingsScreen> {
  int restSeconds = 60;
  bool _mute = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    restSeconds = await SettingsService.getRestSeconds();
    setState(() {
      _mute = AppSettings.muteTimerSounds.value;
    });
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

            SwitchListTile(
              title: const Text('Mute timer sounds'),
              subtitle: const Text('Silence tick and completion sounds during workouts'),
              value: _mute,
              onChanged: (v) => setState(() => _mute = v),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                await SettingsService.setRestSeconds(restSeconds);
                await AppSettings.setMuteTimerSounds(_mute);
                if (!context.mounted) return;
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
