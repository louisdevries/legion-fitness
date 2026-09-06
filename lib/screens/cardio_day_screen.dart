import 'package:flutter/material.dart';
import '../services/cardio_day_service.dart';
import 'outdoor_run_screen.dart';

class CardioDayScreen extends StatefulWidget {
  final int programId;
  final int weekNumber;
  final int dayNumber;

  const CardioDayScreen({
    super.key,
    required this.programId,
    required this.weekNumber,
    required this.dayNumber,
  });

  @override
  State<CardioDayScreen> createState() => _CardioDayScreenState();
}

class _CardioDayScreenState extends State<CardioDayScreen> {
  ProgramDay? _day;
  bool _loading = true;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final day = await CardioDayService.fetchDay(
      widget.programId,
      widget.weekNumber,
      widget.dayNumber,
    );
    final completed =
        await CardioDayService.fetchCompletedCardioKeys(widget.programId);
    final key = '${widget.weekNumber}-${widget.dayNumber}';
    if (!mounted) return;
    setState(() {
      _day = day;
      _isCompleted = completed.contains(key);
      _loading = false;
    });
  }

  Future<void> _markManualDone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark cardio done?'),
        content: const Text(
          'Only mark this day complete if you actually did your cardio session outside the app.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mark done')),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await CardioDayService.markManualComplete(
      programId: widget.programId,
      weekNumber: widget.weekNumber,
      dayNumber: widget.dayNumber,
    );
    if (!mounted) return;

    if (ok) {
      setState(() => _isCompleted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cardio day marked complete')),
      );
      Navigator.pop(context, true); // return true so parent can refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already complete or something went wrong')),
      );
    }
  }

  void _openRunTracker() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OutdoorRunScreen()),
    ).then((_) {
      // On return, refresh — the run may have auto-completed this day
      // via CardioDayService.tryAutoCompleteFromRun in RunService.
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Week ${widget.weekNumber} · Day ${widget.dayNumber}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _day == null
              ? const Center(child: Text('Day not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cs.primary,
                              cs.primary.withValues(alpha: 0.7)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.directions_run,
                                size: 40, color: cs.onPrimary),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _day!.title ?? 'Cardio session',
                                    style: TextStyle(
                                      color: cs.onPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_day!.minDurationSeconds != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Target: at least ${(_day!.minDurationSeconds! / 60).round()} min',
                                      style: TextStyle(
                                        color: cs.onPrimary
                                            .withValues(alpha: 0.85),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_isCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'DONE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Notes
                      if (_day!.notes != null && _day!.notes!.isNotEmpty) ...[
                        Text(
                          _day!.notes!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Primary CTA — Start Run
                      SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _openRunTracker,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text(
                            'Start outdoor run',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary — Mark done externally
                      TextButton(
                        onPressed: _isCompleted ? null : _markManualDone,
                        child: Text(
                          _isCompleted
                              ? 'Already marked complete'
                              : 'Did it outside the app? Mark done',
                          style: TextStyle(
                            color: _isCompleted
                                ? cs.onSurface.withValues(alpha: 0.4)
                                : cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}