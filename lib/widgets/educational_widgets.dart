import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import 'package:graphview/GraphView.dart' as gv;

import 'glass_theme.dart';

/// A gamified Quiz widget that renders inline in the chat.
class QuizCard extends StatefulWidget {
  final String subject;
  final List<dynamic> questions;
  final Function(int score, int total) onComplete;

  const QuizCard({
    Key? key,
    required this.subject,
    required this.questions,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  int _currentIndex = 0;
  int _score = 0;
  bool _showExplanation = false;
  String? _selectedOption;

  void _next() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _showExplanation = false;
        _selectedOption = null;
      });
    } else {
      widget.onComplete(_score, widget.questions.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return _GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No questions found in this quiz.',
            style: TextStyle(color: GlassTheme.textPrimary, fontSize: 15),
          ),
        ),
      );
    }
    final q = widget.questions[_currentIndex];
    final options =
        (q['options'] as List? ?? []).map((e) => e.toString()).toList();
    final questionText = q['question']?.toString() ?? 'No Question';
    final correctAnswer = q['correct_answer']?.toString();
    final explanation = q['explanation']?.toString() ?? "Correct!";
    final progress = (_currentIndex + 1) / widget.questions.length;

    return _GlassPanel(
      strong: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: subject pill + question counter pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Pill(
                  label: 'Quiz · ${widget.subject}',
                  accent: GlassTheme.accentBlue,
                ),
                _Pill(
                  label: 'Q${_currentIndex + 1}/${widget.questions.length}',
                  accent: GlassTheme.accentPurple,
                  faint: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    GlassTheme.accentBlue),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              questionText,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: GlassTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ...options.map((opt) {
              final isCorrect = opt == correctAnswer;
              final isSelected = _selectedOption == opt;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: _OptionTile(
                  label: opt,
                  isSelected: isSelected,
                  isCorrect: isCorrect,
                  showResult: _showExplanation,
                  onTap: _showExplanation
                      ? null
                      : () {
                          setState(() {
                            _selectedOption = opt;
                            _showExplanation = true;
                            if (opt == correctAnswer) _score++;
                          });
                        },
                ),
              );
            }),
            if (_showExplanation) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GlassTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _selectedOption == correctAnswer
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 18,
                          color: _selectedOption == correctAnswer
                              ? GlassTheme.success
                              : GlassTheme.danger,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedOption == correctAnswer
                              ? 'Correct!'
                              : 'Incorrect',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _selectedOption == correctAnswer
                                ? GlassTheme.success
                                : GlassTheme.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      explanation,
                      style: const TextStyle(
                        fontSize: 14,
                        color: GlassTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _next,
                  style: TextButton.styleFrom(
                    foregroundColor: GlassTheme.accentBlue,
                    backgroundColor:
                        GlassTheme.accentBlue.withOpacity(0.18),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                          color: GlassTheme.accentBlue.withOpacity(0.55)),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    _currentIndex == widget.questions.length - 1
                        ? 'Finish Quiz'
                        : 'Next Question',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isCorrect;
  final bool showResult;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.label,
    required this.isSelected,
    required this.isCorrect,
    required this.showResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white.withOpacity(0.06);
    Color border = GlassTheme.border;
    Color text = GlassTheme.textPrimary;

    if (showResult) {
      if (isCorrect) {
        bg = GlassTheme.success.withOpacity(0.18);
        border = GlassTheme.success.withOpacity(0.65);
      } else if (isSelected) {
        bg = GlassTheme.danger.withOpacity(0.18);
        border = GlassTheme.danger.withOpacity(0.65);
      } else {
        text = GlassTheme.textTertiary;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: text,
                      height: 1.35,
                    ),
                  ),
                ),
                if (showResult && isCorrect)
                  const Icon(Icons.check_rounded,
                      color: GlassTheme.success, size: 18)
                else if (showResult && isSelected)
                  const Icon(Icons.close_rounded,
                      color: GlassTheme.danger, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color accent;
  final bool faint;
  const _Pill({required this.label, required this.accent, this.faint = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(faint ? 0.14 : 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(faint ? 0.40 : 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: accent,
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final bool strong;
  final double radius;
  const _GlassPanel({
    required this.child,
    this.strong = false,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: GlassTheme.panel(radius: radius, strong: strong),
          child: child,
        ),
      ),
    );
  }
}

/// A visual Achievement badge widget.
class BadgeCard extends StatefulWidget {
  final String badgeName;
  final String reason;

  const BadgeCard({Key? key, required this.badgeName, required this.reason})
      : super(key: key);

  @override
  State<BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<BadgeCard> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            // Gold → amber. Stays celebratory but reads strongly against the
            // warm pink bg because of the yellow saturation pink lacks.
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD27A), Color(0xFFE89436)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE89436).withOpacity(0.40),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.30)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.40)),
                ),
                child: const Icon(Icons.workspace_premium,
                    size: 48, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'UNLOCKED: ${widget.badgeName.toUpperCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.reason,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
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
      ],
    );
  }
}

/// A simple Pomodoro Focus Timer widget.
class FocusTimerCard extends StatefulWidget {
  final int minutes;
  final String topic;

