import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Screens
import 'auth/login_screen.dart';
import 'auth/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/outdoor_run_screen.dart';

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

      // Force DD/MM/YYYY locale
      locale: const Locale('en', 'ZA'),
      supportedLocales: const [
        Locale('en', 'ZA'),
        Locale('en', 'GB'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      home: const AuthGate(),
    );
  }
}

// =======================================================
// ===================== AUTH GATE ======================
// =======================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? hasSeenWelcome;

  @override
  void initState() {
    super.initState();
    _loadWelcomeFlag();
  }

  Future<void> _loadWelcomeFlag() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hasSeenWelcome = prefs.getBool("hasSeenWelcome") ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hasSeenWelcome == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        // 1️⃣ First launch → show welcome
        if (!hasSeenWelcome!) {
          return const WelcomeScreen();
        }

        // 2️⃣ Logged in → main app
        if (session != null) {
          return const MainShell(isGuest: false);
        }

        // 3️⃣ Not logged in → allow guest access
        return const MainShell(isGuest: true);
      },
    );
  }
}

// =======================================================
// ===================== MAIN SHELL ======================
// =======================================================

class MainShell extends StatefulWidget {
  final bool isGuest;
  const MainShell({super.key, this.isGuest = false});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;
  final List<String> _titles = const [
    'Home',
    'Programs',
    'Outdoor Run',
    'Progress',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const ProgramsScreen(),
      const OutdoorRunScreen(),
      // Show guest-friendly message if not logged in
      widget.isGuest
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Sign up or log in to track your progress 📈",
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : const ProgressScreen(),
      // Always use ProfileScreen, it handles guest vs logged-in internally
      const ProfileScreen(),
    ];
  }

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
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Run'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
