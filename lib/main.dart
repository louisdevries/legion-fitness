import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'widgets/loading_overlay.dart';

// Screens
import 'auth/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/outdoor_run_screen.dart';

/// =======================================================
/// =============== GLOBAL APP SETTINGS ===================
/// =======================================================

class AppSettings {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final restTimerSeconds = ValueNotifier<int>(60);
  static final globalLoading = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final theme = prefs.getString('themeMode');
    final rest = prefs.getInt('restTimerSeconds');

    if (theme != null) {
      themeMode.value = ThemeMode.values.firstWhere(
            (e) => e.name == theme,
        orElse: () => ThemeMode.system,
      );
    }

    if (rest != null) {
      restTimerSeconds.value = rest;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    themeMode.value = mode;
  }

  static Future<void> setRestTimer(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('restTimerSeconds', seconds);
    restTimerSeconds.value = seconds;
  }

  static void showLoading() => globalLoading.value = true;
  static void hideLoading() => globalLoading.value = false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nvfoyrffwmufohcfppac.supabase.co',
    anonKey: 'sb_publishable_Azh2yCvYGguExBupLcQHTQ_hU9y4WVy',
  );

  await AppSettings.load();

  runApp(const LegionFitnessApp());
}

/// =======================================================
/// ===================== APP ROOT ========================
/// =======================================================

class LegionFitnessApp extends StatelessWidget {
  const LegionFitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (_, themeMode, __) {
        return MaterialApp(
          title: 'Legion Fitness',
          debugShowCheckedModeBanner: false,

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

          themeMode: themeMode,

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          builder: (context, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: AppSettings.globalLoading,
              builder: (context, isLoading, _) {
                return LoadingOverlay(
                  isLoading: isLoading,
                  child: child!,
                );
              },
            );
          },

          home: const AuthGate(),
        );
      },
    );
  }
}

/// =======================================================
/// ===================== AUTH GATE =======================
/// =======================================================

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

        if (!hasSeenWelcome!) {
          return const WelcomeScreen();
        }

        if (session != null) {
          return const MainShell(isGuest: false);
        }

        return const MainShell(isGuest: true);
      },
    );
  }
}

/// =======================================================
/// ===================== MAIN SHELL ======================
/// =======================================================

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
        onTap: (index) => setState(() => _currentIndex = index),
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
