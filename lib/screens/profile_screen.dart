import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../main.dart';
import '../screens/health_profile_screen.dart';
import '../screens/premium_program_screen.dart';
import '../screens/workout_reminder_screen.dart';
import 'rest_timer_settings_screen.dart';
import 'achievements_screen.dart';
import '../widgets/xp_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? userName;
  String? userEmail;
  bool isLoggedIn = false;
  bool _googleFitEnabled = false;
  bool _googleFitLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _googleFitEnabled = AppSettings.googleFitEnabled.value;
  }

  Future<void> _loadUser() async {
    final user = AuthService.currentUser;
    final name = await AuthService.getUserName();
    final email = AuthService.getUserEmail();

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
    const ProfileXpSection();
    const SizedBox(height: 24);

    return Scaffold(

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
            onTap: _showChangeEmailDialog,
          ),
          _buildTile(
            icon: Icons.lock,
            title: "Change Password",
            onTap: _showChangePasswordDialog,
          ),

          _buildSectionHeader("Progress"),
          _buildTile(
            icon: Icons.emoji_events,
            title: "Achievements",
            subtitle: "View your unlocked milestones",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AchievementsScreen(),
                ),
              );
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
          _buildGoogleFitTile(),

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

          // ── Workout Reminder ──────────────────────────────────
          _buildTile(
            icon: Icons.notifications_active,
            title: "Workout Reminders",
            subtitle: "Schedule weekly exercise alerts",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkoutReminderScreen(),
                ),
              );
            },
          ),

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

  // ================= GOOGLE FIT =================

  Future<void> _toggleGoogleFit(bool value) async {
    if (_googleFitLoading) return;
    if (!value) {
      await AppSettings.setGoogleFitEnabled(false);
      if (mounted) setState(() => _googleFitEnabled = false);
      return;
    }

    setState(() => _googleFitLoading = true);

    try {
      final health = Health();
      await health.configure();
      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];
      await health.requestAuthorization(types, permissions: permissions);
      final granted = await health.hasPermissions(types, permissions: permissions) ?? false;
      await AppSettings.setGoogleFitEnabled(granted);
      if (mounted) setState(() => _googleFitEnabled = granted);
    } finally {
      if (mounted) setState(() => _googleFitLoading = false);
    }
  }

  // ================= ACCOUNT ACTIONS =================

  Future<void> _showChangePasswordDialog() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ChangeEmailDialog(currentEmail: userEmail),
    );
    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Confirmation sent! Check your new email to confirm the change.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
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

  Widget _buildGoogleFitTile() {
    return ListTile(
      leading: const Icon(Icons.monitor_heart),
      title: const Text("Health Connect"),
      subtitle: Text(
        _googleFitEnabled ? "Connected — syncing daily steps" : "Not connected",
      ),
      trailing: _googleFitLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(
              value: _googleFitEnabled,
              onChanged: _toggleGoogleFit,
            ),
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

// ===============================================================
// Dialog widgets — controllers disposed in State.dispose() so
// they outlive the exit animation and are never used after disposal.
// ===============================================================

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _newVisible = false;
  bool _confirmVisible = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AuthService.changePassword(newPassword: _newCtrl.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newCtrl,
              obscureText: !_newVisible,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _newVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _newVisible = !_newVisible),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: !_confirmVisible,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_confirmVisible
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _confirmVisible = !_confirmVisible),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : ElevatedButton(
                onPressed: _submit,
                child: const Text('Update'),
              ),
      ],
    );
  }
}

class _ChangeEmailDialog extends StatefulWidget {
  final String? currentEmail;
  const _ChangeEmailDialog({this.currentEmail});

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.currentEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newEmail = _emailCtrl.text.trim();
    if (newEmail == widget.currentEmail) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AuthService.changeEmail(newEmail);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'New Email',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          const Text(
            'A confirmation link will be sent to your new email address.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : ElevatedButton(
                onPressed: _submit,
                child: const Text('Update'),
              ),
      ],
    );
  }
}