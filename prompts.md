# Gemma 4 EduCloud Prompts

This document catalogs the system prompts and structured output templates used by the on-device Gemma 4 model to generate educational content in EduCloud.

---

## 1. Study Materials (General Generation)

Used in `StudyMaterialService.generateAndSaveMaterial`.

### Quiz Generation
```markdown
Using the following context, generate a {count}-question multiple choice quiz.

Difficulty: {difficulty_label}.
{difficulty_prompt_guidance}

Each question must have exactly 4 options. Vary which option is correct (don't always make it the first one). Each question should focus on a different idea — avoid repeating the same concept across questions.

Return ONLY a JSON object with a 'questions' key containing exactly {count} questions in the list.

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

Context: {context}
```

### Mind Map Generation
```markdown
Using the following context, extract the key concepts and their relationships to create a Mind Map.
Return ONLY a JSON object with:
- 'nodes': a list of {id, label}
- 'edges': a list of {from, to, label}

Context: {context}
```

### Study Summary
```markdown
Using the following context, generate a comprehensive study summary. Return ONLY the text. 
Context: {context}
```

### Flashcards
```markdown
Using the following context, generate exactly {count} flashcards (Question/Answer pairs). Each card should target a different idea — do not duplicate concepts across cards.

Return ONLY a JSON object with a 'cards' key containing exactly {count} flashcards in the list.

Example:
{
  "cards": [
    {"question": "...", "answer": "..."}
  ]
}

Context: {context}
```

---

## 2. Structured Workshops

### Workshop Outline Generation
```markdown
You are designing a structured workshop for a student studying "{category_name}".

Difficulty: {depth_label}.
{depth_prompt_guidance}

Build a course outline of EXACTLY {lessonCount} lessons that progresses logically from foundations to more advanced material. Use the supplied context as the source of truth — don't invent topics that aren't supported by the context.

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

The lessons array MUST contain exactly {lessonCount} entries.
Context:
{context}
```

### Lesson Body Generation (Streaming)
```markdown
You are writing one lesson in a structured workshop on "{categoryName}" (overall difficulty: {depthLabel}).

Course outline:
{outlineSummary}

Now write the BODY for this specific lesson:
Title: {lesson_title}
Summary: {lesson_summary}
Key points the lesson must cover:
{key_points}

Write a clear, {depthLabel}-level lesson in Markdown. Use:
- A short opening paragraph that motivates the topic.
- Section headings (## Subtopic) where useful.
- Bullet lists for enumerations.
- Code blocks (```) for any code snippets.
- A short "Recap" section at the end that lists 2-3 takeaways.

DO NOT repeat the lesson title at the top — start straight into the content. Use the supplied context as the source of truth and stay grounded in it.

Context:
{context}
```

### Lesson Quiz Generation
```markdown
You are an expert examiner. Create a 5-question multiple-choice quiz based ONLY on the following lesson content.

Lesson Title: {lessonTitle}
Content:
{lessonBody}

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

Ensure questions are challenging but fair based on the text.
```

---

## 3. Tool Calling Catalog (GenUI)

Defined in `EducationalToolService.educationalTools`. These are provided to the model's tool-calling engine.

- **`generate_interactive_quiz`**: Creates a gamified quiz based on the study material.
- **`award_badge`**: Awards a digital badge to the student for mastering a concept.
- **`start_focus_timer`**: Starts a Pomodoro-style focus timer.
- **`narrate_explanation`**: Reads an explanation out loud using the device's native voice narrator.
- **`launch_mini_game`**: Launches a subject-specific interactive mini-game.
