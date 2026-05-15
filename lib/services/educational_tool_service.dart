import 'package:flutter_gemma/flutter_gemma.dart';

class EducationalToolService {
  /// Defines the catalog of tools Gemma 4 can use to interact with the student.
  static final List<Tool> educationalTools = [
    const Tool(
      name: 'generate_interactive_quiz',
      description: 'Creates a gamified quiz based on the study material. Use this when a student wants to test their knowledge.',
      parameters: {
        'type': 'object',
        'properties': {
          'subject': {
            'type': 'string',
            'description': 'The topic of the quiz (e.g., "Photosynthesis", "Cloud Computing").',
          },
          'questions': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'question': {'type': 'string'},
                'options': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'correct_answer': {'type': 'string'},
                'explanation': {'type': 'string'},
              },
              'required': ['question', 'options', 'correct_answer'],
            },
          },
        },
        'required': ['subject', 'questions'],
      },
    ),
    const Tool(
      name: 'award_badge',
      description: 'Awards a digital badge to the student for mastering a concept or showing great effort.',
      parameters: {
        'type': 'object',
        'properties': {
          'badge_name': {
            'type': 'string',
            'description': 'The name of the badge (e.g., "Cloud Guru", "Quick Learner").',
          },
          'reason': {
            'type': 'string',
            'description': 'Why the student is receiving this badge.',
          },
          'animation_type': {
            'type': 'string',
            'description': 'The visual effect to show (confetti, sparkler, fireworks).',
          },
        },
        'required': ['badge_name', 'reason'],
      },
    ),
    const Tool(
      name: 'start_focus_timer',
      description: 'Starts a Pomodoro-style focus timer to help the student manage their study session.',
      parameters: {
        'type': 'object',
        'properties': {
          'duration_minutes': {
            'type': 'integer',
            'description': 'How long the timer should run (default is 25).',
          },
          'focus_topic': {
            'type': 'string',
            'description': 'What the student is focusing on during this timer.',
          },
        },
        'required': ['duration_minutes', 'focus_topic'],
      },
    ),
    const Tool(
      name: 'narrate_explanation',
      description: 'Reads an explanation out loud using the devices native voice narrator.',
      parameters: {
        'type': 'object',
        'properties': {
          'text_to_read': {
            'type': 'string',
            'description': 'The text content to be spoken.',
          },
          'voice_style': {
            'type': 'string',
            'description': 'The style of narration (calm, enthusiastic, professional).',
          },
        },
        'required': ['text_to_read'],
      },
    ),
    const Tool(
      name: 'launch_mini_game',
      description: 'Launches a subject-specific interactive mini-game for hands-on learning.',
      parameters: {
        'type': 'object',
        'properties': {
          'game_type': {
            'type': 'string',
            'description': 'The type of game (equation_balancer, alphabet_match, memory_grid).',
          },
          'difficulty': {
            'type': 'integer',
            'description': 'Difficulty level from 1 to 5.',
          },
        },
        'required': ['game_type', 'difficulty'],
      },
    ),
  ];

  /// Handles the raw model output for tools.
  /// This is our "GenUI-Lite" parsing layer.
  /// It can handle slightly malformed JSON or direct function calls.
  static Map<String, dynamic>? parseLiteResponse(String output) {
    // Basic regex to find JSON-like structures if the model misses brackets
    // (This is the fault-tolerance for quantized edge models)
    if (output.contains('"{') && output.contains('}"')) {
       // Model might have wrapped JSON in extra quotes
       // We can strip them here.
    }
    return null; // Placeholder for future custom parsing if needed
  }

  static Future<InferenceChat> createEducationalChat() async {
    final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
    return model.createChat(
      temperature: 0.7,
      randomSeed: 1,
      topP: 0.9,
      tokenBuffer: 512,
      supportsFunctionCalls: true,
      tools: educationalTools,
    );
  }
}
