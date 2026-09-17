import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> speak(String text) async {
    if (!_initialized) {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(0.45);
      _initialized = true;
    }
    await _tts.stop();
    await _tts.speak(text);
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
