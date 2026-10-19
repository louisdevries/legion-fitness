import 'package:flutter/material.dart';
import '../models/programs.dart';
import '../models/local_custom_program.dart';
import '../services/program_service.dart';
import '../services/local_program_service.dart';
import 'week_day_selector_screen.dart';
import 'custom_exercise_screen.dart';
import 'exercise_preview_screen.dart';
import '../utils/user_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

enum _GenderFilter { men, women }

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  Future<List<Program>>? _programsFuture;
  int? _activeProgramId;
  _GenderFilter _filter = _GenderFilter.men;
  bool _filterInitialised = false;
  List<LocalCustomProgram> _customPrograms = [];

  @override
  void initState() {
    super.initState();
    _programsFuture = fetchPrograms();
    _loadActiveProgramId();
    _loadCustomPrograms();
  }

  Future<void> _loadActiveProgramId() async {
    final id = await UserPrefs.getInt('active_program_id');
    if (!mounted) return;
    setState(() {
      _activeProgramId = id;
    });
  }

  Future<void> _loadCustomPrograms() async {
    final programs = await LocalProgramService.loadAll();
    if (!mounted) return;
    setState(() => _customPrograms = programs);
  }

  /// Pick a sensible default filter once programs are loaded:
  /// if the active program is a women's program, default to Women; else Men.
  void _initialiseFilterIfNeeded(List<Program> programs) {
    if (_filterInitialised) return;
    _filterInitialised = true;

    if (_activeProgramId != null) {
      final active = programs.where((p) => p.id == _activeProgramId).toList();
      if (active.isNotEmpty && active.first.isForWomen && !active.first.isForMen) {
        _filter = _GenderFilter.women;
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _programsFuture = fetchPrograms());
    await Future.wait([_loadActiveProgramId(), _loadCustomPrograms()]);
  }

  Future<void> _deleteCustomProgram(LocalCustomProgram program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete program?'),
        content: Text('"${program.name}" will be removed from your device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: AppColors.of(context).warning)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LocalProgramService.delete(program.id);
    await _loadCustomPrograms();
  }

  void _showCustomProgramDetail(LocalCustomProgram program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomProgramDetailSheet(
        program: program,
        onDelete: () {
          Navigator.pop(ctx);
          _deleteCustomProgram(program);
        },
        onSessionComplete: (week, day) async {
          await LocalProgramService.markSessionComplete(program.id, week, day);
          await _loadCustomPrograms();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Program>>(
      future: _programsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final programs = snapshot.data!;
        _initialiseFilterIfNeeded(programs);

        final activeProgram = _activeProgramId == null
            ? null
            : programs.where((p) => p.id == _activeProgramId).firstOrNull;

        final premiumPrograms = programs.where((p) => p.isPremium).toList();

        final filteredPrograms = programs.where((p) {
          if (p.isPremium) return false; // shown separately
          if (_filter == _GenderFilter.men) return p.isForMen;
          return p.isForWomen;
        }).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (activeProgram != null) ...[
                _SectionHeader(text: 'Active Program'),
                const SizedBox(height: 12),
                _ProgramCard(
                  program: activeProgram,
                  isActive: true,
                  onTap: () => _openProgram(activeProgram),
                ),
                const SizedBox(height: 24),
              ],

              // ── Custom Programs ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _SectionHeader(text: 'Custom Programs'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomExerciseScreen(),
                        ),
                      );
                      _loadCustomPrograms();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_customPrograms.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'No custom programs yet. Tap New to create one.',
                    style: TextStyle(color: AppColors.of(context).muted),
                  ),
                )
              else
                ...List.generate(_customPrograms.length, (i) {
                  final cp = _customPrograms[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _CustomProgramCard(
                      program: cp,
                      onTap: () => _showCustomProgramDetail(cp),
                      onDelete: () => _deleteCustomProgram(cp),
                    ),
                  );
                }),

              // ── Premium Programs ─────────────────────────────────
              if (premiumPrograms.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionHeader(text: 'My Premium Plans'),
                const SizedBox(height: 12),
                ...premiumPrograms.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ProgramCard(
                      program: p,
                      isActive: p.id == _activeProgramId,
                      onTap: () => _openProgram(p),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 8),
              _GenderFilterButtons(
                selected: _filter,
                onChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 16),

              if (filteredPrograms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      _filter == _GenderFilter.men
                          ? 'No programs for men yet'
                          : 'No programs for women yet',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              else
                ...filteredPrograms.map(
                      (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ProgramCard(
                      program: p,
                      isActive: p.id == _activeProgramId,
                      onTap: () => _openProgram(p),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openProgram(Program p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeekDaySelectorScreen(programId: p.id),
      ),
    );
    // After returning from the WeekDaySelectorScreen, the active program
    // may have changed (user pressed "Start Program"). Re-read it.
    if (mounted) _loadActiveProgramId();
  }
}

// =====================================================================
// Section header
// =====================================================================

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) => AppSectionTitle(text);
}

// =====================================================================
// Gender filter buttons
// =====================================================================

class _GenderFilterButtons extends StatelessWidget {
  final _GenderFilter selected;
  final ValueChanged<_GenderFilter> onChanged;

  const _GenderFilterButtons({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilterPill(
            label: 'Men',
            isSelected: selected == _GenderFilter.men,
            onTap: () => onChanged(_GenderFilter.men),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FilterPill(
            label: 'Women',
            isSelected: selected == _GenderFilter.women,
            onTap: () => onChanged(_GenderFilter.women),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? c.accent : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: isSelected ? c.accent : c.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isSelected ? c.onAccent : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Custom program card (local, no image)
// =====================================================================

class _CustomProgramCard extends StatelessWidget {
  final LocalCustomProgram program;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CustomProgramCard({
    required this.program,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final totalSessions = program.weeks * program.daysPerWeek;
    final doneSessions = program.completedSessions.length;
    final progress = totalSessions > 0 ? doneSessions / totalSessions : 0.0;
    final nextLabel = program.isComplete
        ? 'Complete'
        : 'Next: Week ${program.nextWeek} · Day ${program.nextDay}';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
      child: Row(
        children: [
          const AppIconBadge(Icons.fitness_center, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${program.weeks} wks · ${program.daysPerWeek} days/wk · ${program.totalExercises} exercises',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                AppProgressBar(progress, height: 5),
                const SizedBox(height: 6),
                Text(
                  nextLabel,
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.muted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Custom program week/day detail sheet
// =====================================================================

class _CustomProgramDetailSheet extends StatefulWidget {
  final LocalCustomProgram program;
  final VoidCallback onDelete;
  final Future<void> Function(int week, int day) onSessionComplete;

  const _CustomProgramDetailSheet({
    required this.program,
    required this.onDelete,
    required this.onSessionComplete,
  });

  @override
  State<_CustomProgramDetailSheet> createState() =>
      _CustomProgramDetailSheetState();
}

class _CustomProgramDetailSheetState
    extends State<_CustomProgramDetailSheet> {
  late int _selectedWeek;

  @override
  void initState() {
    super.initState();
    _selectedWeek = widget.program.nextWeek;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final p = widget.program;
    Widget heading(String text) => Text(text, style: appDisplay(context, 22));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          // ── Handle ──
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: appDisplay(context, 28)),
                      const SizedBox(height: 2),
                      Text(
                        '${p.weeks} weeks · ${p.daysPerWeek} days/week · ${p.totalExercises} exercises',
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: c.warning),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // ── Week selector ──
                heading('Select week'),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: p.weeks,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemBuilder: (_, i) {
                    final week = i + 1;
                    final selected = week == _selectedWeek;
                    // Week is locked if the previous week isn't fully done
                    final locked = week > 1 &&
                        !p.isDayLocked(week, 1) == false &&
                        (week > 1 &&
                            !List.generate(p.daysPerWeek, (d) => d + 1)
                                .every((d) => p.isDone(week - 1, d)));
                    return GestureDetector(
                      onTap: locked
                          ? null
                          : () => setState(() => _selectedWeek = week),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? c.accent
                              : locked
                                  ? c.track
                                  : c.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? c.accent : c.cardBorder,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Wk $week',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: selected
                                  ? c.onAccent
                                  : locked
                                      ? c.muted
                                      : cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
                heading('Select day'),
                const SizedBox(height: 10),

                // ── Day list ──
                ...List.generate(p.daysPerWeek, (i) {
                  final day = i + 1;
                  final done = p.isDone(_selectedWeek, day);
                  final locked = p.isDayLocked(_selectedWeek, day);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: locked ? c.track : c.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: done
                              ? c.accent.withValues(alpha: 0.6)
                              : c.cardBorder),
                    ),
                    child: ListTile(
                      title: Text('Day $day',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: locked ? c.muted : null,
                          )),
                      subtitle: Text(
                        '${p.totalExercises} exercises',
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ),
                      trailing: done
                          ? Icon(Icons.check_circle, color: c.accentText)
                          : locked
                              ? Icon(Icons.lock_outline, color: c.muted)
                              : Icon(Icons.arrow_forward_ios,
                                  size: 16, color: c.muted),
                      onTap: locked
                          ? null
                          : () => _startWorkout(_selectedWeek, day),
                    ),
                  );
                }),

                const SizedBox(height: 16),
                // ── Exercise list ──
                heading('Exercises in this workout'),
                const SizedBox(height: 8),
                if (p.warmup.isNotEmpty) ...[
                  _sectionLabel('Warm-up'),
                  ..._exerciseRows(p.warmup),
                ],
                if (p.main.isNotEmpty) ...[
                  _sectionLabel('Main'),
                  ..._exerciseRows(p.main),
                ],
                if (p.cooldown.isNotEmpty) ...[
                  _sectionLabel('Cooldown'),
                  ..._exerciseRows(p.cooldown),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkout(int week, int day) async {
    Navigator.pop(context); // close the sheet
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExercisePreviewScreen(
          exercises: widget.program.toExerciseMaps(),
          programId: 0,
          weekNumber: week,
          dayNumber: day,
        ),
      ),
    );
    // Mark this session complete after the user returns from the runner.
    await widget.onSessionComplete(week, day);
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
                color: AppColors.of(context).muted)),
      );

  List<Widget> _exerciseRows(List<LocalExerciseEntry> entries) =>
      entries
          .map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(e.exerciseName),
                subtitle: Text(
                    '${e.sets} sets · ${e.minQuantity}–${e.maxQuantity} ${e.durationType}'),
              ))
          .toList();
}

// =====================================================================
// Program card
// =====================================================================

class _ProgramCard extends StatelessWidget {
  final Program program;
  final bool isActive;
  final VoidCallback onTap;

  const _ProgramCard({
    required this.program,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isActive
              ? BorderSide(color: c.accent, width: 2)
              : BorderSide(color: c.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                program.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: c.track,
                  child: Icon(Icons.fitness_center, size: 44, color: c.muted),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  program.name,
                  style: appDisplay(context, 28, color: Colors.white).copyWith(
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
            if (isActive)
              const Positioned(
                top: 12,
                right: 12,
                child: AppPill('ACTIVE', icon: Icons.check_circle, filled: true),
              ),
          ],
        ),
      ),
    );
  }
}