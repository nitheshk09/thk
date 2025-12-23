// lib/services/translation_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import '../config/api_config.dart';

class TranslationService {
  final FlutterTts _flutterTts = FlutterTts();

  /// Translates [text] from [fromLang] to [toLang] using
  /// the free Google Translate Web API.
  Future<String> translate(String text, String fromLang, String toLang) async {
    try {
      if (text.trim().isEmpty) return "";

      final Uri url = Uri.parse(
        ApiConfig.buildGoogleTranslateUrl(text, fromLang, toLang),
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Google Translate returns nested lists
        final translated = data[0][0][0];
        return translated ?? "";
      } else {
        throw Exception("Translation failed: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Translation error: $e");
      return "Translation failed";
    }
  }

  /// Speaks the given [text] using the system's text-to-speech engine.
  /// [langCode] example: "en-US", "hi-IN", "es-ES"
  Future<void> speak(String text, String langCode) async {
    try {
      if (text.trim().isEmpty) return;

      await _flutterTts.setLanguage(langCode);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(text);
    } catch (e) {
      print("❌ TTS error: $e");
    }
  }

  /// Initialize Text-to-Speech
  Future<void> initializeTts() async {
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      print('✅ TTS initialized');
    } catch (e) {
      print('⚠️ TTS initialization error: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('⚠️ TTS stop error: $e');
    }
  }

  /// Convert language code to TTS language code
  /// 
  /// [langCode] - Simple language code like 'en', 'hi', 'te'
  /// Returns full language code like 'en-US', 'hi-IN', 'te-IN'
  String getTtsLanguageCode(String langCode) {
    switch (langCode) {
      case 'en':
        return 'en-US';
      case 'hi':
        return 'hi-IN';
      case 'te':
        return 'te-IN';
      default:
        return 'en-US';
    }
  }

  /// Detect the language of the input text
  /// Returns 'hi' for Hindi, 'te' for Telugu, 'en' for English
  String detectLanguage(String text) {
    if (text.trim().isEmpty) return 'en';
    
    print('🔍 Analyzing text: "$text"');
    
    // Telugu script detection - Unicode range U+0C00–U+0C7F
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) {
      print('✅ Telugu script detected');
      return 'te';
    }
    
    // Hindi/Devanagari script detection - Unicode range U+0900–U+097F
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      print('✅ Hindi script detected');
      return 'hi';
    }
    
    final lowerText = text.toLowerCase();
    
    // First check for strong English indicators
    final strongEnglishWords = [
      'what', 'how', 'when', 'where', 'why', 'who', 'which', 'the', 'is', 'are', 'am',
      'can', 'could', 'would', 'should', 'will', 'shall', 'may', 'might', 'must',
      'hello', 'hi', 'help', 'please', 'thank', 'thanks', 'sorry', 'excuse',
      'explain', 'tell', 'show', 'give', 'get', 'make', 'take', 'find', 'search',
      'about', 'information', 'details', 'learn', 'know', 'understand',
    ];
    
    int englishMatches = 0;
    for (String word in strongEnglishWords) {
      if (RegExp(r'\b' + word + r'\b').hasMatch(lowerText)) {
        englishMatches++;
        print('✅ Strong English word detected: "$word"');
      }
    }
    
    // If we found strong English indicators, return English
    if (englishMatches >= 2) {
      print('✅ Multiple English words detected - classified as English');
      return 'en';
    }
    
