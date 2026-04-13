import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class WorkoutReminderScreen extends StatefulWidget {
  const WorkoutReminderScreen({super.key});

  @override
  State<WorkoutReminderScreen> createState() =>
      _WorkoutReminderScreenState();
}

class _WorkoutReminderScreenState
    extends State<WorkoutReminderScreen> {
  static const _prefsKey = 'workout_reminders';

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  final List<bool> _days = List.filled(7, false);
  final List<String> _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];
  final List<int> _dayWeekday = [1, 2, 3, 4, 5, 6, 7];

  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  String _message = "Time to crush your workout! 💪";
  bool _enabled = false;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Johannesburg'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(
      settings: initSettings,
    );

    // 🔥 CREATE CHANNEL MANUALLY (THIS IS THE FIX)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'workout_reminders',
      'Workout Reminders',
      description: 'Weekly workout reminder notifications',
      importance: Importance.high,
    );

    final android = _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(channel);

    // iOS permissions
    await _notifications
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+
    await android?.requestNotificationsPermission();

    await _load();

    if (mounted) setState(() => _initialised = true);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    final map = jsonDecode(raw) as Map<String, dynamic>;

    _enabled = map['enabled'] as bool? ?? false;

    _time = TimeOfDay(
      hour: map['hour'] as int? ?? 7,
      minute: map['minute'] as int? ?? 0,
    );

    _message = map['message'] as String? ?? _message;

    final days = map['days'] as List<dynamic>? ?? [];
    for (int i = 0; i < 7; i++) {
      _days[i] = i < days.length ? days[i] as bool : false;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'enabled': _enabled,
        'hour': _time.hour,
        'minute': _time.minute,
        'message': _message,
        'days': _days,
      }),
    );
  }

  Future<void> _scheduleAll() async {
    // Cancel old notifications
    for (int i = 0; i < 7; i++) {
      await _notifications.cancel(id: 100 + i);
    }

    if (!_enabled) return;

    const notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'workout_reminders',
        'Workout Reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < 7; i++) {
      if (!_days[i]) continue;

      final weekday = _dayWeekday[i];

      // Build next occurrence of selected weekday + time
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        _time.hour,
        _time.minute,
      );

      // Move forward until correct weekday and future time
      while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _notifications.zonedSchedule(
        id: 100 + i, // UNIQUE per day
        title: 'Workout Reminder',
        body: _message,
        scheduledDate: scheduled,
        notificationDetails: notifDetails,

        // 🔥 CRITICAL FIX (no exact alarms)
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

        // 🔥 THIS MAKES IT REPEAT WEEKLY
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );

    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _editMessage() async {
    final controller =
    TextEditingController(text: _message);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reminder message'),
        content: TextField(
          controller: controller,
          maxLength: 80,
          decoration: const InputDecoration(
              hintText: 'Enter your message...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _message = result);
    }
  }

  Future<void> _apply() async {
    await _save();
    await _scheduleAll();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            _enabled ? 'Reminders saved ✓' : 'Reminders disabled'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _formattedTime {
    final h = _time.hourOfPeriod == 0
        ? 12
        : _time.hourOfPeriod;
    final m =
    _time.minute.toString().padLeft(2, '0');
    final period =
    _time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialised) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final anyDaySelected = _days.any((d) => d);

    return Scaffold(
      appBar:
      AppBar(title: const Text('Workout Reminders')),
      body: ListView(
        padding:
        const EdgeInsets.symmetric(vertical: 12),
        children: [
          SwitchListTile(
            secondary: Icon(
              Icons.notifications_active,
              color: _enabled ? scheme.primary : null,
            ),
            title: const Text('Enable reminders'),
            subtitle: const Text(
                'Get notified on your chosen days'),
            value: _enabled,
            onChanged: (v) =>
                setState(() => _enabled = v),
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, 8),
            child: Text(
              'REPEAT ON',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final selected = _days[i];
                return ChoiceChip(
                  label: Text(_dayLabels[i]),
                  selected: selected,
                  onSelected: _enabled
                      ? (v) =>
                      setState(() => _days[i] = v)
                      : null,
                  selectedColor: scheme.primary,
                  labelStyle: TextStyle(
                    color: selected
                        ? scheme.onPrimary
                        : null,
                    fontWeight: selected
                        ? FontWeight.bold
                        : null,
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, 8),
            child: Text(
              'TIME',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          ListTile(
            enabled: _enabled,
            leading: const Icon(Icons.access_time),
            title: const Text('Reminder time'),
            trailing: GestureDetector(
              onTap: _enabled ? _pickTime : null,
              child: Container(
                padding:
                const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _enabled
                      ? scheme.primaryContainer
                      : scheme
                      .surfaceContainerHighest,
                  borderRadius:
                  BorderRadius.circular(20),
                ),
                child: Text(
                  _formattedTime,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _enabled
                        ? scheme.onPrimaryContainer
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            onTap: _enabled ? _pickTime : null,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, 8),
            child: Text(
              'MESSAGE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          ListTile(
            enabled: _enabled,
            leading:
            const Icon(Icons.edit_notifications),
            title:
            const Text('Notification text'),
            subtitle: Text(
              _message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing:
            const Icon(Icons.chevron_right),
            onTap: _enabled ? _editMessage : null,
          ),

          const SizedBox(height: 32),

          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton.icon(
              onPressed:
              (_enabled && !anyDaySelected)
                  ? null
                  : _apply,
              icon: const Icon(Icons.check),
              label:
              const Text('Save reminders'),
              style: FilledButton.styleFrom(
                minimumSize:
                const Size.fromHeight(48),
              ),
            ),
          ),

          if (_enabled && !anyDaySelected)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Select at least one day to save',
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 13),
                ),
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}