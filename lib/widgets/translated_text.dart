import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/translation_service.dart';

/// Widget that automatically translates text based on current language
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final bool useStaticTranslation;

  const TranslatedText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.useStaticTranslation = false,
  }) : super(key: key);

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  final LocalizationService _localizationService = LocalizationService();
  final TranslationService _translationService = TranslationService();
  
  String _translatedText = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _localizationService.addListener(_onLanguageChanged);
    _translateText();
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translateText();
    }
  }

  @override
  void dispose() {
    _localizationService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    _translateText();
  }

  Future<void> _translateText() async {
    if (!mounted) return;
    
    final targetLang = _localizationService.languageCode;
    
    // If English, no need to translate
    if (targetLang == 'en') {
      setState(() {
        _translatedText = widget.text;
        _isLoading = false;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      String translatedText;
      
      if (widget.useStaticTranslation) {
        // Use pre-defined static translations
        translatedText = _localizationService.getStaticTranslation(widget.text);
        print('📖 Static translation: "${widget.text}" → "$translatedText" ($targetLang)');
      } else {
        // Use dynamic translation service with Google Translate
        print('🌐 Google translating: "${widget.text}" (en → $targetLang)');
        translatedText = await _translationService.translate(
          widget.text,
          'en', // from English
          targetLang,
        );
        print('✅ Google translated: "${widget.text}" → "$translatedText"');
      }
      
      if (mounted) {
        setState(() {
          _translatedText = translatedText;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Translation error for "${widget.text}": $e');
      if (mounted) {
        setState(() {
          _translatedText = widget.text; // Fallback to original text
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _ShimmerText(
        text: widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        softWrap: widget.softWrap,
      );
    }

    return Text(
      _translatedText.isEmpty ? widget.text : _translatedText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
  }
}

/// Shimmer effect widget for loading state
class _ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  const _ShimmerText({
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
  });

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFEBEBEB),
                Color(0xFFF4F4F4),
                Color(0xFFEBEBEB),
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: Text(
            widget.text,
            style: widget.style?.copyWith(
              color: Colors.grey[300],
            ) ?? TextStyle(color: Colors.grey[300]),
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
            softWrap: widget.softWrap,
          ),
        );
      },
    );
  }
}

/// Extension to make translation easier for strings
extension StringTranslation on String {
  /// Get static translation (for UI elements)
  String tr() {
    return LocalizationService().getStaticTranslation(this);
  }
  
  /// Get dynamic translation (for content)
  Future<String> translate() async {
    final localizationService = LocalizationService();
    return await TranslationService().translate(this, 'en', localizationService.languageCode);
  }
}

/// Helper class for common translations
class AppTranslations {
  static final LocalizationService _localizationService = LocalizationService();
  
  // Common UI elements
  static String get home => 'home'.tr();
  static String get courses => 'courses'.tr();
  static String get wishlist => 'wishlist'.tr();
  static String get quiz => 'quiz'.tr();
  static String get dashboard => 'dashboard'.tr();
  static String get search => 'search'.tr();
  static String get popularCourses => 'popular_courses'.tr();
  static String get categories => 'categories'.tr();
  static String get myProgress => 'my_progress'.tr();
  static String get continueLearning => 'continue_learning'.tr();
  static String get notifications => 'notifications'.tr();
  static String get settings => 'settings'.tr();
  static String get profile => 'profile'.tr();
  static String get language => 'language'.tr();
  static String get selectLanguage => 'select_language'.tr();
  static String get logout => 'logout'.tr();
  static String get login => 'login'.tr();
  static String get signup => 'signup'.tr();
  static String get email => 'email'.tr();
  static String get password => 'password'.tr();
  static String get forgotPassword => 'forgot_password'.tr();
  static String get welcomeBack => 'welcome_back'.tr();
  static String get createAccount => 'create_account'.tr();
  static String get loading => 'loading'.tr();
  static String get error => 'error'.tr();
  static String get success => 'success'.tr();
  static String get retry => 'retry'.tr();
  static String get cancel => 'cancel'.tr();
  static String get ok => 'ok'.tr();
  static String get save => 'save'.tr();
  static String get edit => 'edit'.tr();
  static String get delete => 'delete'.tr();
  static String get share => 'share'.tr();
  static String get download => 'download'.tr();
  static String get play => 'play'.tr();
  static String get pause => 'pause'.tr();
  static String get next => 'next'.tr();
  static String get previous => 'previous'.tr();
  static String get finish => 'finish'.tr();
  static String get start => 'start'.tr();
  static String get complete => 'complete'.tr();
  static String get progress => 'progress'.tr();
  static String get score => 'score'.tr();
  static String get results => 'results'.tr();
  static String get correct => 'correct'.tr();
  static String get incorrect => 'incorrect'.tr();
  static String get pass => 'pass'.tr();
  static String get fail => 'fail'.tr();
  static String get cybersecurity => 'cybersecurity'.tr();
  static String get phishing => 'phishing'.tr();
  static String get malware => 'malware'.tr();
  static String get dataProtection => 'data_protection'.tr();
  static String get networkSecurity => 'network_security'.tr();
  static String get passwordSecurity => 'password_security'.tr();
  static String get socialEngineering => 'social_engineering'.tr();
  static String get threatDetection => 'threat_detection'.tr();
}