  const FocusTimerCard({Key? key, required this.minutes, required this.topic})
      : super(key: key);

  @override
  State<FocusTimerCard> createState() => _FocusTimerCardState();
}

class _FocusTimerCardState extends State<FocusTimerCard> {
  late int _secondsRemaining;
  Timer? _timer;
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.minutes * 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0 && _isRunning) {
        setState(() => _secondsRemaining--);
      } else if (_secondsRemaining == 0) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int m = totalSeconds ~/ 60;
    int s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      strong: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined,
                    size: 16, color: GlassTheme.accentBlue),
                const SizedBox(width: 6),
                Text(
                  'Focusing on: ${widget.topic}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: GlassTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _formatTime(_secondsRemaining),
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: GlassTheme.textPrimary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  color: GlassTheme.accentBlue,
                  iconSize: 28,
                  onPressed: () =>
                      setState(() => _isRunning = !_isRunning),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  color: GlassTheme.textTertiary,
                  iconSize: 24,
                  onPressed: () => setState(
                      () => _secondsRemaining = widget.minutes * 60),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FlashcardCarousel extends StatefulWidget {
  final List<dynamic> cards;

  const FlashcardCarousel({super.key, required this.cards});

  @override
  State<FlashcardCarousel> createState() => _FlashcardCarouselState();
}

class _FlashcardCarouselState extends State<FlashcardCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.85);
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Text(
        'No flashcards available.',
        style: TextStyle(color: GlassTheme.textTertiary),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.cards.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final card = widget.cards[index];
              return FlashcardItem(
                question: card['question'] ?? 'No Question',
                answer: card['answer'] ?? 'No Answer',
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.cards.length, (i) {
            final active = i == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? GlassTheme.accentBlue
                    : Colors.white.withOpacity(0.30),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Card ${_currentIndex + 1} of ${widget.cards.length} · tap to flip',
          style: TextStyle(color: GlassTheme.textTertiary, fontSize: 12),
        ),
      ],
    );
  }
}

class FlashcardItem extends StatefulWidget {
  final String question;
  final String answer;

  const FlashcardItem(
      {super.key, required this.question, required this.answer});

  @override
  State<FlashcardItem> createState() => _FlashcardItemState();
}

class _FlashcardItemState extends State<FlashcardItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * 3.14159;
          final isShowingFront = angle < 1.5708;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isShowingFront
                ? _buildCard(
                    widget.question,
                    'QUESTION',
                    GlassTheme.accentBlue,
                  )
                : Transform(
                    transform: Matrix4.identity()..rotateY(3.14159),
                    alignment: Alignment.center,
                    child: _buildCard(
                      widget.answer,
                      'ANSWER',
                      GlassTheme.accentPurple,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCard(String text, String label, Color accent) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withOpacity(0.20),
                  GlassTheme.surfaceBase.withOpacity(0.78),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent.withOpacity(0.45)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withOpacity(0.55)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GlassTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    Icons.touch_app_outlined,
                    color: Colors.white.withOpacity(0.45),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MindMapWidget extends StatefulWidget {
  final Map<String, dynamic> data;

  const MindMapWidget({super.key, required this.data});

  @override
  State<MindMapWidget> createState() => _MindMapWidgetState();
}

class _MindMapWidgetState extends State<MindMapWidget> {
  final gv.Graph graph = gv.Graph();
  final gv.FruchtermanReingoldAlgorithm algorithm =
      gv.FruchtermanReingoldAlgorithm(gv.FruchtermanReingoldConfiguration());

  @override
  void initState() {
    super.initState();
    final List nodesData = widget.data['nodes'] ?? [];
    final List edgesData = widget.data['edges'] ?? [];

    final Map<String, gv.Node> nodeMap = {};

    for (var n in nodesData) {
      final node = gv.Node.Id(n['id']);
      nodeMap[n['id'].toString()] = node;
      graph.addNode(node);
    }

    for (var e in edgesData) {
      final from = nodeMap[e['from'].toString()];
      final to = nodeMap[e['to'].toString()];
      if (from != null && to != null) {
        graph.addEdge(
          from,
          to,
          paint: Paint()
            ..color = GlassTheme.accentBlue.withOpacity(0.55)
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 500,
          width: double.infinity,
          decoration: BoxDecoration(
            color: GlassTheme.surfaceStrong,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: GlassTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(500),
              minScale: 0.01,
              maxScale: 10.0,
              child: gv.GraphView(
                graph: graph,
                algorithm: algorithm,
                paint: Paint()
                  ..color = GlassTheme.accentBlue
                  ..strokeWidth = 2
                  ..style = PaintingStyle.stroke,
                builder: (gv.Node node) {
                  final nodeId = node.key!.value;
                  final nodeData = (widget.data['nodes'] as List).firstWhere(
                      (n) => n['id'].toString() == nodeId.toString(),
                      orElse: () => {'label': '?'});
                  return _buildNodeWidget(nodeData['label']);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeWidget(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GlassTheme.accentBlue.withOpacity(0.85),
            GlassTheme.accentPurple.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: GlassTheme.accentBlue.withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
