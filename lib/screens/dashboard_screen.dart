import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';

import '../services/api_client.dart';
import '../services/wishlist_store.dart';
import '../services/cart_service.dart';
import '../services/localization_service.dart';
import '../services/translation_service.dart';
import '../services/plan_classifier.dart';
import '../config/razorpay_config.dart';
import '../widgets/topic_visuals.dart';
import '../widgets/translated_text.dart';
import '../widgets/lottie_loader.dart';
import '../widgets/plan_display_widget.dart';
import 'topic_detail_screen.dart';
import 'bundle_topics_detail_screen.dart';
import 'cart_screen.dart';
import 'account_screen.dart';
import 'notification_screen.dart';
import 'wishlist_screen.dart';

// Helper class for search results with module/video match
class _ModuleSearchResult {
  final CourseTopic topic;
  final String? matchingModuleTitle;
  final String? matchingVideoTitle;
  final bool isModuleDescriptionMatch;
  final String? matchedDescription;
  _ModuleSearchResult({
    required this.topic, 
    this.matchingModuleTitle,
    this.matchingVideoTitle,
    this.isModuleDescriptionMatch = false,
    this.matchedDescription,
  });
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.onSeeAllCourses, this.onSeeAllPaidCourses});

  final VoidCallback? onSeeAllCourses;
  final VoidCallback? onSeeAllPaidCourses;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  static const _background = Color(0xFFF5F7FA);
  static const _card = Colors.white;
  static const _text = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFF2E7DFF);
  static const _shadow = Color(0x0A000000);

  final ThinkCyberApi _api = ThinkCyberApi();
  final WishlistStore _wishlist = WishlistStore.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<CourseTopic> _topics = [];
  List<_ModuleSearchResult> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  String _userName = 'Explorer';
  String? _userEmail;
  double _completionRatio = 0;
  String _activeCategory = 'All';
  String _searchQuery = '';
  String _selectedLanguage = 'English'; // Track selected language
  String _searchHint = 'Search topics, categories...';

  // Selected category for filtering
  CourseCategory? _selectedCategory;
  
  // Pagination state
  int _currentPage = 0;
  static const int _topicsPerPage = 6;
  int _swipeDirection = 1; // 1 for right/next, -1 for left/previous

  List<String> _currentChips = [];
  Map<String, List<String>> _categorySubcats = {};
  bool _showingSubcats = false;
  String? _selectedSubcategoryName;
  
  // Plan-related state
  List<FeaturePlan> _plans = [];
  FeaturePlan? _selectedPlan;
  
  // Categories state (API-driven)
  List<CourseCategory> _categories = [];
  bool _categoriesLoading = false;
  late final VoidCallback _wishlistListener;
  final LocalizationService _localizationService = LocalizationService();
  
  // Track purchased bundles (categoryId -> true)
  Set<int> _purchasedBundleCategoryIds = {};

  // Razorpay for bundle purchase
  late Razorpay _razorpay;
  String? _currentBundleOrderId;
  int? _currentBundleCategoryId;
  bool _processingBundlePurchase = false;
  int? _userId;
  String? _userEmail2;

  @override
  void initState() {
    super.initState();
    _currentChips = ['All'];
    _updateSearchHint();
    _localizationService.addListener(_onLanguageChanged);
    _loadSelectedLanguage(); // Load saved language
    _loadPlans(); // Load available plans
    _loadCategoriesData(); // Load categories
    _hydrate();
    _wishlistListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _wishlist.addListener(_wishlistListener);
    _wishlist.hydrate();
    
    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleBundlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleBundlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleBundleExternalWallet);
    
    // Load user info for payment
    _loadUserInfo();
  }

  @override
  void dispose() {
    _api.dispose();
    _wishlist.removeListener(_wishlistListener);
    _localizationService.removeListener(_onLanguageChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _razorpay.clear();
    super.dispose();
  }
  
  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString('thinkcyber_user');
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final json = jsonDecode(rawUser);
        if (json is Map<String, dynamic>) {
          _userId = json['id'] as int?;
          _userEmail2 = json['email'] as String?;
        }
      } catch (_) {}
    }
    _userId ??= prefs.getInt('thinkcyber_user_id');
    _userEmail2 ??= prefs.getString('thinkcyber_email');
    
    // Load user's purchased bundles
    if (_userId != null) {
      _loadUserBundles();
    }
  }
  
  Future<void> _loadUserBundles() async {
    if (_userId == null) return;
    
    try {
      final bundles = await _api.fetchUserBundles(userId: _userId!);
      if (!mounted) return;
      
      final purchasedCategoryIds = <int>{};
      for (final bundle in bundles) {
        if (bundle.categoryId != null) {
          purchasedCategoryIds.add(bundle.categoryId!);
        }
      }
      
      setState(() {
        _purchasedBundleCategoryIds = purchasedCategoryIds;
      });
      
      debugPrint('✅ Loaded ${purchasedCategoryIds.length} purchased bundles: $purchasedCategoryIds');
    } catch (e) {
      debugPrint('Error loading user bundles: $e');
    }
  }

  void _onLanguageChanged() {
    print('🔄 Language changed in Dashboard, updating search hint...');
    _updateSearchHint();
  }

  Future<void> _loadPlans() async {
    try {
      final response = await _api.fetchFeaturePlans();
      if (!mounted) return;
      
      setState(() {
        _plans = response.data;
      });
    } catch (e) {
      debugPrint('Error loading plans: $e');
    }
  }

  Future<void> _loadCategoriesData() async {
    if (!mounted) return;
    setState(() => _categoriesLoading = true);
    
    try {
      final response = await _api.fetchCategories();
      if (!mounted) return;
      
      // Sort by display_order
      final sorted = response.data;
      sorted.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      
      setState(() {
        _categories = sorted;
        _categoriesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _categoriesLoading = false);
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _updateSearchHint() async {
    final translationService = TranslationService();
    final targetLang = _localizationService.languageCode;
    
    print('🌐 Updating search hint for language: $targetLang');
    
    if (targetLang == 'en') {
      if (mounted) {
        setState(() {
          _searchHint = 'Search topics, categories...';
        });
        print('✅ Search hint updated to: $_searchHint');
      }
    } else {
      final translated = await translationService.translate(
        'Search topics, categories...',
        'en',
        targetLang,
      );
      print('✅ Translated search hint: $translated');
      if (mounted) {
        setState(() {
          _searchHint = translated;
        });
        print('✅ Search hint state updated to: $_searchHint');
      }
    }
  }

  Future<void> _hydrate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedName = prefs.getString('thinkcyber_user_name');
      final storedEmail = prefs.getString('thinkcyber_email');
      final storedUserId = prefs.getInt('thinkcyber_user_id');

      // Fetch topics with userId to get basic enrollment info
      final response = await _api.fetchTopics(userId: storedUserId);
      var topics = response.topics;

      // Also fetch user enrollments separately for accurate enrollment status
      if (storedUserId != null && storedUserId > 0) {
        try {
          final enrolledTopics = await _api.fetchUserEnrollments(userId: storedUserId);
          final enrolledIds = enrolledTopics.map((t) => t.id).toSet();
          
          // Update topics to mark those that are enrolled
          topics = topics.map((topic) {
            if (enrolledIds.contains(topic.id)) {
              // Use copyWith to update isEnrolled while preserving all other fields
              return topic.copyWith(isEnrolled: true);
            }
            return topic;
          }).toList();
        } catch (e) {
          debugPrint('Error fetching user enrollments: $e');
          // Continue with the original topics if enrollment fetch fails
        }
      }

      if (!mounted) return;

      // Debug: Print all loaded courses and their properties
      for (var t in topics) {
        debugPrint('Course: ${t.title}, isFree: ${t.isFree}, price: ${t.price}, isEnrolled: ${t.isEnrolled}, status: ${t.status}');
      }
      
      final published = topics
          .where((t) => t.status.toLowerCase() == 'published')
          .length;
      final total = topics.length;
      final ratio = total == 0 ? 0.0 : (published / total).clamp(0.0, 1.0);

      Set<String> uniqueCats = topics.map((t) => t.categoryName).toSet();
      List<String> stringCategories = ['All', ...uniqueCats.toList()..sort()];

      _categorySubcats.clear();
      Map<String, Set<String>> tempSubcats = {};
      for (var topic in topics) {
        String cat = topic.categoryName;
        String sub = topic.subcategoryName ?? cat;
        tempSubcats.putIfAbsent(cat, () => <String>{}).add(sub);
      }
      for (var entry in tempSubcats.entries) {
        _categorySubcats[entry.key] = entry.value.toList()..sort();
      }

      if (!mounted) return;

      // Clear any active search when refreshing/hydrating topics
      _searchController.clear();
      setState(() {
        _topics = topics;
        _completionRatio = ratio;
        _userEmail = storedEmail;
        _userName = (storedName ?? storedEmail ?? 'Explorer').trim();
        _currentChips = stringCategories;  // Keep _currentChips as string categories for filtering
        _isLoading = false;
        _isSearching = false;
        _searchResults = [];
        _searchQuery = '';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to load topics right now. Please try again shortly.';
        _isLoading = false;
      });
    }
    
    // Also refresh categories from API
    await _loadCategoriesData();
  }

  // Helper method to extract description snippet around the match
  String _extractDescriptionSnippet(String description, String searchQuery) {
    final lowerDesc = description.toLowerCase();
    final queryLower = searchQuery.toLowerCase();
    final matchIndex = lowerDesc.indexOf(queryLower);
    
    if (matchIndex == -1) return description.length > 100 ? '${description.substring(0, 100)}...' : description;
    
    // Extract snippet around the match (50 chars before and after)
    final start = (matchIndex - 50).clamp(0, description.length);
    final end = (matchIndex + queryLower.length + 50).clamp(0, description.length);
    
    String snippet = description.substring(start, end);
    
    // Add ellipsis if we're not at the beginning/end
    if (start > 0) snippet = '...$snippet';
    if (end < description.length) snippet = '$snippet...';
    
    return snippet;
  }

  // Helper method to create highlighted text with matched terms in bold
  Widget _buildHighlightedText(String text, String searchQuery) {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF4B5563),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final matches = <TextSpan>[];
    
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          matches.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      
      // Add text before match
      if (index > start) {
        matches.add(TextSpan(text: text.substring(start, index)));
      }
      
      // Add highlighted match
      matches.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F2937), // Dark text
          backgroundColor: Color(0xFFFEF08A), // Yellow highlight
        ),
      ));
      
      start = index + searchQuery.length;
    }
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF4B5563),
          fontStyle: FontStyle.italic,
        ),
        children: matches,
      ),
    );
  }

  Future<void> _onSearchChanged(String query) async {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      _isSearching = _searchQuery.isNotEmpty;
    });
    
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    List<_ModuleSearchResult> results = [];
    
    for (final topic in _topics) {
      String? matchingModuleTitle;
      String? matchingVideoTitle;
      bool topicMatches = false;
      
      // Check topic-level matches
      if (topic.title.toLowerCase().contains(_searchQuery) ||
          topic.categoryName.toLowerCase().contains(_searchQuery) ||
          (topic.subcategoryName?.toLowerCase().contains(_searchQuery) ?? false) ||
          (topic.description?.toLowerCase().contains(_searchQuery) ?? false)) {
        topicMatches = true;
      }
      
      // If no topic match, search in modules and videos
      bool isDescriptionMatch = false;
      String? matchedDescriptionText;
      if (!topicMatches) {
        try {
          final detailResp = await _api.fetchTopicDetail(topic.id);
          final modules = detailResp.topic.modules;
          
          for (final module in modules) {
            // Check module title
            if (module.title.toLowerCase().contains(_searchQuery)) {
              matchingModuleTitle = module.title;
              break;
            }
            
            // Check module description
            if (module.description.toLowerCase().contains(_searchQuery)) {
              matchingModuleTitle = module.title;
              isDescriptionMatch = true;
              // Extract a snippet around the match for display
              matchedDescriptionText = _extractDescriptionSnippet(module.description, _searchQuery);
              break;
            }
            
            // Check video titles in this module
            for (final video in module.videos) {
              if (video.title.toLowerCase().contains(_searchQuery)) {
                matchingModuleTitle = module.title;
                matchingVideoTitle = video.title;
                break;
              }
            }
            if (matchingModuleTitle != null) break;
          }
        } catch (e) {
          print('Error fetching details for topic ${topic.title}: $e');
        }
      }
      
      // Add to results if there's any match
      if (topicMatches || matchingModuleTitle != null) {
        results.add(_ModuleSearchResult(
          topic: topic,
          matchingModuleTitle: matchingModuleTitle,
          matchingVideoTitle: matchingVideoTitle,
          isModuleDescriptionMatch: isDescriptionMatch,
          matchedDescription: matchedDescriptionText,
        ));
      }
    }
    
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
    }
  }

  void _navigateToTopic(CourseTopic topic) {
    // Clear search when navigating
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchResults = [];
    });
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopicDetailScreen(topic: topic),
      ),
    );
  }

  List<CourseTopic> get _filteredTopics {
    // If a category is selected from the new category cards, filter by that
    if (_selectedCategory != null) {
      return _topics
          .where((t) => t.categoryName == _selectedCategory!.name)
          .toList();
    }
    
    if (_activeCategory == 'All') {
      if (_showingSubcats && _selectedCategory != null) {
        return _topics
            .where((t) => t.categoryName == _selectedCategory!.name)
            .toList();
      } else {
        return _topics;
      }
    }
    if (_showingSubcats && _selectedCategory != null) {
      return _topics
          .where(
            (t) =>
                t.categoryName == _selectedCategory!.name &&
                t.subcategoryName == _activeCategory,
          )
          .toList();
    } else {
      return _topics.where((t) => t.categoryName == _activeCategory).toList();
    }
  }

  void _navigateToAllCourses({bool showPaidTab = false}) {
    if (showPaidTab) {
      widget.onSeeAllPaidCourses?.call();
    } else {
      widget.onSeeAllCourses?.call();
    }
  }

  // Load selected language from SharedPreferences
  Future<void> _loadSelectedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('selected_language');
      if (savedLanguage != null && mounted) {
        setState(() {
          _selectedLanguage = savedLanguage;
        });
      }
    } catch (e) {
      print('Error loading selected language: $e');
    }
  }

  // Save selected language to SharedPreferences
  Future<void> _saveSelectedLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', language);
    } catch (e) {
      print('Error saving selected language: $e');
    }
  }

  // Test translation functionality
  Future<void> _testTranslation(String selectedLanguage) async {
    print('Testing translation for: $selectedLanguage');
    
    String targetCode = 'en'; // Default to English
    if (selectedLanguage == 'हिन्दी') {
      targetCode = 'hi';
    } else if (selectedLanguage == 'తెలుగు') {
      targetCode = 'te';
    }
    
    if (targetCode != 'en') {
      try {
        final translationService = TranslationService();
        final testTexts = [
          'Find a source you want to learn!',
          'Welcome to ThinkCyber',
          'Cybersecurity Training',
          'Start Learning Today'
        ];
        
        for (final text in testTexts) {
          final translation = await translationService.translate(text, 'en', targetCode);
          print('Translated "$text" to "$translation"');
        }
      } catch (e) {
        print('Translation test error: $e');
      }
    }
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TranslatedText(
              'Select Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 20),
            
            // English
            _buildSimpleLanguageOption('English', '🇺🇸', _selectedLanguage == 'English'),
            const SizedBox(height: 12),
            
            // Hindi
            _buildSimpleLanguageOption('हिन्दी', '🇮🇳', _selectedLanguage == 'हिन्दी'),
            const SizedBox(height: 12),
            
            // Telugu
            _buildSimpleLanguageOption('తెలుగు', '🇮🇳', _selectedLanguage == 'తెలుగు'),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLanguageOption(String language, String flag, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        // Update selected language and save it
        setState(() {
          _selectedLanguage = language;
        });
        await _saveSelectedLanguage(language);
        
        // ✅ Update LocalizationService to trigger app-wide language change
        final localizationService = LocalizationService();
        AppLanguage newLanguage = AppLanguage.english;
        if (language == 'हिन्दी') {
          newLanguage = AppLanguage.hindi;
        } else if (language == 'తెలుగు') {
          newLanguage = AppLanguage.telugu;
        }
        await localizationService.changeLanguage(newLanguage);
        
        Navigator.pop(context);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Language changed to $language'),
              backgroundColor: const Color(0xFF2E7DFF),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          
          // Test translation by translating the welcome message
          _testTranslation(language);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7DFF).withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF2E7DFF) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                language,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? const Color(0xFF2E7DFF) : const Color(0xFF2D3142),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2E7DFF),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _hydrate,
          color: _accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                // Main Content
                if (_isSearching) ...[
                  const SizedBox(height: 12),
                  _buildSearchResults(),
                ]
                else ...[
                  const SizedBox(height: 12),
                  _buildCategoriesSection(),
                  const SizedBox(height: 28),
                  _buildModernTopicsGrid(),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    if (_categoriesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 150,
          child: Center(
            child: TranslatedText(
              'No categories available',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'Categories',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _text,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory?.id == category.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildCategoryCardHorizontal(category, isSelected),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCardHorizontal(CourseCategory category, bool isSelected) {
    final planType = category.planType;
    final bundlePrice = double.tryParse(category.bundlePrice) ?? 0;
    
    // Calculate actual topic count from loaded topics
    final actualTopicCount = _topics
        .where((t) => t.categoryName == category.name)
        .length;
    
    final colorMap = {
      'FREE': {
        'primary': const Color(0xFF10B981),
        'light': const Color(0xFFDCFCE7),
      },
      'BUNDLE': {
        'primary': const Color(0xFFF59E0B),
        'light': const Color(0xFFFEF3C7),
      },
      'FLEXIBLE': {
        'primary': const Color(0xFF6366F1),
        'light': const Color(0xFFEEF2FF),
      },
    };

    final colors = colorMap[planType] ?? colorMap['FLEXIBLE']!;
    final primaryColor = colors['primary'] as Color;
    final lightColor = colors['light'] as Color;

    IconData getPlanIcon() {
      switch (planType) {
        case 'FREE':
          return Icons.card_giftcard_rounded;
        case 'BUNDLE':
          return Icons.card_giftcard_rounded;
        case 'FLEXIBLE':
          return Icons.tune_rounded;
        default:
          return Icons.star_rounded;
      }
    }

    String getPlanType() {
      switch (planType) {
        case 'FREE':
          return 'FREE';
        case 'BUNDLE':
          return 'BUNDLE';
        case 'FLEXIBLE':
          return 'FLEXIBLE';
        default:
          return 'PLAN';
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedCategory = null;
          } else {
            _selectedCategory = category;
            _currentPage = 0; // Reset to first page when category changes
          }
        });
      },
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: primaryColor.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon, Title, Topics, and Price in Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Icon(
                        getPlanIcon(),
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title and Topics
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plan Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: TranslatedText(
                            getPlanType(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TranslatedText(
                          category.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Topics count inline
                        Row(
                          children: [
                            Icon(
                              Icons.library_books_rounded,
                              size: 12,
                              color: primaryColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            TranslatedText(
                              '$actualTopicCount topics',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Price or Free on the right
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: TranslatedText(
                      bundlePrice > 0 ? '₹${bundlePrice.toStringAsFixed(0)}' : 'Free',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTopicsGrid() {
    if (_isLoading && _topics.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: LottieLoader(
            width: 120,
            height: 120,
          ),
        ),
      );
    }

    if (_errorMessage != null && _topics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _ErrorCard(message: _errorMessage!, onRetry: _hydrate),
      );
    }

    final filtered = _filteredTopics;

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyCard(onRetry: _hydrate),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bundle Purchase Section - Show when category is selected
          if (_selectedCategory != null) ...[
            _buildBundlePurchaseSection(),
            const SizedBox(height: 24),
          ],
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(
                'Available Topics',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToAllCourses(),
                child: const TranslatedText(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    color: _accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Calculate pagination
          Builder(
            builder: (context) {
              final totalPages = (filtered.length / _topicsPerPage).ceil();
              final startIndex = _currentPage * _topicsPerPage;
              final endIndex = (startIndex + _topicsPerPage).clamp(0, filtered.length);
              final pageTopics = filtered.sublist(startIndex, endIndex);
              
              return Column(
                children: [
                  // Pagination dots at top
                  if (totalPages > 1) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalPages, (index) {
                        final isActive = _currentPage == index;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _accent
                                  : const Color(0xFFD1D5DB),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: _accent.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    // Page counter text
                    TranslatedText(
                      'Page ${_currentPage + 1} of $totalPages',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Swipeable grid with smooth animation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 700),
                    transitionBuilder: (child, animation) {
                      // Animate based on swipe direction
                      final beginOffset = _swipeDirection > 0 
                        ? const Offset(1, 0)    // Swipe left (next): slide from right
                        : const Offset(-1, 0);  // Swipe right (previous): slide from left
                      
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: beginOffset,
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                        ),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      key: ValueKey<int>(_currentPage),
                      onHorizontalDragEnd: (DragEndDetails details) {
                        // Swipe right to previous page
                        if (details.primaryVelocity! > 0) {
                          if (_currentPage > 0) {
                            setState(() {
                              _swipeDirection = -1; // Swiping right (previous)
                              _currentPage--;
                            });
                          }
                        }
                        // Swipe left to next page
                        else if (details.primaryVelocity! < 0) {
                          if (_currentPage < totalPages - 1) {
                            setState(() {
                              _swipeDirection = 1; // Swiping left (next)
                              _currentPage++;
                            });
                          }
                        }
                      },
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: pageTopics.length,
                        itemBuilder: (context, index) {
                          final topic = pageTopics[index];
                          return _buildModernTopicCard(topic);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBundlePurchaseSection() {
    if (_selectedCategory == null) return const SizedBox.shrink();
    
    final planType = _selectedCategory!.planType;
    
    // Only show bundle section for BUNDLE and FLEXIBLE plans
    if (planType == 'FREE' || planType == 'INDIVIDUAL') {
      return const SizedBox.shrink();
    }
    
    // Get the bundle price for this category - handle String to double conversion
    final bundlePrice = double.tryParse(_selectedCategory!.bundlePrice?.toString() ?? '0') ?? 0.0;
    // Calculate actual topic count from loaded topics
    final topicsCount = _topics
        .where((t) => t.categoryName == _selectedCategory!.name)
        .length;
    
    // Get category icon/emoji
    final categoryIconEmoji = _getCategoryEmoji(_selectedCategory!.name);
    
    // Check if bundle is already purchased
    final isBundlePurchased = _purchasedBundleCategoryIds.contains(_selectedCategory!.id);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF0F4FF),
            const Color(0xFFE8EEFF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0E7FF),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with category icon and name
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0E7FF),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    categoryIconEmoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      _selectedCategory!.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (planType == 'BUNDLE') ...[
                          const Icon(
                            Icons.card_giftcard_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          TranslatedText(
                            'Bundle Package',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else ...[
                          const Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 4),
                          TranslatedText(
                            'Flexible Package',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TranslatedText(
                          'Access all $topicsCount topics',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Price info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (bundlePrice > 0 && !isBundlePurchased) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(
                        'Bundle Price',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        '₹${bundlePrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D6EFD),
                        ),
                      ),
                      const SizedBox(height: 2),
                      TranslatedText(
                        'for all $topicsCount topics = ₹${(bundlePrice / topicsCount).toStringAsFixed(0)}/topic',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ] else if (isBundlePurchased) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xFF10B981),
                                ),
                                SizedBox(width: 4),
                                TranslatedText(
                                  'Purchased',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TranslatedText(
                        'You have access to all $topicsCount topics',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Buy Bundle or View Topics Button
              GestureDetector(
                onTap: () {
                  if (isBundlePurchased) {
                    // Navigate to bundle topics
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BundleTopicsDetailScreen(
                          categoryId: _selectedCategory!.id,
                          categoryName: _selectedCategory!.name,
                          userId: _userId ?? 0,
                        ),
                      ),
                    );
                  } else {
                    // Show purchase dialog
                    _showBundlePurchaseDialog();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isBundlePurchased
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF0D6EFD), const Color(0xFF0853E8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isBundlePurchased 
                            ? const Color(0xFF10B981) 
                            : const Color(0xFF0D6EFD)).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBundlePurchased 
                            ? Icons.play_circle_outline_rounded
                            : Icons.shopping_bag_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      TranslatedText(
                        isBundlePurchased ? 'View Topics' : 'Buy Bundle',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBundlePurchaseDialog() {
    if (_selectedCategory == null) return;
    
    final planType = _selectedCategory!.planType;
    final includeFutureTopics = planType == 'BUNDLE'; // Only BUNDLE includes future topics
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: TranslatedText(
          'Purchase ${_selectedCategory!.name} Bundle?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TranslatedText(
              'You will get instant access to:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TranslatedText(
                    'All ${_selectedCategory!.topicsCount} topics in this category',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  includeFutureTopics ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: includeFutureTopics ? const Color(0xFF10B981) : const Color(0xFFFCA5A5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TranslatedText(
                    'Future topics added to this category',
                    style: TextStyle(
                      fontSize: 13,
                      color: includeFutureTopics ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TranslatedText(
                    'Annual access to all materials',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D6EFD),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: _processingBundlePurchase ? null : () {
              Navigator.pop(context);
              // Start bundle purchase with Razorpay
              _startBundlePurchase();
            },
            child: _processingBundlePurchase 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const TranslatedText(
                  'Confirm Purchase',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _startBundlePurchase() async {
    if (_selectedCategory == null || _userId == null || _userEmail2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Please login to purchase')),
      );
      return;
    }
    
    setState(() => _processingBundlePurchase = true);
    
    try {
      debugPrint('✅ Razorpay | Creating bundle order...');
      
      // Create order via backend
      final orderData = await _api.createOrderForBundle(
        userId: _userId!,
        categoryId: _selectedCategory!.id,
        email: _userEmail2!,
      );
      
      final orderId = orderData['orderId'] as String?;
      final keyId = orderData['keyId'] as String?;
      final amount = orderData['amount'] as num?;
      
      if (orderId == null || keyId == null) {
        throw Exception('Invalid order response from backend');
      }
      
      debugPrint('✅ Razorpay | Bundle order created: $orderId');
      
      // Store for verification
      _currentBundleOrderId = orderId;
      _currentBundleCategoryId = _selectedCategory!.id;
      
      // Get bundle price
      final bundlePrice = double.tryParse(_selectedCategory!.bundlePrice?.toString() ?? '0') ?? 0.0;
      final amountInPaise = amount ?? (bundlePrice * 100).toInt();
      
      // Open Razorpay
      var options = {
        'key': keyId,
        'amount': amountInPaise,
        'name': RazorpayConfig.merchantName,
        'description': '${_selectedCategory!.name} Bundle',
        'order_id': orderId,
        'prefill': {
          'contact': '',
          'email': _userEmail2,
        },
        'external': {
          'wallets': RazorpayConfig.supportedWallets,
        }
      };
      
      _razorpay.open(options);
    } catch (e) {
      debugPrint('❌ Razorpay | Error creating bundle order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _processingBundlePurchase = false);
      }
    }
  }
  
  void _handleBundlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('✅ Razorpay | Bundle Payment Success - PaymentId: ${response.paymentId}');
    
    final messenger = ScaffoldMessenger.of(context);
    final orderId = _currentBundleOrderId;
    final categoryId = _currentBundleCategoryId;
    
    if (_userId == null || orderId == null || categoryId == null) {
      debugPrint('❌ Razorpay | Missing userId, orderId, or categoryId');
      messenger.showSnackBar(
        const SnackBar(content: TranslatedText('Payment successful!')),
      );
      setState(() => _processingBundlePurchase = false);
      return;
    }
    
    try {
      debugPrint('✅ Razorpay | Verifying bundle payment...');
      
      final enrollResponse = await _api.verifyBundlePaymentAndEnroll(
        userId: _userId!,
        categoryId: categoryId,
        paymentId: response.paymentId!,
        orderId: orderId,
        signature: response.signature!,
      );
      
      if (!mounted) return;
      
      if (enrollResponse.success) {
        debugPrint('✅ Razorpay | Bundle payment verified and enrolled!');
        messenger.showSnackBar(
          const SnackBar(
            content: TranslatedText('Bundle purchased! You now have access to all topics.'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 3),
          ),
        );
        
        // Add the purchased category to the set immediately for instant UI update
        setState(() {
          _purchasedBundleCategoryIds.add(categoryId);
        });
        
        // Refresh data to reflect new enrollments
        _loadUserBundles();
        _hydrate();
      } else {
        debugPrint('❌ Razorpay | Bundle verification failed: ${enrollResponse.message}');
        messenger.showSnackBar(
          SnackBar(content: Text('Error: ${enrollResponse.message}')),
        );
      }
    } catch (e) {
      debugPrint('❌ Razorpay | Error verifying bundle payment: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingBundlePurchase = false);
      }
    }
  }
  
  void _handleBundlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Razorpay | Bundle Payment Error - ${response.code}: ${response.message}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message ?? 'Cancelled'}')),
    );
    setState(() => _processingBundlePurchase = false);
  }
  
  void _handleBundleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay | External Wallet: ${response.walletName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  String _getCategoryEmoji(String categoryName) {
    final emojiMap = {
      'Cyber Entry (Fundamentals)': '🎁',
      'Cyber Expert (Professional)': '📦',
      'Cyber Explorer (Intermediate)': '🔍',
      'Security': '🔒',
      'Cryptography': '🔐',
      'Network Security': '🌐',
      'Malware Analysis': '🦠',
      'Penetration Testing': '🎯',
      'Cloud Security': '☁️',
      'Incident Response': '🚨',
    };
    return emojiMap[categoryName] ?? '📚';
  }

  Widget _buildModernTopicCard(CourseTopic topic) {
    final isFree = topic.isFree;
    
    // Determine plan type for the current category
    final planType = _selectedCategory?.planType ?? 'INDIVIDUAL';
    
    // Only show "Free" tag for FREE plan type, never for BUNDLE or FLEXIBLE
    final showFreeTag = isFree && planType == 'FREE';
    
    // For BUNDLE/FLEXIBLE, don't show price tags either (it's part of bundle)
    final showPriceTag = planType == 'INDIVIDUAL' || planType == 'FREE';
    
    // Check if user has access via bundle purchase or individual enrollment
    final hasBundleAccess = _purchasedBundleCategoryIds.contains(
      _categories.firstWhere(
        (c) => c.name == topic.categoryName,
        orElse: () => CourseCategory(id: 0, name: '', description: '', topicsCount: 0, displayOrder: 0, planType: '', bundlePrice: '0', price: '0', flexiblePurchase: false),
      ).id
    );
    final isEnrolled = topic.isEnrolled || hasBundleAccess;
    
    return GestureDetector(
      onTap: () => _navigateToTopic(topic),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic Image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  color: const Color(0xFFF0F4F8),
                ),
                child: Stack(
                  children: [
                    TopicImage(
                      imageUrl: topic.thumbnailUrl,
                      title: topic.title,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                    // Only show tags for INDIVIDUAL or FREE plan types
                    if (showPriceTag) ...[
                      if (showFreeTag)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const TranslatedText(
                              'Free',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else if (!isFree && planType == 'INDIVIDUAL')
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TranslatedText(
                              '₹${topic.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            // Card Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title in blue with icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D6EFD).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF0D6EFD),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TranslatedText(
                          topic.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D6EFD),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Description
                  if (topic.description.isNotEmpty)
                    TranslatedText(
                      topic.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (topic.description.isNotEmpty) const SizedBox(height: 8),
                  // Category and difficulty badges
                  Row(
                    children: [
                      if (topic.categoryName.isNotEmpty)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: TranslatedText(
                              topic.categoryName,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if (topic.difficulty.isNotEmpty) const SizedBox(width: 4),
                      if (topic.difficulty.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(topic.difficulty).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: TranslatedText(
                            topic.difficulty,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getDifficultyColor(topic.difficulty),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress or enrollment status
                  if (isEnrolled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: TranslatedText(
                          'Enrolled',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF10B981);
      case 'intermediate':
        return const Color(0xFF0EA5E9);
      case 'advanced':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildPlanBanner() {
    if (_plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6366F1),
              const Color(0xFF4F46E5),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            TranslatedText(
              'Select Your Learning Plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            TranslatedText(
              'Choose a plan to access topics and courses',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFE0E7FF),
              ),
            ),
          ],
        ),
      );
    }

    // Show random plan or featured plan
    final planToShow = _selectedPlan ?? _plans.first;
    final planType = PlanClassifier.classifyPlan(planToShow);
    
    final colors = {
      PlanType.free: const Color(0xFF10B981),
      PlanType.bundleOnly: const Color(0xFF0EA5E9),
      PlanType.flexible: const Color(0xFF6366F1),
      PlanType.individualOnly: const Color(0xFFF59E0B),
    };

    final cardColor = colors[planType]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor,
            cardColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TranslatedText(
                    _selectedPlan != null ? 'Current Plan' : 'Featured Plan',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TranslatedText(
                  planToShow.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TranslatedText(
                  planToShow.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1), // Purple-blue
            const Color(0xFF4F46E5), // Indigo
            const Color(0xFF2563EB), // Blue
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Top bar with user icon on left and other icons on right
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // User Account Icon - left side
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AccountScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              
                // Right side icons
                Row(
                  children: [
                    // Wishlist Icon
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const WishlistScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Cart Icon
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Language Icon
                    GestureDetector(
                      onTap: () {
                        _showLanguageSelector(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.g_translate,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    
                    // Notification Icon with badge - Hidden for now
                    // GestureDetector(
                    //   onTap: () {
                    //     Navigator.of(context).push(
                    //       MaterialPageRoute(
                    //         builder: (context) => const NotificationScreen(),
                    //       ),
                    //     );
                    //   },
                    //   child: Stack(
                    //     children: [
                    //       Container(
                    //         padding: const EdgeInsets.all(10),
                    //         decoration: BoxDecoration(
                    //           color: Colors.white.withOpacity(0.25),
                    //           borderRadius: BorderRadius.circular(12),
                    //           border: Border.all(
                    //             color: Colors.white.withOpacity(0.3),
                    //             width: 1,
                    //           ),
                    //         ),
                    //         child: const Icon(
                    //           Icons.notifications_outlined,
                    //           color: Colors.white,
                    //           size: 20,
                    //         ),
                    //       ),
                    //       Positioned(
                    //         top: 8,
                    //         right: 8,
                    //         child: Container(
                    //           width: 8,
                    //           height: 8,
                    //           decoration: BoxDecoration(
                    //             color: const Color(0xFFFF4444),
                    //             shape: BoxShape.circle,
                    //             border: Border.all(
                    //               color: Colors.white,
                    //               width: 1.5,
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ],
            ),
          ),
          
          // Greeting section below icons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const TranslatedText(
                            'Hi',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: TranslatedText(
                              '$_userName!',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('👋', style: TextStyle(fontSize: 26)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const TranslatedText(
                        'Let\'s Start Learning',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Search bar integrated in header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                key: ValueKey(_searchHint),
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: _searchHint,
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF6366F1),
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                            setState(() {
                              _searchQuery = '';
                              _isSearching = false;
                              _searchResults = [];
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: _onSearchChanged,
                onTap: () {
                  if (_searchController.text.isNotEmpty && !_isSearching) {
                    setState(() {
                      _isSearching = true;
                    });
                  }
                },
              ),
            ),
          ),
          // Add tap outside detector for search
          if (_isSearching)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _searchFocusNode.unfocus();
                  setState(() {
                    _isSearching = false;
                    _searchResults = [];
                  });
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    key: ValueKey(_searchHint),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _text,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: _searchHint,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: _muted.withValues(alpha: 0.6),
                        size: 20,
                      ),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: _muted.withValues(alpha: 0.6),
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                                _searchFocusNode.unfocus();
                                // Only set _isSearching to false if the search box is empty
                                setState(() {
                                  if (_searchController.text.isEmpty) {
                                    _isSearching = false;
                                  }
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Search Results Dropdown
          if (_isSearching && _searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: _shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: _muted.withValues(alpha: 0.1),
                ),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  final topic = result.topic;
                  final matchingModuleTitle = result.matchingModuleTitle;
                  final matchingVideoTitle = result.matchingVideoTitle;
                  
                  return ListTile(
                    onTap: () => _navigateToTopic(topic),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: TopicImage(
                          imageUrl: topic.thumbnailUrl,
                          title: topic.title,
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                    title: matchingModuleTitle != null
                        ? Text(
                            matchingVideoTitle ?? matchingModuleTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueAccent,
                            ),
                          )
                        : TranslatedText(
                            topic.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    subtitle: matchingModuleTitle != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TranslatedText(
                                topic.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              if (matchingVideoTitle != null)
                                Text(
                                  'Module: $matchingModuleTitle',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          )
                        : TranslatedText(
                            topic.categoryName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                            ),
                          ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: _muted.withValues(alpha: 0.5),
                    ),
                  );
                },
              ),
            ),
          // No Results Message
          if (_isSearching && _searchResults.isEmpty && _searchQuery.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: _shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_off,
                    color: _muted.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'No topics found for "$_searchQuery"',
                    style: TextStyle(
                      fontSize: 14,
                      color: _muted.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Results
          if (_searchResults.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: _shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: _muted.withValues(alpha: 0.1),
                ),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  final topic = result.topic;
                  final matchingModuleTitle = result.matchingModuleTitle;
                  final matchingVideoTitle = result.matchingVideoTitle;
                  final isModuleDescMatch = result.isModuleDescriptionMatch;
                  final matchedDescription = result.matchedDescription;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: InkWell(
                      onTap: () => _navigateToTopic(topic),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Topic Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: TopicImage(
                                  imageUrl: topic.thumbnailUrl,
                                  title: topic.title,
                                  width: 48,
                                  height: 48,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Main Title
                                  if (matchingModuleTitle != null)
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: matchingVideoTitle != null 
                                                ? const Color(0xFFFEF3C7)  // Yellow for videos
                                                : const Color(0xFFDCFCE7), // Green for modules
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            matchingVideoTitle != null 
                                                ? Icons.play_circle_outline 
                                                : Icons.article_outlined,
                                            size: 14,
                                            color: matchingVideoTitle != null 
                                                ? const Color(0xFFD97706) 
                                                : const Color(0xFF059669),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            matchingVideoTitle ?? matchingModuleTitle,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1F2937),
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    TranslatedText(
                                      topic.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1F2937),
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  
                                  const SizedBox(height: 6),
                                  
                                  // Topic Title (when showing module/video match)
                                  if (matchingModuleTitle != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.topic_outlined,
                                          size: 12,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: TranslatedText(
                                            topic.title,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF6B7280),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  
                                  // Match Type Badge
                                  if (matchingModuleTitle != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: matchingVideoTitle != null
                                                  ? const Color(0xFFFEF3C7) // Yellow for video
                                                  : isModuleDescMatch
                                                      ? const Color(0xFFDCFCE7) // Green for description
                                                      : const Color(0xFFDBEAFE), // Blue for title
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: matchingVideoTitle != null
                                                    ? const Color(0xFFEAB308)
                                                    : isModuleDescMatch
                                                        ? const Color(0xFF059669)
                                                        : const Color(0xFF3B82F6),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              matchingVideoTitle != null
                                                  ? 'Video Match'
                                                  : isModuleDescMatch
                                                      ? 'Description Match'
                                                      : 'Module Match',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: matchingVideoTitle != null
                                                    ? const Color(0xFFD97706)
                                                    : isModuleDescMatch
                                                        ? const Color(0xFF059669)
                                                        : const Color(0xFF3B82F6),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  // Description Snippet
                                  if (matchedDescription != null && matchedDescription.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.format_quote,
                                                size: 12,
                                                color: const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Matched Content:',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          _buildHighlightedText(matchedDescription, _searchQuery),
                                        ],
                                      ),
                                    ),
                                  
                                  // Category (for topic-level matches)
                                  if (matchingModuleTitle == null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.category_outlined,
                                            size: 12,
                                            color: const Color(0xFF9CA3AF),
                                          ),
                                          const SizedBox(width: 4),
                                          TranslatedText(
                                            topic.categoryName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            // Arrow Icon
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: const Color(0xFFD1D5DB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // No Results Message
          if (_searchResults.isEmpty && _searchQuery.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: _shadow,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    color: _muted.withValues(alpha: 0.5),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  TranslatedText(
                    'No results found for "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 👉 Fixed Categories Layout with Wrap
  Widget _buildCategories() {
    final isSub = _showingSubcats && _selectedSubcategoryName != null;
    final items = _currentChips;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TranslatedText(
                  isSub ? "$_selectedSubcategoryName Subcategories" : "Categories",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSub)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _showingSubcats = false;
                    _selectedSubcategoryName = null;
                    _activeCategory = 'All';
                    _currentChips = ['All'];
                  }),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                  label: const TranslatedText("Back"),
                ),
            ],
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items.map((chip) {
                final isActive = _activeCategory == chip;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _activeCategory = chip);
                      if (!_showingSubcats &&
                          chip != 'All' &&
                          _categorySubcats.containsKey(chip)) {
                        setState(() {
                          _selectedSubcategoryName = chip;
                          _showingSubcats = true;
                          _currentChips = [
                            'All',
                            ...(_categorySubcats[chip] ?? []),
                          ];
                          _activeCategory = 'All';
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _accent.withValues(alpha: 0.1)
                            : const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? _accent : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getCategoryIcon(chip, isSub: isSub),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          TranslatedText(
                            chip,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isActive ? _accent : _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryIcon(String category, {bool isSub = false}) {
    if (isSub) return '📖';
    switch (category.toLowerCase()) {
      case 'all':
        return '📚';
      case 'cybersecurity':
      case 'cybersecurity fundamentals':
        return '🔒';
      case 'network security':
        return '🌐';
      case 'ethical hacking':
        return '💻';
      default:
        return '📖';
    }
  }

  Future<void> _toggleWishlist(CourseTopic topic) async {
    final added = await _wishlist.toggleCourse(summary: topic);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TranslatedText(added ? 'Added to wishlist' : 'Removed from wishlist'),
      ),
    );
  }

  Widget _buildPopularCourses() {
    if (_isLoading && _topics.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: LottieLoader(
            width: 120,
            height: 120,
          ),
        ),
      );
    }
    if (_errorMessage != null && _topics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _ErrorCard(message: _errorMessage!, onRetry: _hydrate),
      );
    }

    final filtered = _filteredTopics;
    final featured = filtered.where((t) => !t.isFree && t.price > 0).toList();
        // Debug: Print all filtered paid courses
        for (var t in featured) {
          debugPrint('PAID COURSE: ${t.title}, isFree: ${t.isFree}, price: ${t.price}, status: ${t.status}');
        }
    
    // Debug: Print information about courses
    debugPrint('Dashboard: Total courses: ${filtered.length}, Paid courses: ${featured.length}');
    if (filtered.isNotEmpty) {
      debugPrint('Dashboard: Sample courses:');
      for (var i = 0; i < filtered.length && i < 3; i++) {
        debugPrint('  ${i+1}. ${filtered[i].title} - Price: ${filtered[i].price}, IsFree: ${filtered[i].isFree}');
      }
    }

    if (featured.isEmpty) {
      if (filtered.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _EmptyCard(onRetry: _hydrate),
        );
      }
      // Show section even with no paid courses for debugging
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TranslatedText(
                    "Featured Topics (No courses available)",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _activeCategory = 'All');
                    _navigateToAllCourses();
                  },
                  child: const TranslatedText(
                    "See All",
                    style: TextStyle(
                      fontSize: 12,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "No featured topics available at the moment.",
              style: TextStyle(color: _muted),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TranslatedText(
                  "Featured Topics",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _activeCategory = 'All');
                  _navigateToAllCourses(showPaidTab: true);
                },
                child: const TranslatedText(
                  "See All",
                  style: TextStyle(
                    fontSize: 12,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 235,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final course = featured[index];
              return _PopularCourseCard(
                topic: course,
                isWishlisted: _wishlist.contains(course.id),
                onToggleWishlist: () => _toggleWishlist(course),
              );
            },
          ),
        ),
      ],
    );
  }

  // 👉 All Topics horizontal carousel
  Widget _buildAllTopics() {
    final filtered = _filteredTopics;
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const TranslatedText(
                "All Topics",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _activeCategory = 'All');
                  _navigateToAllCourses();
                },
                child: const TranslatedText(
                  "See All",
                  style: TextStyle(
                    fontSize: 12,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 235,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final course = filtered[index];
                return _PopularCourseCard(
                  topic: course,
                  isWishlisted: _wishlist.contains(course.id),
                  onToggleWishlist: () => _toggleWishlist(course),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularCourseCard extends StatelessWidget {
  final CourseTopic topic;
  final bool isWishlisted;
  final VoidCallback onToggleWishlist;
  final double? width;
  const _PopularCourseCard({
    required this.topic,
    required this.isWishlisted,
    required this.onToggleWishlist,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final heroTag = topicHeroTag(topic.id, 'popular');
    final isFree = topic.isFree || topic.price == 0;
    final bool isOwned = topic.isEnrolled;

    String priceText(num value) {
      if (value % 1 == 0) {
        return '₹${value.toInt()}';
      }
      return '₹${value.toStringAsFixed(2)}';
    }

    final String priceLabel = isOwned
        ? 'Enrolled'
        : (isFree ? 'Free' : priceText(topic.price));
    final Color priceColor = isOwned
        ? const Color(0xFF22C55E)
        : (isFree ? Colors.green : _DashboardState._accent);

    Widget _buildThumbnail() {
      return TopicImage(
        imageUrl: topic.thumbnailUrl,
        title: topic.title,
      );
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TopicDetailScreen(topic: topic)),
        );
        // Refresh dashboard when returning from detail screen
        final state = context.findAncestorStateOfType<_DashboardState>();
        state?._hydrate();
      },
      child: Container(
        width: width ?? 170,
        decoration: BoxDecoration(
          color: _DashboardState._card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: _DashboardState._shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Hero(
                    tag: heroTag,
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: _buildThumbnail(),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _WishlistIconButton(
                    isActive: isWishlisted,
                    onTap: onToggleWishlist,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: priceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TranslatedText(
                      priceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TranslatedText(
                      topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _DashboardState._text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TranslatedText(
                      "by ${topic.categoryName}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _DashboardState._muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_circle_outline,
                          size: 12,
                          color: _DashboardState._accent,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TranslatedText(
                            "${topic.durationMinutes} min",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: _DashboardState._accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          "4.5",
                          style: TextStyle(
                            fontSize: 11,
                            color: _DashboardState._text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 👉 Grid Card for All Topics
class _GridCourseCard extends StatelessWidget {
  final CourseTopic topic;
  final bool isWishlisted;
  final VoidCallback onToggleWishlist;
  final VoidCallback onTap;

  const _GridCourseCard({
    required this.topic,
    required this.isWishlisted,
    required this.onToggleWishlist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = topic.isFree || topic.price == 0;
    final bool isOwned = topic.isEnrolled;

    String priceText(num value) {
      if (value % 1 == 0) {
        return '₹${value.toInt()}';
      }
      return '₹${value.toStringAsFixed(2)}';
    }

    final String priceLabel = isOwned
        ? 'Enrolled'
        : (isFree ? 'Free' : priceText(topic.price));
    final Color priceColor = isOwned
        ? const Color(0xFF22C55E)
        : (isFree ? Colors.green : _DashboardState._accent);

    Widget _buildThumbnail() {
      return SizedBox(
        height: 120,
        width: double.infinity,
        child: TopicImage(
          imageUrl: topic.thumbnailUrl,
          title: topic.title,
          height: 120,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _DashboardState._card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: _DashboardState._shadow,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with price + wishlist
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildThumbnail(),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TranslatedText(
                      priceLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _WishlistPill(
                    isActive: isWishlisted,
                    onToggle: onToggleWishlist,
                  ),
                ),
              ],
            ),
            // Info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _DashboardState._text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TranslatedText(
                      topic.description.isNotEmpty
                          ? topic.description
                          : 'Learn about ${topic.categoryName.toLowerCase()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _DashboardState._muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _DashboardState._accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TranslatedText(
                            topic.difficulty.toUpperCase(),
                            style: const TextStyle(
                              color: _DashboardState._accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule, 
                              size: 14, 
                              color: _DashboardState._muted.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              topic.durationMinutes > 0
                                  ? '${topic.durationMinutes}m'
                                  : 'Self-paced',
                              style: TextStyle(
                                color: _DashboardState._muted.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wishlist pill widget
class _WishlistPill extends StatelessWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const _WishlistPill({
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.favorite : Icons.favorite_border,
          color: isActive ? Colors.red : _DashboardState._muted,
          size: 16,
        ),
      ),
    );
  }
}

class _WishlistIconButton extends StatelessWidget {
  const _WishlistIconButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.favorite : Icons.favorite_border,
          color: isActive
              ? Colors.red
              : _DashboardState._muted.withValues(alpha: 0.7),
          size: 18,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _DashboardState._card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off,
            color: _DashboardState._muted.withValues(alpha: 0.4),
            size: 48,
          ),
          const SizedBox(height: 16),
          TranslatedText(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: _DashboardState._text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const TranslatedText('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _DashboardState._card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.library_books_outlined,
            color: _DashboardState._muted.withValues(alpha: 0.4),
            size: 48,
          ),
          const SizedBox(height: 16),
          const TranslatedText(
            "No topics yet",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _DashboardState._text,
            ),
          ),
          const SizedBox(height: 8),
          const TranslatedText(
            "We are calibrating your curriculum.\nCome back soon!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _DashboardState._muted,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const TranslatedText('Refresh'),
          ),
        ],
      ),
    );
  }
}
