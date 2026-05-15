import 'dart:convert';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:objectbox/objectbox.dart';
import '../models/entities.dart';
import 'rag_service.dart';
import '../objectbox.g.dart';
import '../models/model.dart';
import '../utils/json_utils.dart';

/// User-selectable workshop depth.
enum WorkshopDepth {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const WorkshopDepth(this.label);
  final String label;

  String get promptGuidance {
    switch (this) {
      case WorkshopDepth.beginner:
        return 'Assume the student has no prior knowledge of the topic. '
            'Use plain language, define every new term, include simple '
            'analogies, and progress slowly from fundamentals.';
      case WorkshopDepth.intermediate:
        return 'Assume the student knows the basics. Cover the topic in '
            'real depth, include concrete examples and trade-offs, and '
            'connect concepts across lessons.';
      case WorkshopDepth.advanced:
        return 'Assume strong fundamentals. Focus on advanced techniques, '
            'edge cases, performance/security implications, and how the '
            'concepts apply in production systems.';
    }
  }
}

/// User-selectable quiz difficulty.
enum QuizDifficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const QuizDifficulty(this.label);
  final String label;

  /// Prompt fragment describing what kind of questions to generate.
  String get promptGuidance {
    switch (this) {
      case QuizDifficulty.easy:
        return 'Questions should test basic recall of facts that are '
            'explicitly stated in the context. Use clear, simple wording '
            'and short answer choices. Avoid trick questions.';
      case QuizDifficulty.medium:
        return 'Questions should test comprehension and the ability to '
            'apply concepts from the context to slightly different '
            'situations. Mix recall and reasoning. Distractor options '
            'should be plausible but clearly wrong on careful reading.';
      case QuizDifficulty.hard:
        return 'Questions should test analysis, synthesis, and inference. '
            'Require the student to combine multiple pieces of context '
            'or reason about implications that are not stated verbatim. '
            'Distractors should be subtle and require careful reading '
            'to eliminate.';
    }
  }
}

class StudyMaterialService {
  final RagService _ragService;
  late final Box<GeneratedStudyMaterial> _materialBox;

  StudyMaterialService(this._ragService, Store store) {
    _materialBox = store.box<GeneratedStudyMaterial>();
  }

  Future<void> _ensureModelActive() async {
    if (!FlutterGemma.hasActiveModel()) {
      final gemma4 = Model.gemma4_E2B;
      if (await FlutterGemma.isModelInstalled(gemma4.filename)) {
        await FlutterGemma.installModel(
          modelType: gemma4.modelType,
          fileType: gemma4.fileType,
        ).fromNetwork(gemma4.url).install();
      }
    }
  }

