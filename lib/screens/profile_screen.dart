import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../main.dart';
import '../screens/health_profile_screen.dart';
import '../screens/premium_program_screen.dart';
import 'rest_timer_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? userName;
  String? userEmail;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = AuthService.currentUser;
    final name = await AuthService.getUserName();
    final email = AuthService.getUserEmail(); // Removed await as it's a String?, not a Future

    if (!mounted) return;
    setState(() {
      isLoggedIn = user != null;
      userName = name;
      userEmail = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return _buildLoggedOut(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          _buildAccountHeader(),

          _buildSectionHeader("Account"),
          _buildTile(
            icon: Icons.person,
            title: "Name",
            subtitle: userName ?? "Set your name",
            onTap: () {
              // TODO: Change name screen
            },
          ),
          _buildTile(
            icon: Icons.email,
            title: "Email",
            subtitle: userEmail ?? "",
            enabled: false,
          ),
          _buildTile(
            icon: Icons.lock,
            title: "Change Password",
            onTap: () {
              // TODO: Password reset
            },
          ),

          _buildSectionHeader("Health"),
          _buildTile(
            icon: Icons.favorite,
            title: "Health Profile",
            subtitle: "Weight, height, goals",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HealthProfileScreen(),
                ),
              );
            },
          ),

          _buildSectionHeader("Preferences"),
          _buildTile(
            icon: Icons.dark_mode,
            title: "Dark Mode",
            subtitle: "System / Light / Dark",
            onTap: () async {
              final selected = await showModalBottomSheet<ThemeMode>(
                context: context,
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text("System"),
                      onTap: () => Navigator.pop(context, ThemeMode.system),
                    ),
                    ListTile(
                      title: const Text("Light"),
                      onTap: () => Navigator.pop(context, ThemeMode.light),
                    ),
                    ListTile(
                      title: const Text("Dark"),
                      onTap: () => Navigator.pop(context, ThemeMode.dark),
                    ),
                  ],
                ),
              );

              if (selected != null) {
                await AppSettings.setThemeMode(selected);
              }
            },
          ),
          _buildTile(
            icon: Icons.timer,
            title: "Rest Timer",
            subtitle: "Default rest duration",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RestTimerSettingsScreen(),
                ),
              );
            },
          ),

          /// 🔹 PREMIUM PROGRAM LINK
          _buildSectionHeader("Premium"),
          _buildTile(
            icon: Icons.workspace_premium,
            title: "Premium Program",
            subtitle: "Get a program designed just for you",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PremiumProgramScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          _buildLogoutTile(),
        ],
      ),
    );
  }

  // ================= UI HELPERS =================

  Widget _buildAccountHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            child: Icon(Icons.person, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName ?? "",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userEmail ?? "",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: enabled ? const Icon(Icons.chevron_right) : null,
      onTap: enabled ? onTap : null,
    );
  }

  Widget _buildLogoutTile() {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text(
        "Logout",
        style: TextStyle(color: Colors.red),
      ),
      onTap: () async {
        await AuthService.logout();
        if (!mounted) return;
        setState(() {
          isLoggedIn = false;
          userName = null;
          userEmail = null;
        });
      },
    );
  }

  Widget _buildLoggedOut(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'You are not logged in',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ).then((_) => _loadUser());
            },
            child: const Text("Login or Register"),
          ),
        ],
      ),
    );
  }
}
