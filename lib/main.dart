import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/loading_overlay.dart';
import 'package:flutter_map/flutter_map.dart';

// Screens
import 'auth/splash_screen.dart';
import 'auth/login_screen.dart';
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
  static final muteTimerSounds = ValueNotifier<bool>(false);
  static final globalLoading = ValueNotifier<bool>(false);
  static final googleFitEnabled = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final theme = prefs.getString('themeMode');
    // Use 'rest_seconds' — the key shared with SettingsService.
    final rest = prefs.getInt('rest_seconds');
    final mute = prefs.getBool('muteTimerSounds');
    final googleFit = prefs.getBool('googleFitEnabled');

    if (theme != null) {
      themeMode.value = ThemeMode.values.firstWhere(
            (e) => e.name == theme,
        orElse: () => ThemeMode.system,
      );
    }
    if (rest != null) restTimerSeconds.value = rest;
    if (mute != null) muteTimerSounds.value = mute;
    if (googleFit != null) googleFitEnabled.value = googleFit;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    themeMode.value = mode;
  }

  static Future<void> setRestTimer(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rest_seconds', seconds);
    restTimerSeconds.value = seconds;
  }

  static Future<void> setMuteTimerSounds(bool mute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('muteTimerSounds', mute);
    muteTimerSounds.value = mute;
  }

  static Future<void> setGoogleFitEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('googleFitEnabled', enabled);
    googleFitEnabled.value = enabled;
  }

  static void showLoading() => globalLoading.value = true;
  static void hideLoading() => globalLoading.value = false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure flutter_map's built-in tile cache.
  BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 2 * 1024 * 1024 * 1024,
    overrideFreshAge: const Duration(days: 30),
    tileKeyGenerator: (url) {
      final uri = Uri.parse(url);
      final cleaned = uri.replace(queryParameters: Map.of(uri.queryParameters)
        ..remove('access_token'));
      return cleaned.toString();
    },
  );

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
      builder: (_, themeMode, _) {
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
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
            useMaterial3: true,
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.green,
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

          home: const SplashScreen(),
        );
      },
    );
  }
}

/// =======================================================
/// ===================== AUTH GATE =======================
/// =======================================================

class AuthGate extends StatefulWidget {
  final bool hasSeenWelcome;
  const AuthGate({super.key, this.hasSeenWelcome = false});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _isLoggedIn;
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
    _authStream.listen((event) {
      final loggedIn = event.session != null;
      if (loggedIn != _isLoggedIn && mounted) {
        setState(() => _isLoggedIn = loggedIn);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return const MainShell(isGuest: false);
    }
    if (!widget.hasSeenWelcome) {
      return const LoginScreen(showSkip: true);
    }
    return const MainShell(isGuest: true);
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

  bool _isRunMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await Permission.ignoreBatteryOptimizations.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    });
  }

  final List<String> _titles = const [
    'Home',
    'Programs',
    'Outdoor Run',
    'Progress',
    'Profile',
  ];

  void _goToPrograms() => setState(() => _currentIndex = 1);

  List<Widget> get _screens => [
    HomeScreen(onGoToPrograms: _goToPrograms),
    const ProgramsScreen(),
    OutdoorRunScreen(
      onRunModeChanged: (value) {
        setState(() {
          _isRunMode = value;
        });
      },
    ),
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

        // 🔒 BLOCK TAB SWITCHING WHEN RUN MODE ACTIVE
        onTap: _isRunMode
            ? null
            : (index) => setState(() => _currentIndex = index),

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