  /// Generates a study material (quiz, summary, flashcards, mind_map) for a
  /// category and persists it to ObjectBox.
  ///
  /// [count] applies to `'quiz'` and `'flashcards'` types — defaults to 10.
  /// [difficulty] only applies to `'quiz'` — defaults to medium.
  Future<GeneratedStudyMaterial> generateAndSaveMaterial({
    required SubjectCategory category,
    required String type, // 'quiz', 'summary', 'flashcards', 'mind_map'
    int count = 10,
    QuizDifficulty difficulty = QuizDifficulty.medium,
  }) async {
    // Ensure model is ready
    await _ensureModelActive();

    // 1. Get RAG context for the entire category. Pull a few more chunks
    // for larger generations so the model has more material to work with.
    final ragChunks = (count >= 15) ? 16 : (count >= 10 ? 12 : 10);
    final chunks = await _ragService.searchByCategory(
      "General overview of ${category.name}",
      category.id,
      maxResults: ragChunks,
    );

    final context = chunks.map((c) => c.text).join("\n\n");
    if (context.trim().isEmpty) {
      throw 'I couldn\'t find any information about "${category.name}" in your library. \n\nPlease add some PDFs or documents to this subject first using the "Add" button at the top right!';
    }

    String prompt = "";
    if (type == 'quiz') {
      prompt = """Using the following context, generate a $count-question multiple choice quiz.

Difficulty: ${difficulty.label}.
${difficulty.promptGuidance}

Each question must have exactly 4 options. Vary which option is correct (don't always make it the first one). Each question should focus on a different idea — avoid repeating the same concept across questions.

Return ONLY a JSON object with a 'questions' key containing exactly $count questions in the list.

Example format:
{
  "questions": [
    {
      "question": "...",
      "options": ["...", "...", "...", "..."],
      "correct_answer": "...",
      "explanation": "...",
      "source_quote": "...",
      "page_number": 1
    }
  ]
}

Context: $context""";
    } else if (type == 'mind_map') {
      prompt = """Using the following context, extract the key concepts and their relationships to create a Mind Map.
      Return ONLY a JSON object with:
      - 'nodes': a list of {id, label}
      - 'edges': a list of {from, to, label}

      Context: $context""";
    } else if (type == 'summary') {
      prompt = "Using the following context, generate a comprehensive study summary. Return ONLY the text. Context: $context";
    } else if (type == 'flashcards') {
      prompt = """Using the following context, generate exactly $count flashcards (Question/Answer pairs). Each card should target a different idea — do not duplicate concepts across cards.

Return ONLY a JSON object with a 'cards' key containing exactly $count flashcards in the list.

Example:
{
  "cards": [
    {"question": "...", "answer": "..."}
  ]
}

Context: $context""";
    }

    // Larger requests need more tokens to fit the full JSON payload.
    final int maxTokens = count >= 15 ? 4096 : 2560;
    // Use near-maximum stability (0.1 is safer for LiteRT than 0.0)
    final model = await FlutterGemma.getActiveModel(maxTokens: maxTokens);
    final chat = await model.createChat(temperature: 0.1);
    await chat.addQuery(Message.text(text: prompt));
    final response = await chat.generateChatResponse();
    
    String rawText = "";
    if (response is TextResponse) rawText = response.token;

    // The Universal Gemma Response Handler logic
    final cleanedResponse = _universalGemmaRepair(rawText, type);

    // If the repair still produced empty/invalid data, show the raw refusal
    if (cleanedResponse.length < 10 && !rawText.contains('{') && type != 'summary') {
       throw 'Gemma Refusal: "$rawText"';
    }

    // Auto-title so the materials list shows something useful at a glance.
    String? autoTitle;
    if (type == 'quiz') {
      autoTitle = '${category.name} · ${difficulty.label} · $count Q';
    } else if (type == 'flashcards') {
      autoTitle = '${category.name} · $count cards';
    }

    final material = GeneratedStudyMaterial(
      type: type,
      title: autoTitle,
      contentJson: cleanedResponse,
      dateCreated: DateTime.now(),
    );
    material.category.target = category;

    _materialBox.put(material);
    return material;
  }

