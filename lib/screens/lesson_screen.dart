import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:confetti/confetti.dart';
import '../models/entities.dart';
import '../services/study_material_service.dart';
import '../services/tts_service.dart';
import '../widgets/glass_theme.dart';
import '../utils/json_utils.dart';
import 'quiz_screen.dart';

class LessonScreen extends StatefulWidget {
  final GeneratedStudyMaterial material;
  final StudyMaterialService materialService;
  final int lessonIndex;

  const LessonScreen({
    super.key,
    required this.material,
    required this.materialService,
    required this.lessonIndex,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late int _index = widget.lessonIndex;
  late ConfettiController _confetti;
  late final TtsService _tts = TtsService();

  Map<String, dynamic>? _lesson;
  bool _generatingBody = false;
  bool _generatingQuiz = false;
  bool _isSpeaking = false;
  String? _generationError;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _loadLesson();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleNarration() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
    } else {
      final body = (_lesson?['body'] as String? ?? '').trim();
      if (body.isEmpty) return;
      
      setState(() => _isSpeaking = true);
      // Strip markdown for cleaner TTS
      final cleanText = body.replaceAll(RegExp(r'#+\s*'), '')
                            .replaceAll(RegExp(r'\*+'), '')
                            .replaceAll(RegExp(r'`+'), '');
      await _tts.speak(cleanText);
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _generateQuiz() async {
    if (_lesson == null || _generatingQuiz) return;
    final body = (_lesson!['body'] as String? ?? '').trim();
    if (body.isEmpty) return;

    setState(() => _generatingQuiz = true);
    try {
      final quiz = await widget.materialService.generateLessonQuiz(
        category: widget.material.category.target!,
        lessonTitle: _lesson!['title'],
        lessonBody: body,
      );
      
      if (!mounted) return;
      setState(() => _generatingQuiz = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            material: quiz,
            materialService: widget.materialService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingQuiz = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate quiz: $e')),
      );
    }
  }

  Map<String, dynamic> _readData() =>
      jsonDecode(JsonUtils.extractAndCleanJson(widget.material.contentJson)) as Map<String, dynamic>;

  List<Map<String, dynamic>> _readLessons() =>
      (_readData()['lessons'] as List).cast<Map<String, dynamic>>();

  Future<void> _loadLesson({bool force = false}) async {
    final lessons = _readLessons();
    if (_index < 0 || _index >= lessons.length) return;
    var lesson = lessons[_index];
    
    final body = (lesson['body'] as String? ?? '').trim();
    if (!force && body.isNotEmpty) {
      setState(() {
        _lesson = lesson;
        _generationError = null;
      });
      return;
    }

    setState(() {
      _lesson = lesson;
      _generatingBody = true;
      _generationError = null;
      // Clear body if forcing
      if (force) _lesson!['body'] = '';
    });

    try {
      final stream = widget.materialService.generateLessonBodyStream(
        workshop: widget.material,
        lessonIndex: _index,
      );

      await for (final updatedLesson in stream) {
        if (!mounted || _index != updatedLesson['index']) break;
        setState(() {
          _lesson = updatedLesson;
        });
      }

      if (mounted) setState(() => _generatingBody = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generatingBody = false;
        _generationError = 'Could not generate this lesson: $e';
      });
    }
  }

  Future<void> _markCompleteAndAdvance() async {
    final newBadges = widget.materialService.markLessonComplete(
      workshop: widget.material,
      lessonIndex: _index,
    );
    if (newBadges.isNotEmpty) {
      _confetti.play();
      await _showBadges(newBadges);
    }
    if (!mounted) return;

    final lessons = _readLessons();
    if (_index + 1 < lessons.length) {
      // Auto-advance to next lesson within the same screen.
      setState(() {
        _index = _index + 1;
        _lesson = null;
      });
      // Mark "opened" for the new lesson — may award badges too.
      final more = widget.materialService.noteLessonOpened(
        workshop: widget.material,
        lessonIndex: _index,
      );
      if (more.isNotEmpty) {
        _confetti.play();
        await _showBadges(more);
      }
      _loadLesson();
    } else {
      // Last lesson — pop back to overview.
      Navigator.of(context).pop();
    }
  }

  Future<void> _showBadges(List<Badge> badges) async {
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
                          color: Colors.white.withOpacity(0.30),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.workspace_premium,
                            size: 56,
                            color: Colors.white,
                          ),
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
                      backgroundColor: GlassTheme.accentBlue.withOpacity(0.18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: GlassTheme.accentBlue.withOpacity(0.55),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Continue',
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
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final lessons = _readLessons();
    final total = lessons.length;
    final isCompleted = lesson?['completed'] == true;

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
                    title: Text(
                      'Lesson ${_index + 1} of $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.06),
                    elevation: 0,
                    iconTheme: const IconThemeData(color: Colors.white),
                    actions: [
                      if (!_generatingBody && _lesson != null && (_lesson!['body'] as String? ?? '').isNotEmpty)
                        IconButton(
                          onPressed: _toggleNarration,
                          icon: Icon(
                            _isSpeaking ? Icons.stop_circle_rounded : Icons.play_circle_outline_rounded,
                            color: _isSpeaking ? GlassTheme.danger : Colors.white,
                          ),
                          tooltip: 'Listen to lesson',
                        ),
                      if (!_generatingBody)
                        IconButton(
                          onPressed: () => _loadLesson(force: true),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          tooltip: 'Regenerate lesson',
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
            body: lesson == null
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        GlassTheme.accentBlue,
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                      16,
                      MediaQuery.of(context).padding.bottom + 100,
                    ),
                    children: [
                      _buildHeader(lesson),
                      const SizedBox(height: 14),
                      if (_generatingBody)
                        _buildGeneratingState()
                      else if (_generationError != null)
                        _buildErrorState()
                      else ...[
                        _buildBody(lesson),
                        const SizedBox(height: 16),
                        _buildQuizAction(),
                      ],
                    ],
                  ),
            bottomNavigationBar: lesson == null
                ? null
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PrimaryAction(
                              icon: isCompleted
                                  ? Icons.east_rounded
                                  : Icons.check_rounded,
                              label: isCompleted
                                  ? (_index + 1 < total
                                        ? 'Next lesson'
                                        : 'Back to workshop')
                                  : (_index + 1 < total
                                        ? 'Mark complete · Next'
                                        : 'Finish workshop'),
                              accent: isCompleted
                                  ? GlassTheme.accentBlue
                                  : GlassTheme.success,
                              onTap: _generatingBody
                                  ? null
                                  : _markCompleteAndAdvance,
                            ),
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildHeader(Map<String, dynamic> lesson) {
    final keyPoints = (lesson['keyPoints'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final estimated = lesson['estimatedMinutes'] ?? 8;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: GlassTheme.panel(radius: 22, strong: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentBlue.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: GlassTheme.accentBlue.withOpacity(0.55),
                      ),
                    ),
                    child: Text(
                      'LESSON ${_index + 1}',
                      style: const TextStyle(
                        color: GlassTheme.accentBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: Colors.white.withOpacity(0.55),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$estimated min',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lesson['title'] ?? 'Lesson',
                style: const TextStyle(
                  color: GlassTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if ((lesson['summary'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  lesson['summary'],
                  style: const TextStyle(
                    color: GlassTheme.textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
              if (keyPoints.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'KEY POINTS',
                  style: TextStyle(
                    color: GlassTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                ...keyPoints.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 7, right: 8),
                          child: Icon(
                            Icons.circle,
                            color: GlassTheme.accentBlue,
                            size: 6,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            p,
                            style: const TextStyle(
                              color: GlassTheme.textPrimary,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: GlassTheme.panel(radius: 22),
      child: const Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(GlassTheme.accentBlue),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Writing this lesson...',
            style: TextStyle(
              color: GlassTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Pulled from your subject\'s documents.',
            style: TextStyle(color: GlassTheme.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: GlassTheme.panel(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: GlassTheme.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Generation failed',
                style: TextStyle(
                  color: GlassTheme.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _generationError ?? 'Unknown error',
            style: const TextStyle(
              color: GlassTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _loadLesson,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: TextButton.styleFrom(foregroundColor: GlassTheme.accentBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> lesson) {
    final body = (lesson['body'] as String? ?? '').trim();
    if (body.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: GlassTheme.panel(radius: 22),
        child: const Text(
          'No content yet.',
          style: TextStyle(color: GlassTheme.textTertiary),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: GlassTheme.panel(radius: 22),
          child: MarkdownBody(
            data: body,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 15,
                height: 1.55,
              ),
              h1: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
              h2: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
              h3: const TextStyle(
                color: GlassTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              listBullet: const TextStyle(
                color: GlassTheme.accentBlue,
                fontSize: 15,
              ),
              code: TextStyle(
                color: GlassTheme.accentCyan,
                backgroundColor: Colors.white.withOpacity(0.06),
                fontFamily: 'monospace',
                fontSize: 13.5,
              ),
              codeblockDecoration: BoxDecoration(
                color: Colors.black.withOpacity(0.30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GlassTheme.borderSubtle),
              ),
              codeblockPadding: const EdgeInsets.all(12),
              blockquoteDecoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(
                    color: GlassTheme.accentBlue.withOpacity(0.6),
                    width: 3,
                  ),
                ),
              ),
              blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              strong: const TextStyle(
                color: GlassTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              em: const TextStyle(
                color: GlassTheme.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: GlassTheme.panel(radius: 22),
      child: Column(
        children: [
          const Icon(
            Icons.quiz_outlined,
            color: GlassTheme.accentBlue,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'Check Your Understanding',
            style: TextStyle(
              color: GlassTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Test your knowledge of this lesson with a quick 5-question AI quiz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          _generatingQuiz
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(GlassTheme.accentBlue),
                )
              : _PrimaryAction(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Generate Lesson Quiz',
                  accent: GlassTheme.accentBlue,
                  onTap: _generateQuiz,
                ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withOpacity(disabled ? 0.18 : 0.45),
                accent.withOpacity(disabled ? 0.08 : 0.22),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withOpacity(disabled ? 0.30 : 0.65),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      fontSize: 14.5,
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
