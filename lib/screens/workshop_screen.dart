import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart' hide Badge;
import 'package:confetti/confetti.dart';
import '../models/entities.dart';
import '../services/study_material_service.dart';
import '../widgets/glass_theme.dart';
import '../utils/json_utils.dart';
import 'lesson_screen.dart';

/// Overview of a generated workshop: title, description, progress and the
/// full lesson list.
class WorkshopScreen extends StatefulWidget {
  final GeneratedStudyMaterial material;
  final StudyMaterialService materialService;

  const WorkshopScreen({
    super.key,
    required this.material,
    required this.materialService,
  });

  @override
  State<WorkshopScreen> createState() => _WorkshopScreenState();
}

class _WorkshopScreenState extends State<WorkshopScreen> {
  late Map<String, dynamic> _data;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _data = jsonDecode(JsonUtils.extractAndCleanJson(widget.material.contentJson)) as Map<String, dynamic>;
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _refreshFromBox() {
    setState(() {
      _data = jsonDecode(JsonUtils.extractAndCleanJson(widget.material.contentJson)) as Map<String, dynamic>;
    });
  }

  List<Map<String, dynamic>> get _lessons =>
      (_data['lessons'] as List).cast<Map<String, dynamic>>();

  int get _completedCount =>
      _lessons.where((l) => l['completed'] == true).length;

  double get _progress =>
      _lessons.isEmpty ? 0 : _completedCount / _lessons.length;

  int get _nextLessonIndex {
    for (var i = 0; i < _lessons.length; i++) {
      if (_lessons[i]['completed'] != true) return i;
    }
    return 0;
  }

  Future<void> _openLesson(int index) async {
    // Note opening + maybe award "started" badge
    final newBadges = widget.materialService.noteLessonOpened(
      workshop: widget.material,
      lessonIndex: index,
    );
    if (newBadges.isNotEmpty && mounted) {
      _showBadgeOverlay(newBadges);
    }
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonScreen(
          material: widget.material,
          materialService: widget.materialService,
          lessonIndex: index,
        ),
      ),
    );
    _refreshFromBox();
  }

  Future<void> _showBadgeOverlay(List<Badge> badges) async {
    _confetti.play();
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: GlassTheme.panel(radius: 24, strong: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final b in badges) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD27A), Color(0xFFE89436)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.30)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.workspace_premium,
                              size: 56, color: Colors.white),
                          const SizedBox(height: 8),
                          Text(
                            b.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            b.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: GlassTheme.accentBlue,
                      backgroundColor:
                          GlassTheme.accentBlue.withOpacity(0.18),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                            color:
                                GlassTheme.accentBlue.withOpacity(0.55)),
                      ),
                    ),
                    child: const Text(
                      'Nice!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _refreshFromBox();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: AppBar(
                    title: const Text(
                      'Workshop',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.06),
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                ),
              ),
            ),
            body: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                16,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              children: [
                _buildHero(),
                const SizedBox(height: 16),
                _buildLessonList(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                GlassTheme.accentBlue,
                GlassTheme.accentPurple,
                GlassTheme.accentCyan,
                GlassTheme.success,
                GlassTheme.warning,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final title = _data['title'] ?? 'Workshop';
    final description = _data['description'] ?? '';
    final depth = _data['depth'] ?? 'Intermediate';
    final percent = (_progress * 100).round();
    final startedAt = _data['startedAt'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                GlassTheme.surfaceBase.withOpacity(0.78),
                const Color(0xFF24365C).withOpacity(0.78),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: GlassTheme.border),
            boxShadow: [
              BoxShadow(
                color: GlassTheme.accentBlue.withOpacity(0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentBlue.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: GlassTheme.accentBlue.withOpacity(0.55)),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: GlassTheme.accentBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentPurple.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: GlassTheme.accentPurple.withOpacity(0.55)),
                    ),
                    child: Text(
                      depth.toString().toUpperCase(),
                      style: const TextStyle(
                        color: GlassTheme.accentPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: GlassTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  color: GlassTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        backgroundColor: Colors.white.withOpacity(0.10),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            GlassTheme.accentBlue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: GlassTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$_completedCount of ${_lessons.length} lessons complete',
                style: const TextStyle(
                  color: GlassTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryAction(
                      icon: startedAt == null
                          ? Icons.play_arrow_rounded
                          : (_completedCount == _lessons.length
                              ? Icons.refresh_rounded
                              : Icons.east_rounded),
                      label: startedAt == null
                          ? 'Start Lesson 1'
                          : (_completedCount == _lessons.length
                              ? 'Review from Lesson 1'
                              : 'Continue · Lesson ${_nextLessonIndex + 1}'),
                      accent: GlassTheme.accentBlue,
                      onTap: () {
                        final target = _completedCount == _lessons.length
                            ? 0
                            : _nextLessonIndex;
                        _openLesson(target);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonList() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: GlassTheme.panel(radius: 22),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Text(
                  'Lessons',
                  style: TextStyle(
                    color: GlassTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (var i = 0; i < _lessons.length; i++)
                _buildLessonRow(i, _lessons[i]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonRow(int index, Map<String, dynamic> lesson) {
    final completed = lesson['completed'] == true;
    final title = lesson['title'] ?? 'Lesson ${index + 1}';
    final summary = lesson['summary'] ?? '';
    final estimatedMinutes = lesson['estimatedMinutes'] ?? 8;
    final isNext = !completed && index == _nextLessonIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openLesson(index),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LessonStatusIcon(
                completed: completed,
                index: index,
                isNext: isNext,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: completed
                                  ? GlassTheme.textTertiary
                                  : GlassTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              decoration: completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: GlassTheme.textTertiary,
                            ),
                          ),
                        ),
                        if (isNext)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  GlassTheme.accentBlue.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: GlassTheme.accentBlue
                                      .withOpacity(0.55)),
                            ),
                            child: const Text(
                              'NEXT',
                              style: TextStyle(
                                color: GlassTheme.accentBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (summary.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: const TextStyle(
                          color: GlassTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12,
                            color: Colors.white.withOpacity(0.55)),
                        const SizedBox(width: 4),
                        Text(
                          '$estimatedMinutes min',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonStatusIcon extends StatelessWidget {
  final bool completed;
  final int index;
  final bool isNext;

  const _LessonStatusIcon({
    required this.completed,
    required this.index,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white.withOpacity(0.10);
    Color border = GlassTheme.border;
    Widget child = Text(
      '${index + 1}',
      style: const TextStyle(
        color: GlassTheme.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 13,
      ),
    );

    if (completed) {
      bg = GlassTheme.success.withOpacity(0.20);
      border = GlassTheme.success.withOpacity(0.55);
      child = const Icon(Icons.check_rounded,
          color: GlassTheme.success, size: 20);
    } else if (isNext) {
      bg = GlassTheme.accentBlue.withOpacity(0.18);
      border = GlassTheme.accentBlue.withOpacity(0.55);
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Center(child: child),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withOpacity(0.45),
                accent.withOpacity(0.22),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.65)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GlassTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
