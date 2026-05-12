import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/programs.dart';
import '../services/program_service.dart';
import 'week_day_selector_screen.dart';
import '../utils/user_prefs.dart';

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

  @override
  void initState() {
    super.initState();
    _programsFuture = fetchPrograms();
    _loadActiveProgramId();
  }

  Future<void> _loadActiveProgramId() async {
    final id = await UserPrefs.getInt('active_program_id');
    if (!mounted) return;
    setState(() {
      _activeProgramId = id;
    });
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
    setState(() {
      _programsFuture = fetchPrograms();
    });
    await _loadActiveProgramId();
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

        final filteredPrograms = programs.where((p) {
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
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? cs.onPrimary : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isActive
              ? BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            Image.network(
              program.imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: Colors.grey.shade300,
                child: const Icon(Icons.image, size: 50),
              ),
            ),
            Container(
              height: 180,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                program.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
            ),
            if (isActive)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}