    // Telugu words detection (only unique Telugu words, not common English words)
    final teluguUniqueWords = [
      // Core Telugu identification words
      'cheppandi', 'cheppu', 'cheppali', 'chepte', 'cheppara', 'chepu',
      'gurinchi', 'gurchi', 'gurnchi', 'gurunchi', 'gurinche', 'gurinci', 'gurunche',
      'చెప్పండి', 'గురించి', // Native Telugu script versions
      
      // Common Telugu words and phrases  
      'ela', 'elaa', 'ela undi', 'yela', 'ela undhi', 'elaa undi',
      'enti', 'emiti', 'entidi', 'em undi', 'emiti idi', 'yenti', 'yemiti',
      'chala', 'chaala', 'baga', 'baaga', 'bagaa', 'chaalaa',
      'nenu', 'meeru', 'mee', 'memu', 'maaku', 'naaku',
      'andi', 'aam', 'avunu', 'ledu', 'ledhu', 'aunu', 'leduu',
      'ante', 'antey', 'adi', 'idi', 'adhi', 'idhi', 'antee',
      'kavali', 'kavalena', 'undali', 'kaavali', 'kavaali',
      'telugu', 'telugulo', 'telugula', 'telugulalo', 'teluguloni',
      
      // Telugu question words
      'ekkada', 'eppudu', 'enduku', 'entha', 'enni', 'em',
      'evaru', 'evari', 'em chestaru', 'em cheyyali', 'emm',
      'yevaru', 'yeppudu', 'yekkada', 'yenduku', 'yem',
      
      // Telugu common phrases
      'theliyali', 'thelusu', 'artham', 'arthamaindi', 'thelusaa',
      'chudali', 'vinali', 'nerchukovali', 'nerchukovaali', 'chudaali',
      'vishayam', 'topiclu', 'vethuku', 'vethakandi', 'chupaandu', 'chupistu',
      
      // Specific Telugu cyber security terms (from chatbot service)
      'చూపించు', 'వెతుకు', 'సైబర్', 'సెక్యూరిటీ',
      
      // Telugu phonetic variations and common spellings
      'chepi', 'cheppi', 'cheppina', 'gurchi', 'gurnchi', 'cheppava',
      'undi', 'undhi', 'undii', 'unndi', 'unnayi', 'untayi',
      'malli', 'maree', 'kuda', 'kooda', 'kani', 'kaani',
    ];
    
    // Check Telugu words - look for matches
    for (String word in teluguUniqueWords) {
      if (lowerText.contains(word)) {
        print('✅ Telugu word detected: "$word"');
        return 'te';
      }
    }
    
    // Hindi words detection (only unique Hindi words, not common English words)
    final hindiUniqueWords = [
      // Common Hindi words
      'kya', 'kaise', 'kaisa', 'kahan', 'kab', 'kyun', 'kyu',
      'batao', 'bataiye', 'batana', 'bolo', 'boliye', 'batiye',
      'baare', 'bare', 'vishay', 'sambandh', 'ke baare mein',
      'main', 'mein', 'hum', 'humein', 'aap', 'aapko', 'aapke',
      'hai', 'hain', 'tha', 'the', 'hoga', 'honge',
      'kuch', 'koi', 'sabh', 'sab', 'yeh', 'veh', 'woh', 'ye',
      'samjhao', 'samjhana', 'seekhna', 'sikhna', 'samjhaiye',
      'hindi', 'hindime', 'hindustani', 'hindi mein',
      // Hindi question words
      'kahaan', 'kitna', 'kitne', 'kaun', 'koun',
      // Hindi common phrases
      'pata', 'maloom', 'samajh', 'jaanna', 'jaana',
      'dekhna', 'sunna', 'padhna', 'likhna', 'dekho',
      'ke baare', 'vishay mein',
    ];
    
    // Check Hindi words - look for matches
    for (String word in hindiUniqueWords) {
      if (lowerText.contains(word)) {
        print('✅ Hindi word detected: "$word"');
        return 'hi';
      }
    }
    
    print('📝 Defaulting to English (no strong indicators found)');
    // Default to English
    return 'en';
  }

  /// Get response in English and translate to target language if needed
  Future<String> getTranslatedResponse(String englishResponse, String targetLang) async {
    if (targetLang == 'en' || englishResponse.trim().isEmpty) {
      return englishResponse;
    }
    
    try {
      return await translate(englishResponse, 'en', targetLang);
    } catch (e) {
      print('❌ Translation error: $e');
      return englishResponse; // Fallback to English if translation fails
    }
  }
}
