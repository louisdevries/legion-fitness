import 'dart:async';
import 'package:flutter/material.dart';

class RestScreen extends StatefulWidget {
  final int restSeconds;

  const RestScreen({super.key, required this.restSeconds});

  @override
  State<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends State<RestScreen> {
  late int remaining;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    remaining = widget.restSeconds;
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remaining <= 1) {
        t.cancel();
        Navigator.pop(context, true);
      } else {
        setState(() => remaining--);
      }
    });
  }

  void addSeconds(int s) {
    setState(() => remaining += s);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rest")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Rest", style: TextStyle(fontSize: 28)),
            const SizedBox(height: 16),
            Text(
              "$remaining",
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => addSeconds(10),
                  child: const Text("+10s"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Skip"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