  /// The Universal Gemma Response Handler.
  /// Standardizes extraction and repair for ALL Gemma responses.
  String _universalGemmaRepair(String raw, String type) {
    if (type == 'summary') {
      return raw.replaceAll('```markdown', '').replaceAll('```', '').trim();
    }

    // 1. Atomic Extraction (Find first { or [ and last } or ])
    final start = raw.contains('{') ? raw.indexOf('{') : (raw.contains('[') ? raw.indexOf('[') : -1);
    var end = raw.contains('}') ? raw.lastIndexOf('}') : (raw.contains(']') ? raw.lastIndexOf(']') : -1);
    
    if (start == -1) return raw.trim();
    // If we have a start but no end, take everything to the end of the string
    if (end == -1 || end <= start) end = raw.length - 1;
    
    String s = raw.substring(start, end + 1);

    // 2. Multiline & Whitespace Cleanup
    // Normalize smart quotes and remove actual newlines inside quotes.
    s = s.replaceAll('“', '"').replaceAll('”', '"').replaceAll('‘', "'").replaceAll('’', "'");

    // Pass 2.1: State-machine inner-quote normalizer.
    //
    // The model frequently emits things like:
    //   "To create a cost-efficient, "highly scalable", and easy-to-maintain..."
    // where the inner `"highly scalable"` quotes aren't escaped. The old
    // regex pass had two bugs:
    //   (a) Its non-greedy `.*?` stopped at the FIRST `"` followed by a
    //       comma, leaving a stray closing `"` mid-string.
    //   (b) When the string contained a fragment like `, "highly`, the
    //       `,\s*"` alternative in the alt-list would re-anchor on the
    //       inner comma and corrupt the surrounding field's quotes (e.g.
    //       `"options":` would become `"options':`).
    // This state-machine pass walks the string once and only treats a
    // `"` as the end of a string if what follows it actually looks like
    // a JSON structural separator (`:`, `]`, `}`, or `,` followed by
    // another value start). Every other `"` inside a string is replaced
    // with `'` to neutralize it.
    s = _normalizeInnerQuotes(s);

    s = s.replaceAllMapped(
      RegExp(r'":\s*"([^"]*)"', dotAll: true),
      (m) => '": "${m[1]!.replaceAll('\n', ' ').replaceAll('\r', '')}"'
    );

    // 3. Hallucination Cleanup (Stitch or Wrap "unquoted text" following a quote)
    // Example: "foo", Hallucination -> "foo Hallucination"
    //
    // The captured "hallucination" text MUST start with an ASCII letter —
    // otherwise the regex used to spuriously match the newline+`}` at the
    // end of a clean value and garble the closing.
    for (var i = 0; i < 3; i++) {
      final before = s;
      s = s.replaceAllMapped(
        RegExp(r'("\s*:\s*"[^"]*)"\s*,?\s*([A-Za-z][^"{\[]*?)(?=\s*[,}\]])', dotAll: true),
        (m) => '${m[1]} ${m[2].toString().trim().replaceAll('"', "'")}"'
      );
      if (s == before) break;
    }

    // 4. Array Wrapper (["A", B, C] -> ["A", "B", "C"]).
    //
    // String-aware walker. The previous regex-based pass was depth-blind
    // and would wrap content INSIDE a string (e.g. converting an inner
    // `, 'highly scalable',` fragment of a sentence into a malformed
    // `, "'highly scalable'",` "array item"). This walker only quotes
    // barewords that sit at actual array depth, outside any string.
    s = _quoteUnquotedArrayItems(s);

    // 5. Cheap Structural Fixes (Trailing commas, unquoted keys etc)
    s = s.replaceAll(RegExp(r',\s*\}'), '}');
    s = s.replaceAll(RegExp(r',\s*\]'), ']');
    s = s.replaceAllMapped(RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)\s*:'), (m) => '${m[1]}"${m[2]}":');

    // 6. Force Closure (Handle truncation)
    // We use a stack to ensure we close in the correct reverse order.
    List<String> stack = [];
    bool inQuote = false;
    for (int i = 0; i < s.length; i++) {
      if (s[i] == '"' && (i == 0 || s[i-1] != '\\')) inQuote = !inQuote;
      if (!inQuote) {
        if (s[i] == '{') stack.add('}');
        if (s[i] == '[') stack.add(']');
        if (s[i] == '}' || s[i] == ']') {
          if (stack.isNotEmpty && stack.last == s[i]) stack.removeLast();
        }
      }
    }
    if (inQuote) s += '"';
    while (stack.isNotEmpty) {
      s += stack.removeLast();
    }

    s = JsonUtils.cleanJson(s);

    print('██████████ REPAIRED JSON ██████████');
    print(s);
    return s;
  }


  bool _isJsonWhitespace(int code) =>
      code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D;

  String _normalizeInnerQuotes(String s) {
    final out = StringBuffer();
    bool inStr = false;
    bool seenInner = false;
    int i = 0;
    final n = s.length;
    while (i < n) {
      final c = s[i];
      if (inStr && c == '\\' && i + 1 < n) {
        out.write(c);
        out.write(s[i + 1]);
        i += 2;
        continue;
      }
      if (c == '"') {
        if (!inStr) {
          inStr = true;
          seenInner = false;
          out.write(c);
          i++;
          continue;
        }
        int j = i + 1;
        while (j < n && _isJsonWhitespace(s.codeUnitAt(j))) {
          j++;
        }
        bool closing;
        if (j >= n) {
          closing = true;
        } else {
          final next = s[j];
          if (next == ':' || next == ']' || next == '}') {
            closing = true;
          } else if (next == ',') {
            int k = j + 1;
            while (k < n && _isJsonWhitespace(s.codeUnitAt(k))) {
              k++;
            }
            if (k >= n) {
              closing = true;
            } else {
              final after = s[k];
              final code = after.codeUnitAt(0);
              final isDigit = code >= 0x30 && code <= 0x39;
              final structural = after == '"' ||
                  after == '{' ||
                  after == '[' ||
                  after == ']' ||
                  after == '}' ||
                  after == '-' ||
                  after == 't' ||
                  after == 'f' ||
                  after == 'n' ||
                  isDigit;
              closing = structural ? true : !seenInner;
            }
          } else {
            closing = false;
          }
        }
        if (closing) {
          out.write(c);
          inStr = false;
          seenInner = false;
        } else {
          out.write("'");
          seenInner = true;
        }
        i++;
        continue;
      }
      out.write(c);
      i++;
    }
    return out.toString();
  }

