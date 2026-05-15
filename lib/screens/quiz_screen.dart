import 'package:flutter/material.dart' hide Badge;
import '../models/entities.dart';
import '../services/study_material_service.dart';
import '../widgets/educational_widgets.dart';
import '../widgets/glass_theme.dart';
import '../utils/json_utils.dart';
import 'dart:convert';
import 'dart:ui';

class QuizScreen extends StatelessWidget {
  final GeneratedStudyMaterial material;
  final StudyMaterialService materialService;

  const QuizScreen({
    super.key,
    required this.material,
    required this.materialService,
  });

  @override
  Widget build(BuildContext context) {
    // Extract and decode questions
    final data = jsonDecode(JsonUtils.extractAndCleanJson(material.contentJson));
    List<dynamic> questions = [];
    if (data is Map) {
      questions = data['questions'] ?? [];
    } else if (data is List) {
      questions = data;
    }

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: AppBar(
                title: Text(
                  material.title ?? 'Quiz',
                  style: const TextStyle(
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
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + kToolbarHeight + 20,
              16,
              20,
            ),
            child: QuizCard(
              subject: material.category.target?.name ?? 'Lesson',
              questions: questions,
              onComplete: (score, total) {
                _showResults(context, score, total);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showResults(BuildContext context, int score, int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: GlassTheme.panel(radius: 24, strong: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, size: 64, color: Colors.amber),
                  const SizedBox(height: 16),
                  const Text(
                    'Quiz Complete!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You scored $score out of $total',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _PrimaryAction(
                    label: 'Back to Lesson',
                    onTap: () {
                      Navigator.pop(ctx); // Close dialog
                      Navigator.pop(context); // Exit quiz screen
                    },
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

class _PrimaryAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                GlassTheme.accentBlue.withOpacity(0.45),
                GlassTheme.accentBlue.withOpacity(0.22),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GlassTheme.accentBlue.withOpacity(0.65)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
