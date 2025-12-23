import 'dart:convert';
import 'package:http/http.dart' as http;

/// Alternative free translation service using LibreTranslate
class LibreTranslateService {
  static final LibreTranslateService _instance = LibreTranslateService._internal();
  factory LibreTranslateService() => _instance;
  LibreTranslateService._internal();

  // Public LibreTranslate instances (completely free)
  static const List<String> _publicInstances = [
    'https://libretranslate.de',
    'https://translate.terraprint.co',
    'https://translate.argosopentech.com',
  ];

  int _currentInstanceIndex = 0;

  /// Translate text using LibreTranslate (completely free)
  Future<String> translate(String text, String targetLanguage) async {
    if (text.isEmpty) return text;

    // Try each public instance
    for (int i = 0; i < _publicInstances.length; i++) {
      try {
        final instance = _publicInstances[(_currentInstanceIndex + i) % _publicInstances.length];
        final translation = await _translateWithInstance(instance, text, targetLanguage);
        
        if (translation.isNotEmpty && translation != text) {
          // Update current instance on success
          _currentInstanceIndex = (_currentInstanceIndex + i) % _publicInstances.length;
          return translation;
        }
      } catch (e) {
        print('LibreTranslate instance ${_publicInstances[(_currentInstanceIndex + i) % _publicInstances.length]} failed: $e');
        continue;
      }
    }

    return text; // Return original text if all instances fail
  }

  Future<String> _translateWithInstance(String baseUrl, String text, String targetLanguage) async {
    final response = await http.post(
      Uri.parse('$baseUrl/translate'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'q': text,
        'source': 'en',
        'target': targetLanguage,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['translatedText'] ?? text;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Get available language codes
  static Map<String, String> get supportedLanguages => {
    'en': 'English',
    'hi': 'Hindi',
    'te': 'Telugu',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'ar': 'Arabic',
  };
}