  String _quoteUnquotedArrayItems(String s) {
    final out = StringBuffer();
    bool inStr = false;
    int arrayDepth = 0;
    bool expectingValue = false;
    int i = 0;
    final n = s.length;
    while (i < n) {
      final c = s[i];
      if (inStr) {
        if (c == '\\' && i + 1 < n) {
          out.write(c);
          out.write(s[i + 1]);
          i += 2;
          continue;
        }
        if (c == '"') {
          inStr = false;
          out.write(c);
          i++;
          continue;
        }
        out.write(c);
        i++;
        continue;
      }
      if (c == '"') {
        inStr = true;
        expectingValue = false;
        out.write(c);
        i++;
        continue;
      }
      if (c == '[') {
        arrayDepth++;
        expectingValue = true;
        out.write(c);
        i++;
        continue;
      }
      if (c == ']') {
        if (arrayDepth > 0) arrayDepth--;
        expectingValue = false;
        out.write(c);
        i++;
        continue;
      }
      if (c == '{' || c == '}') {
        expectingValue = false;
        out.write(c);
        i++;
        continue;
      }
      if (c == ',' || c == ':') {
        expectingValue = true;
        out.write(c);
        i++;
        continue;
      }
      if (_isJsonWhitespace(c.codeUnitAt(0))) {
        out.write(c);
        i++;
        continue;
      }
      if (expectingValue && arrayDepth > 0) {
        final code = c.codeUnitAt(0);
        final isDigit = code >= 0x30 && code <= 0x39;
        if (c == '-' || c == 't' || c == 'f' || c == 'n' || isDigit) {
          expectingValue = false;
          out.write(c);
          i++;
          continue;
        }
        int j = i;
        bool localInStr = false;
        while (j < n) {
          final cj = s[j];
          if (localInStr) {
            if (cj == '\\' && j + 1 < n) {
              j += 2;
              continue;
            }
            if (cj == '"') localInStr = false;
            j++;
            continue;
          }
          if (cj == '"') {
            localInStr = true;
            j++;
            continue;
          }
          if (cj == ',' || cj == ']') break;
          j++;
        }
        final span = s.substring(i, j);
        int trimEnd = span.length;
        while (trimEnd > 0 &&
            _isJsonWhitespace(span.codeUnitAt(trimEnd - 1))) {
          trimEnd--;
        }
        final rawVal = span.substring(0, trimEnd);
        final trailing = span.substring(trimEnd);
        final isNumeric = RegExp(r'^-?\d+(\.\d+)?$').hasMatch(rawVal);
        if (isNumeric || rawVal == 'true' || rawVal == 'false' ||
            rawVal == 'null') {
          out.write(rawVal);
        } else {
          out.write('"');
          out.write(rawVal.replaceAll('"', "'"));
          out.write('"');
        }
        out.write(trailing);
        i = j;
        expectingValue = false;
        continue;
      }
      expectingValue = false;
      out.write(c);
      i++;
    }
    return out.toString();
  }


  List<GeneratedStudyMaterial> getMaterialsForCategory(int categoryId) {
    return _materialBox.query(GeneratedStudyMaterial_.category.equals(categoryId)).build().find();
  }

  // =====================================================================
  // Workshop generation, progress tracking, and badge awards.
  //
  // Workshops are stored as a `GeneratedStudyMaterial` with type='workshop'.
  // The `contentJson` is mutated in-place as the user progresses, so we get
  // persistence "for free" via the existing ObjectBox material box.
  // Lesson bodies are generated lazily on first open to keep the initial
  // workshop generation snappy.
  // =====================================================================

  /// Stage labels emitted during workshop generation.
  static const stageOutline = 'Drafting workshop outline...';
  static const stageDone = 'Workshop ready';

