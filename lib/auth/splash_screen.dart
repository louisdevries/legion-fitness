import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);

    if (!mounted) return;

    final prefs = results[0] as SharedPreferences;
    final hasSeenWelcome = prefs.getBool('hasSeenWelcome') ?? false;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AuthGate(hasSeenWelcome: hasSeenWelcome),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 260,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                backgroundColor: isDark
                    ? Colors.white12
                    : Colors.deepPurple.shade100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
