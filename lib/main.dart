import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';

import 'auth/welcome_screen.dart';
import 'auth/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Widget> _decideStartScreen() async {
  final prefs = await SharedPreferences.getInstance();
  final hasSeenWelcome = prefs.getBool("hasSeenWelcome") ?? false;
  final isLoggedIn = await AuthService.getToken() != null;

  if (!hasSeenWelcome) {
    return const WelcomeScreen();
  }

  // If user has seen welcome, go to app
  return const MainShell();
}


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nvfoyrffwmufohcfppac.supabase.co',
    anonKey: 'sb_publishable_Azh2yCvYGguExBupLcQHTQ_hU9y4WVy',
  );

  runApp(const LegionFitnessApp());
}


class LegionFitnessApp extends StatelessWidget {
  const LegionFitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legion Fitness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder<Widget>(
        future: _decideStartScreen(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!;
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ProgramsScreen(),
    const ProgressScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = const [
    'Home',
    'Programs',
    'Progress',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Programs'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
