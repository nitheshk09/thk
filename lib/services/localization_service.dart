import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { english, hindi, telugu }

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  AppLanguage _currentLanguage = AppLanguage.english;
  AppLanguage get currentLanguage => _currentLanguage;

  // Language codes for Google Translate API
  String get languageCode {
    switch (_currentLanguage) {
      case AppLanguage.english:
        return 'en';
      case AppLanguage.hindi:
        return 'hi';
      case AppLanguage.telugu:
        return 'te';
    }
  }

  String get languageDisplayCode {
    switch (_currentLanguage) {
      case AppLanguage.english:
        return 'EN';
      case AppLanguage.hindi:
        return 'HI';
      case AppLanguage.telugu:
        return 'TE';
    }
  }

  String get languageName {
    switch (_currentLanguage) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.hindi:
        return 'हिन्दी';
      case AppLanguage.telugu:
        return 'తెలుగు';
    }
  }

  String get languageFlag {
    switch (_currentLanguage) {
      case AppLanguage.english:
        return '🇺🇸';
      case AppLanguage.hindi:
        return '🇮🇳';
      case AppLanguage.telugu:
        return '🇮🇳';
    }
  }

  // Static translations for UI elements (Pre-translated)
  static final Map<AppLanguage, Map<String, String>> _staticTranslations = {
    AppLanguage.english: {
      'home': 'Home',
      'courses': 'My Topics',
      'wishlist': 'Wishlist',
      'quiz': 'Quiz',
      'dashboard': 'Dashboard',
      'search': 'Search courses...',
      'popular_courses': 'Popular Courses',
      'categories': 'Categories',
      'my_progress': 'My Progress',
      'continue_learning': 'Continue Learning',
      'notifications': 'Notifications',
      'settings': 'Settings',
      'profile': 'Profile',
      'language': 'Language',
      'select_language': 'Select Language',
      'logout': 'Logout',
      'login': 'Login',
      'signup': 'Sign Up',
      'email': 'Email',
      'password': 'Password',
      'forgot_password': 'Forgot Password?',
      'welcome_back': 'Welcome Back',
      'create_account': 'Create Account',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'retry': 'Retry',
      'cancel': 'Cancel',
      'ok': 'OK',
      'save': 'Save',
      'edit': 'Edit',
      'delete': 'Delete',
      'share': 'Share',
      'download': 'Download',
      'play': 'Play',
      'pause': 'Pause',
      'next': 'Next',
      'previous': 'Previous',
      'finish': 'Finish',
      'start': 'Start',
      'complete': 'Complete',
      'progress': 'Progress',
      'score': 'Score',
      'results': 'Results',
      'correct': 'Correct',
      'incorrect': 'Incorrect',
      'pass': 'Pass',
      'fail': 'Fail',
      'cybersecurity': 'Cybersecurity',
      'phishing': 'Phishing',
      'malware': 'Malware',
      'data_protection': 'Data Protection',
      'network_security': 'Network Security',
      'password_security': 'Password Security',
      'social_engineering': 'Social Engineering',
      'threat_detection': 'Threat Detection',
    },
    AppLanguage.hindi: {
      'home': 'होम',
      'courses': 'मेरे विषय',
      'wishlist': 'इच्छा सूची',
      'quiz': 'क्विज़',
      'dashboard': 'डैशबोर्ड',
      'search': 'कोर्स खोजें...',
      'popular_courses': 'लोकप्रिय कोर्स',
      'categories': 'श्रेणियां',
      'my_progress': 'मेरी प्रगति',
      'continue_learning': 'सीखना जारी रखें',
      'notifications': 'सूचनाएं',
      'settings': 'सेटिंग्स',
      'profile': 'प्रोफ़ाइल',
      'language': 'भाषा',
      'select_language': 'भाषा चुनें',
      'logout': 'लॉग आउट',
      'login': 'लॉगिन',
      'signup': 'साइन अप',
      'email': 'ईमेल',
      'password': 'पासवर्ड',
      'forgot_password': 'पासवर्ड भूल गए?',
      'welcome_back': 'वापस स्वागत है',
      'create_account': 'खाता बनाएं',
      'loading': 'लोड हो रहा है...',
      'error': 'त्रुटि',
      'success': 'सफलता',
      'retry': 'पुनः प्रयास करें',
      'cancel': 'रद्द करें',
      'ok': 'ठीक है',
      'save': 'सेव करें',
      'edit': 'संपादित करें',
      'delete': 'हटाएं',
      'share': 'साझा करें',
      'download': 'डाउनलोड',
      'play': 'चलाएं',
      'pause': 'रोकें',
      'next': 'अगला',
      'previous': 'पिछला',
      'finish': 'समाप्त',
      'start': 'शुरू करें',
      'complete': 'पूर्ण',
      'progress': 'प्रगति',
      'score': 'स्कोर',
      'results': 'परिणाम',
      'correct': 'सही',
      'incorrect': 'गलत',
      'pass': 'उत्तीर्ण',
      'fail': 'असफल',
      'cybersecurity': 'साइबर सुरक्षा',
      'phishing': 'फ़िशिंग',
      'malware': 'मैलवेयर',
      'data_protection': 'डेटा सुरक्षा',
      'network_security': 'नेटवर्क सुरक्षा',
      'password_security': 'पासवर्ड सुरक्षा',
      'social_engineering': 'सामाजिक इंजीनियरिंग',
      'threat_detection': 'खतरे की पहचान',
    },
    AppLanguage.telugu: {
      'home': 'హోం',
      'courses': 'నా టాపిక్స్',
      'wishlist': 'కోరిక జాబితా',
      'quiz': 'క్విజ్',
      'dashboard': 'డ్యాష్‌బోర్డ్',
      'search': 'కోర్సులను వెతకండి...',
      'popular_courses': 'ప్రసిద్ధ కోర్సులు',
      'categories': 'వర్గాలు',
      'my_progress': 'నా పురోగతి',
      'continue_learning': 'నేర్చుకోవడం కొనసాగించండి',
      'notifications': 'నోటిఫికేషన్లు',
      'settings': 'సెట్టింగులు',
      'profile': 'ప్రొఫైల్',
      'language': 'భాష',
      'select_language': 'భాష ఎంచుకోండి',
      'logout': 'లాగ్ అవుట్',
      'login': 'లాగిన్',
      'signup': 'సైన్ అప్',
      'email': 'ఇమెయిల్',
      'password': 'పాస్‌వర్డ్',
      'forgot_password': 'పాస్‌వర్డ్ మర్చిపోయారా?',
      'welcome_back': 'తిరిగి స్వాగతం',
      'create_account': 'ఖాతా సృష్టించండి',
      'loading': 'లోడ్ అవుతోంది...',
      'error': 'లోపం',
      'success': 'విజయం',
      'retry': 'మళ్లీ ప్రయత్నించండి',
      'cancel': 'రద్దు చేయండి',
      'ok': 'సరే',
      'save': 'సేవ్ చేయండి',
      'edit': 'సవరించండి',
      'delete': 'తొలగించండి',
      'share': 'షేర్ చేయండి',
      'download': 'డౌన్‌లోడ్',
      'play': 'ప్లే',
      'pause': 'పాజ్',
      'next': 'తదుపరి',
      'previous': 'మునుపటి',
      'finish': 'ముగించండి',
      'start': 'ప్రారంభించండి',
      'complete': 'పూర్తి',
      'progress': 'పురోగతి',
      'score': 'స్కోర్',
      'results': 'ఫలితాలు',
      'correct': 'సరైనది',
      'incorrect': 'తప్పు',
      'pass': 'ఉత్తీర్ణత',
      'fail': 'విఫలత',
      'cybersecurity': 'సైబర్ భద్రత',
      'phishing': 'ఫిషింగ్',
      'malware': 'మాల్వేర్',
      'data_protection': 'డేటా రక్షణ',
      'network_security': 'నెట్వర్క్ భద్రత',
      'password_security': 'పాస్‌వర్డ్ భద్రత',
      'social_engineering': 'సామాజిక ఇంజనీరింగ్',
      'threat_detection': 'ముప్పు గుర్తింపు',
    },
  };

  // Get static translation (for UI elements)
  String getStaticTranslation(String key) {
    return _staticTranslations[_currentLanguage]?[key] ?? key;
  }

  // Initialize language from saved preference
  Future<void> initializeLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('app_language');
      if (savedLanguage != null) {
        switch (savedLanguage) {
          case 'hindi':
            _currentLanguage = AppLanguage.hindi;
            break;
          case 'telugu':
            _currentLanguage = AppLanguage.telugu;
            break;
          default:
            _currentLanguage = AppLanguage.english;
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error initializing language: $e');
    }
  }

  // Change language and save to preferences
  Future<void> changeLanguage(AppLanguage newLanguage) async {
    if (_currentLanguage != newLanguage) {
      _currentLanguage = newLanguage;
      
      // Save to preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        String languageString;
        switch (newLanguage) {
          case AppLanguage.hindi:
            languageString = 'hindi';
            break;
          case AppLanguage.telugu:
            languageString = 'telugu';
            break;
          default:
            languageString = 'english';
        }
        await prefs.setString('app_language', languageString);
      } catch (e) {
        print('Error saving language preference: $e');
      }
      
      // Notify all listeners
      notifyListeners();
    }
  }

  // Get all available languages
  List<Map<String, dynamic>> getAvailableLanguages() {
    return [
      {
        'language': AppLanguage.english,
        'name': 'English',
        'flag': '🇺🇸',
        'code': 'EN',
        'selected': _currentLanguage == AppLanguage.english,
      },
      {
        'language': AppLanguage.hindi,
        'name': 'हिन्दी',
        'flag': '🇮🇳',
        'code': 'HI',
        'selected': _currentLanguage == AppLanguage.hindi,
      },
      {
        'language': AppLanguage.telugu,
        'name': 'తెలుగు',
        'flag': '🇮🇳',
        'code': 'TE',
        'selected': _currentLanguage == AppLanguage.telugu,
      },
    ];
  }
}