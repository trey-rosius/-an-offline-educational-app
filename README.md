# EduCloud: On-Device AI Study Hub 🚀

EduCloud is a premium, offline-first educational platform that leverages on-device LLMs (Google Gemma 4) to transform local documents into immersive, interactive learning experiences. 

Designed for students who need a distraction-free, privacy-preserving environment, EduCloud brings Generative UI (GenUI) and Retrieval-Augmented Generation (RAG) directly to the edge.

---

## 🌟 Key Features

- **Local Document Ingestion (RAG)**: Turn PDFs and textbooks into a searchable knowledge base. All vectorization and retrieval happen on-device using a local embedding model.
- **Structured Workshops**: Automatically generate multi-lesson courses from your library, complete with learning objectives and lazy-loaded content.
- **Interactive Quizzes & Flashcards**: AI-generated testing materials that focus on concepts you've actually studied.
- **GenUI-Lite Chat**: An intelligent study companion that doesn't just talk—it acts. The AI can trigger focus timers, award achievement badges, and launch interactive mini-games.
- **Premium UX**: A "glassmorphic" design system with smooth animations and a dark-mode optimized interface for long study sessions.

---

## 🏗️ Technical Architecture

### 1. On-Device AI Engine
EduCloud uses the `flutter_gemma` plugin to run **Google's Gemma 4** models locally via LiteRT (formerly TFLite). 
- **Privacy**: No user data, documents, or chat history ever leave the device.
- **Offline Access**: Fully functional in areas with limited or no internet connectivity.

### 2. Universal JSON Repair Pipeline
One of the core innovations in EduCloud is its **Robust Sanitization Engine** (`JsonUtils`). Smaller on-device models can occasionally hallucinate JSON syntax (e.g., unescaped quotes in descriptions or truncated closing brackets).
- **State-Machine Parser**: A custom walker that identifies and escapes internal quotes and control characters.
- **Force-Closure Mechanism**: Uses a bracket stack to repair truncated JSON streams in real-time.
- **Atomic Extraction**: Isolates JSON payloads from model "preamble" or prose.

### 3. Retrieval-Augmented Generation (RAG)
- **Vector Database**: Utilizes **ObjectBox** for high-performance local storage of text chunks and embeddings.
- **Contextual Injection**: Relevant document fragments are retrieved based on semantic similarity and injected into the LLM prompt to ensure factual accuracy and grounded responses.

### 4. GenUI-Lite Architecture
Instead of relying on heavy UI-generation frameworks, EduCloud uses a lightweight **Tool-Calling Mapping** system:
1. **Tool Definition**: Tools (e.g., `generate_interactive_quiz`) are defined with strict schemas.
2. **Execution**: The AI decides which tool to call.
3. **Rendering**: The `ChatMessageWidget` detects tool calls and renders native, high-performance Flutter widgets (like the `QuizCard`) inline.

---

## 🛠️ Tech Stack

- **Framework**: Flutter (Dart)
- **AI Models**: Gemma 2b/4b (via `flutter_gemma`)
- **Embeddings**: Local Gecko/Minilm models
- **Database**: ObjectBox (NoSQL + Vector Support)
- **Design**: Vanilla Flutter with Custom Glassmorphism Theme

---

## 🚀 Getting Started

1. **Clone & Install**:
   ```bash
   flutter pub get
   ```
2. **Configure Native Dependencies**:
   - For **iOS**: Run `pod install --repo-update` in the `ios` directory.
   - For **Android**: Ensure `minSdkVersion` is 21 or higher.
3. **Model Download**:
   Upon first launch, navigate to the "Model Selection" screen to download the Gemma 4 weights (approx. 1.2GB - 2GB depending on quantization).

---

## 📄 Prompts
A complete catalog of the system prompts and structured templates used to guide the AI can be found in [prompts.md](prompts.md).

---

## 🏆 Competition Merit
EduCloud demonstrates that **Sophisticated AI isn't dependent on the Cloud**. By combining local RAG, a robust JSON repair engine, and premium UI/UX, we've created a tool that is private, permanent, and performant—setting a new standard for on-device generative applications.