  /// Generates the *outline* of a workshop (title, description, lesson
  /// titles + key points). Lesson bodies are NOT generated here — they're
  /// filled in lazily by [generateLessonBody] when the user opens a
  /// lesson for the first time.
  ///
  /// [onProgress] is called with a stage label and a 0..1 progress value.
  Future<GeneratedStudyMaterial> generateWorkshopMaterial({
    required SubjectCategory category,
    int lessonCount = 6,
    WorkshopDepth depth = WorkshopDepth.intermediate,
    void Function(String stage, double progress)? onProgress,
  }) async {
    onProgress?.call(stageOutline, 0.0);
    await _ensureModelActive();

    // Pull a generous amount of context so the outline reflects the full
    // breadth of the subject.
    final chunks = await _ragService.searchByCategory(
      'Comprehensive overview of ${category.name} for a structured course',
      category.id,
      maxResults: 5,
    );
    final context = chunks.map((c) => c.text).join('\n\n');

    final prompt = '''You are designing a structured workshop for a student studying "${category.name}".

Difficulty: ${depth.label}.
${depth.promptGuidance}

Build a course outline of EXACTLY $lessonCount lessons that progresses logically from foundations to more advanced material. Use the supplied context as the source of truth — don't invent topics that aren't supported by the context.

CRITICAL JSON RULES — read these carefully:
1. Output ONLY a single JSON object. No prose before or after, no markdown code fences.
2. The entire output must be one continuous JSON object. DO NOT split long descriptions into multiple strings.
3. EVERY string value must be wrapped in double quotes ("), even if the value contains commas, colons, or other punctuation.
4. Inside any string, escape inner double quotes as \".
5. Do NOT put trailing commas before } or ].
6. Numbers (like estimatedMinutes) must NOT be quoted.

{
  "title": "Workshop Title",
  "description": "Short summary",
  "lessons": [
    {
      "title": "Lesson 1",
      "summary": "Short overview",
      "keyPoints": ["Point A", "Point B"],
      "estimatedMinutes": 10
    }
  ]
}

The lessons array MUST contain exactly $lessonCount entries.
Context:
$context''';

    print('██████████ MODEL GENERATION STARTED (Prompt length: ${prompt.length}) ██████████');
    final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
    // Lower temperature for stricter, more deterministic structured output.
    final chat = await model.createChat(temperature: 0.1);
    await chat.addQuery(Message.text(text: prompt));
    final response = await chat.generateChatResponse();

    onProgress?.call(stageOutline, 0.85);

    String raw = '';
    if (response is TextResponse) raw = response.token;

    Map<String, dynamic> outline;
    try {
      final repaired = _universalGemmaRepair(raw, 'workshop');
      outline = jsonDecode(repaired) as Map<String, dynamic>;
    } catch (e) {
      onProgress?.call('Repairing JSON...', 0.92);
      // _decodeOutline already tried both the as-is and aggressive repair
      // passes. If we land here, surface a clean error with a snippet so
      // the user can retry (and so it's debuggable).
      final preview = raw.length > 600 ? '${raw.substring(0, 600)}...' : raw;
      throw StateError(
        'Workshop outline JSON could not be parsed even after local repair.\n'
        'Parser error: $e\n'
        'Tip: try generating again — the on-device model occasionally emits '
        'malformed JSON. Lowering depth or lesson count can also help.\n'
        'Raw output preview:\n$preview',
      );
    }

    // Normalize lesson list and inject empty body fields (lazy fill).
    final rawLessons = (outline['lessons'] as List? ?? []);
    final lessons = <Map<String, dynamic>>[];
    for (var i = 0; i < rawLessons.length; i++) {
      final l = Map<String, dynamic>.from(rawLessons[i] as Map);
      l['index'] = i;
      l['body'] ??= ''; // generated on demand
      l['completed'] ??= false;
      l['completedAt'] ??= null;
      l['keyPoints'] ??= <dynamic>[];
      l['estimatedMinutes'] ??= 8;
      lessons.add(l);
    }

    final workshopJson = <String, dynamic>{
      'title': outline['title'] ?? '${category.name} Workshop',
      'description':
          outline['description'] ?? 'A structured course on ${category.name}.',
      'depth': depth.label,
      'lessonCount': lessons.length,
      'lessons': lessons,
      'startedAt': null,
      'lastAccessedAt': null,
      'lastLessonIndex': 0,
      'awardedBadges': <String>[],
    };

    final material = GeneratedStudyMaterial(
      type: 'workshop',
      title: '${category.name} · ${depth.label} workshop',
      contentJson: jsonEncode(workshopJson),
      dateCreated: DateTime.now(),
    );
    material.category.target = category;
    _materialBox.put(material);

    onProgress?.call(stageDone, 1.0);
    return material;
  }

