import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;

  TtsService() {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // iOS Specific: Set audio category to playback
    await _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.duckOthers,
    ]);

    _flutterTts.setCompletionHandler(() {
      print("TTS: Finished speaking");
      _isPlaying = false;
    });

    _flutterTts.setErrorHandler((msg) {
      print("TTS Error: $msg");
      _isPlaying = false;
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    print("TTS: Starting to speak ${text.length} chars");
    _isPlaying = true;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
  }

  bool get isPlaying => _isPlaying;
}
