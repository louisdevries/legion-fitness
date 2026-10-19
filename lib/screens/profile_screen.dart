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
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

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

    void push(Widget screen) => Navigator.push(
        context, MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildAccountHeader(),
          const SizedBox(height: 12),
          const ProfileXpSection(),

          _buildGroup("Account", [
            _buildTile(
              icon: Icons.person_outline,
              title: "Name",
              subtitle: userName ?? "Set your name",
              enabled: false,
            ),
            _buildTile(
              icon: Icons.mail_outline,
              title: "Email",
              subtitle: userEmail ?? "",
              onTap: _showChangeEmailDialog,
            ),
            _buildTile(
              icon: Icons.lock_outline,
              title: "Change password",
              onTap: _showChangePasswordDialog,
            ),
          ]),

          _buildGroup("Progress & health", [
            _buildTile(
              icon: Icons.emoji_events_outlined,
              title: "Achievements",
              subtitle: "View your unlocked milestones",
              onTap: () => push(const AchievementsScreen()),
            ),
            _buildTile(
              icon: Icons.favorite_outline,
              title: "Health profile",
              subtitle: "Weight, height, goals",
              onTap: () => push(const HealthProfileScreen()),
            ),
            _buildGoogleFitTile(),
          ]),

          _buildGroup("Preferences", [
            _buildTile(
              icon: Icons.dark_mode_outlined,
              title: "Appearance",
              subtitle: switch (AppSettings.themeMode.value) {
                ThemeMode.light => "Light",
                ThemeMode.dark => "Dark",
                ThemeMode.system => "Follow system",
              },
              onTap: _pickThemeMode,
            ),
            _buildTile(
              icon: Icons.timer_outlined,
              title: "Rest timer",
              subtitle: "Default rest duration",
              onTap: () => push(const RestTimerSettingsScreen()),
            ),
            _buildTile(
              icon: Icons.notifications_none,
              title: "Workout reminders",
              subtitle: "Schedule weekly exercise alerts",
              onTap: () => push(const WorkoutReminderScreen()),
            ),
          ]),

          _buildGroup("Premium", [
            _buildTile(
              icon: Icons.workspace_premium_outlined,
              iconColor: AppColors.of(context).premium,
              title: "Premium program",
              subtitle: "Get a program designed just for you",
              onTap: () => push(const PremiumProgramScreen()),
            ),
          ]),

          const SizedBox(height: 24),
          _buildLogoutTile(),
        ],
      ),
    );
  }

  Future<void> _pickThemeMode() async {
    final current = AppSettings.themeMode.value;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Appearance', style: appDisplay(ctx, 26)),
              ),
              const SizedBox(height: 8),
              for (final (mode, label) in const [
                (ThemeMode.system, 'Follow system'),
                (ThemeMode.light, 'Light'),
                (ThemeMode.dark, 'Dark'),
              ])
                ListTile(
                  title: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: mode == current
                      ? Icon(Icons.check_circle,
                          color: AppColors.of(ctx).accentText)
                      : null,
                  onTap: () => Navigator.pop(ctx, mode),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await AppSettings.setThemeMode(selected);
      if (mounted) setState(() {});
    }
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
    final c = AppColors.of(context);
    final name = userName?.trim() ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          child: Text(initial, style: appDisplay(context, 30, color: c.onAccent)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Your profile' : name,
                style: appDisplay(context, 30),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                userEmail ?? "",
                style: TextStyle(color: c.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A titled group of settings rows inside one card.
  Widget _buildGroup(String title, List<Widget> tiles) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: c.muted,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 68),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool enabled = true,
    Color? iconColor,
  }) {
    final c = AppColors.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: AppIconBadge(icon, size: 38, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing:
          enabled && onTap != null ? Icon(Icons.chevron_right, color: c.muted) : null,
      onTap: enabled ? onTap : null,
    );
  }

  Widget _buildGoogleFitTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: const AppIconBadge(Icons.monitor_heart_outlined, size: 38),
      title: const Text("Health Connect",
          style: TextStyle(fontWeight: FontWeight.w700)),
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
    final warning = AppColors.of(context).warning;
    return OutlinedButton.icon(
      icon: Icon(Icons.logout, color: warning),
      label: Text("Log out", style: TextStyle(color: warning)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: warning.withValues(alpha: 0.5)),
        minimumSize: const Size.fromHeight(52),
      ),
      onPressed: () async {
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
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconBadge(Icons.person_outline, size: 72, color: c.muted),
            const SizedBox(height: 20),
            Text('You’re not logged in', style: appDisplay(context, 28)),
            const SizedBox(height: 8),
            Text(
              'Log in to save workouts, meals and progress across devices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ).then((_) => _loadUser());
              },
              child: const Text("Log in or register"),
            ),
          ],
        ),
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          Text(
            'A confirmation link will be sent to your new email address.',
            style: TextStyle(fontSize: 12, color: AppColors.of(context).muted),
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