  /// Lazily generates the body of a single lesson as a stream of updates.
  /// Stores the final body back into the workshop's contentJson.
  Stream<Map<String, dynamic>> generateLessonBodyStream({
    required GeneratedStudyMaterial workshop,
    required int lessonIndex,
  }) async* {
    final data = jsonDecode(JsonUtils.extractAndCleanJson(workshop.contentJson)) as Map<String, dynamic>;
    final lessons = (data['lessons'] as List).cast<Map<String, dynamic>>();
    if (lessonIndex < 0 || lessonIndex >= lessons.length) {
      throw RangeError.value(lessonIndex);
    }
    final lesson = lessons[lessonIndex];

    await _ensureModelActive();

    final categoryName = workshop.category.target?.name ?? 'the topic';
    final depthLabel = data['depth'] as String? ?? 'Intermediate';
    final outlineSummary = lessons.asMap().entries.map((e) {
      final title = e.value['title'] ?? 'Lesson ${e.key + 1}';
      return '${e.key + 1}. $title';
    }).join('\n');

    final chunks = await _ragService.searchByCategory(
      '${lesson['title']} ${(lesson['summary'] ?? '')}',
      workshop.category.target?.id ?? 0,
      maxResults: 5,
    );
    final context = chunks.map((c) => c.text).join('\n\n');

    final prompt = '''You are writing one lesson in a structured workshop on "$categoryName" (overall difficulty: $depthLabel).

Course outline:
$outlineSummary

Now write the BODY for this specific lesson:
Title: ${lesson['title']}
Summary: ${lesson['summary'] ?? ''}
Key points the lesson must cover:
${(lesson['keyPoints'] as List? ?? []).map((kp) => '- $kp').join('\n')}

Write a clear, ${depthLabel.toLowerCase()}-level lesson in Markdown. Use:
- A short opening paragraph that motivates the topic.
- Section headings (## Subtopic) where useful.
- Bullet lists for enumerations.
- Code blocks (```) for any code snippets.
- A short "Recap" section at the end that lists 2-3 takeaways.

DO NOT repeat the lesson title at the top — start straight into the content. Use the supplied context as the source of truth and stay grounded in it.

Context:
$context''';

    print('██████████ STREAMING LESSON BODY (Prompt: ${prompt.length}) ██████████');
    final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
    // 0.1 is the sweet spot for structured data stability on mobile
    final chat = await model.createChat(temperature: 0.1);
    await chat.addQuery(Message.text(text: prompt));

    final stream = chat.generateChatResponseAsync();
    String fullBody = '';

    await for (final response in stream) {
      if (response is TextResponse) {
        fullBody += response.token;
        lesson['body'] = fullBody.replaceAll('```markdown', '```').trim();
        yield lesson;
      }
    }

    // Final persist
    data['lessons'] = lessons;
    workshop.contentJson = jsonEncode(data);
    _materialBox.put(workshop);
  }

  /// Generates a quiz specifically for a single lesson's content.
  Future<GeneratedStudyMaterial> generateLessonQuiz({
    required SubjectCategory category,
    required String lessonTitle,
    required String lessonBody,
  }) async {
    await _ensureModelActive();

    final prompt = '''You are an expert examiner. Create a 5-question multiple-choice quiz based ONLY on the following lesson content.

Lesson Title: $lessonTitle
Content:
$lessonBody

CRITICAL JSON RULES:
1. Output ONLY a valid JSON object.
2. Format:
{
  "questions": [
    {
      "question": "Question text?",
      "options": ["A", "B", "C", "D"],
      "correct_answer": "A",
      "explanation": "Why A is correct"
    }
  ]
}

Ensure questions are challenging but fair based on the text.''';

    final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
    final chat = await model.createChat(temperature: 0.1);
    await chat.addQuery(Message.text(text: prompt));
    final response = await chat.generateChatResponse();

    String raw = '';
    if (response is TextResponse) raw = response.token;

    // Use the new universal repair pipeline
    final repaired = _universalGemmaRepair(raw, 'quiz');

    final material = GeneratedStudyMaterial(
      type: 'quiz',
      title: 'Quiz: $lessonTitle',
      contentJson: repaired,
      dateCreated: DateTime.now(),
    );
    material.category.target = category;
    _materialBox.put(material);
    return material;
  }

  /// Records the user opening a lesson — sets `startedAt`/`lastAccessedAt`
  /// and (idempotently) awards the "Workshop Started" badge if needed.
  ///
  /// Returns the list of NEWLY awarded badges (so the UI can show them).
  List<Badge> noteLessonOpened({
    required GeneratedStudyMaterial workshop,
    required int lessonIndex,
  }) {
    final data = jsonDecode(JsonUtils.extractAndCleanJson(workshop.contentJson)) as Map<String, dynamic>;
    final now = DateTime.now().toIso8601String();
    data['startedAt'] ??= now;
    data['lastAccessedAt'] = now;
    data['lastLessonIndex'] = lessonIndex;

    final newBadges = _maybeAwardMilestoneBadges(workshop, data);
    workshop.contentJson = jsonEncode(data);
    _materialBox.put(workshop);
    return newBadges;
  }

  /// Marks a lesson complete, persists progress, and awards milestone
  /// badges (25%, 50%, 100%) the first time each threshold is crossed.
  /// Returns the list of newly awarded badges so the UI can celebrate.
  List<Badge> markLessonComplete({
    required GeneratedStudyMaterial workshop,
    required int lessonIndex,
  }) {
    final data = jsonDecode(JsonUtils.extractAndCleanJson(workshop.contentJson)) as Map<String, dynamic>;
    final lessons = (data['lessons'] as List).cast<Map<String, dynamic>>();
    if (lessonIndex < 0 || lessonIndex >= lessons.length) return const [];

    final lesson = lessons[lessonIndex];
    if (lesson['completed'] != true) {
      lesson['completed'] = true;
      lesson['completedAt'] = DateTime.now().toIso8601String();
    }
    data['lessons'] = lessons;
    data['lastAccessedAt'] = DateTime.now().toIso8601String();
    data['lastLessonIndex'] = lessonIndex;

    final newBadges = _maybeAwardMilestoneBadges(workshop, data);
    workshop.contentJson = jsonEncode(data);
    _materialBox.put(workshop);
    return newBadges;
  }

  /// Returns currently-completed percentage 0..1 for a workshop material.
  double workshopProgress(GeneratedStudyMaterial workshop) {
    try {
      final data = jsonDecode(JsonUtils.extractAndCleanJson(workshop.contentJson)) as Map<String, dynamic>;
      final lessons = (data['lessons'] as List? ?? []);
      if (lessons.isEmpty) return 0.0;
      final done = lessons.where((l) => l['completed'] == true).length;
      return done / lessons.length;
    } catch (_) {
      return 0.0;
    }
  }

  /// Awards milestone badges that haven't been awarded yet, mutating the
  /// workshop data in place. Caller is responsible for persisting `data`.
  List<Badge> _maybeAwardMilestoneBadges(
    GeneratedStudyMaterial workshop,
    Map<String, dynamic> data,
  ) {
    final lessons = (data['lessons'] as List).cast<Map<String, dynamic>>();
    final total = lessons.length;
    if (total == 0) return const [];
    final done = lessons.where((l) => l['completed'] == true).length;
    final percent = done / total;

    final awarded =
        ((data['awardedBadges'] as List?)?.cast<String>() ?? const <String>[])
            .toSet();

    final categoryName =
        workshop.category.target?.name ?? 'a workshop';
    final workshopTitle = data['title'] as String? ?? '$categoryName Workshop';

    final newBadges = <Badge>[];

    void award(String key, String name, String reason) {
      if (awarded.contains(key)) return;
      final b = Badge(
        name: name,
        description: reason,
        dateEarned: DateTime.now(),
      );
      b.category.target = workshop.category.target;
      _ragService.store.box<Badge>().put(b);
      awarded.add(key);
      newBadges.add(b);
    }

    // Started: any lesson opened OR completed, OR startedAt set.
    if (data['startedAt'] != null) {
      award(
        'workshop_started',
        'Workshop Started',
        'Began the "$workshopTitle".',
      );
    }
    if (percent >= 0.25) {
      award(
        'workshop_25',
        '25% Complete',
        'Quarter of the way through "$workshopTitle".',
      );
    }
    if (percent >= 0.50) {
      award(
        'workshop_50',
        'Halfway There',
        'Half of "$workshopTitle" complete.',
      );
    }
    if (percent >= 1.00) {
      award(
        'workshop_complete',
        'Workshop Champion',
        'Completed every lesson of "$workshopTitle".',
      );
    }

    data['awardedBadges'] = awarded.toList();
    return newBadges;
  }
}
