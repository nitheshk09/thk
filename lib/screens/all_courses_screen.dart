import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/wishlist_store.dart';
import '../widgets/topic_visuals.dart';
import '../widgets/translated_text.dart';
import 'topic_detail_screen.dart';
import 'bundle_topics_detail_screen.dart';

const _pageBackground = Color(0xFFF5F7FA);
const _cardBackground = Colors.white;
const _textColor = Color(0xFF1F2937);
const _mutedColor = Color(0xFF6B7280);
const _accentColor = Color(0xFF2E7DFF);
const _shadowColor = Color(0x11000000);

String _truncateDescription(String description, int maxLength) {
  if (description.length <= maxLength) {
    return description;
  }
  
  // Find the last complete word within the limit
  String truncated = description.substring(0, maxLength);
  int lastSpace = truncated.lastIndexOf(' ');
  
  if (lastSpace > 0) {
    truncated = truncated.substring(0, lastSpace);
  }
  
  return '$truncated...';
}

/// Public controller for programmatically switching tabs
class AllCoursesController {
  void Function(int)? _switchToTab;
  
  void switchToTab(int index) {
    _switchToTab?.call(index);
  }
  
  void _attach(void Function(int) callback) {
    _switchToTab = callback;
  }
  
  void _detach() {
    _switchToTab = null;
  }
}

class AllCoursesScreen extends StatefulWidget {
  const AllCoursesScreen({super.key, this.initialTabIndex = 0, this.controller});

  final int initialTabIndex;
  final AllCoursesController? controller;

  @override
  State<AllCoursesScreen> createState() => _AllCoursesScreenState();
}

class _AllCoursesScreenState extends State<AllCoursesScreen> with SingleTickerProviderStateMixin {
  final ThinkCyberApi _api = ThinkCyberApi();
  final WishlistStore _wishlist = WishlistStore.instance;
  late final VoidCallback _wishlistListener;
  late TabController _tabController;
  List<CourseTopic> _courses = const [];
  List<CourseTopic> _freeCourses = const [];
  List<CourseTopic> _paidCourses = const [];
  List<CourseTopic> _enrolledCourses = const [];
  List<UserBundle> _userBundles = const [];
  bool _loading = true;
  String? _error;
  bool _enrollmentsLoading = false;
  String? _enrollmentsError;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_onTabChanged);
    _loadCourses();
    _loadEnrollments();
    _wishlistListener = () {
      if (mounted) setState(() {});
    };
    _wishlist.addListener(_wishlistListener);
    _wishlist.hydrate();
    
    // Attach controller if provided
    widget.controller?._attach(_switchToTab);
  }

  /// Public method to switch to a specific tab
  void switchToTab(int index) {
    _switchToTab(index);
  }
  
  /// Internal method to switch tabs
  void _switchToTab(int index) {
    if (index >= 0 && index < 3 && mounted) {
      _tabController.animateTo(index);
    }
  }

  void _onTabChanged() {
    // When user switches to Enrollments tab (index 2), refresh the enrollments
    if (_tabController.index == 2) {
      debugPrint('🔄 Enrollments tab selected, refreshing enrollments...');
      _loadEnrollments(showLoader: false);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _api.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _wishlist.removeListener(_wishlistListener);
    super.dispose();
  }

  Future<void> _loadCourses({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getInt('thinkcyber_user_id');

      final response = await _api.fetchTopics(userId: storedUserId);
      if (!mounted) return;
      setState(() {
        _courses = response.topics;
        _freeCourses = _courses.where((c) => c.isFree || c.price == 0).toList();
        _paidCourses = _courses.where((c) => !(c.isFree || c.price == 0)).toList();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load courses right now. Please try again shortly.';
        _loading = false;
      });
    }
  }

  Future<void> _loadEnrollments({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _enrollmentsLoading = true;
        _enrollmentsError = null;
      });
    } else {
      setState(() {
        _enrollmentsError = null;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getInt('thinkcyber_user_id');
    if (!mounted) return;

    if (storedUserId == null || storedUserId <= 0) {
      setState(() {
        _userId = null;
        _enrolledCourses = const [];
        _enrollmentsLoading = false;
      });
      return;
    }

    try {
      final courses = await _api.fetchUserEnrollments(userId: storedUserId);
      final bundles = await _api.fetchUserBundles(userId: storedUserId);
      if (!mounted) return;
      setState(() {
        _userId = storedUserId;
        _enrolledCourses = courses;
        _userBundles = bundles;
        _enrollmentsLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _userId = storedUserId;
        _enrollmentsError = error.message;
        _enrollmentsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userId = storedUserId;
        _enrollmentsError =
            'Unable to load enrollments right now. Please try again.';
        _enrollmentsLoading = false;
      });
    }
  }

  Widget _buildGrid(
    List<CourseTopic> courses, {
    Future<void> Function()? onRefresh,
    Widget? emptyState,
    bool hidePriceBadge = false,
  }) {
    if (courses.isEmpty) {
      return emptyState ?? const _EmptyState();
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () => _loadCourses(showLoader: false),
      color: _accentColor,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: courses.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          final course = courses[index];
          return _CourseCard(
            course: course,
            isWishlisted: _wishlist.contains(course.id),
            hidePriceBadge: hidePriceBadge,
            onToggleWishlist: () async {
              final messenger = ScaffoldMessenger.of(context);
              final added = await _wishlist.toggleCourse(summary: course);
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: TranslatedText(
                    added ? 'Added to wishlist' : 'Removed from wishlist',
                  ),
                ),
              );
            },
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TopicDetailScreen(
                    topic: course,
                    fromEnrollments: _tabController.index == 2,
                  ),
                ),
              );
              // Refresh enrollments when returning from detail screen
              if (mounted && _tabController.index == 2) {
                debugPrint('🔄 Returning to Enrollments tab, refreshing...');
                _loadEnrollments(showLoader: false);
              }
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _pageBackground,
        appBar: AppBar(
          title: const TranslatedText('All Topics'),
          backgroundColor: _pageBackground,
          foregroundColor: _textColor,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: _accentColor),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _pageBackground,
        appBar: AppBar(
          title: const TranslatedText('All Topics'),
          backgroundColor: _pageBackground,
          foregroundColor: _textColor,
          elevation: 0,
        ),
        body: _CoursesError(message: _error!, onRetry: _loadCourses),
      );
    }

    if (_courses.isEmpty) {
      return Scaffold(
        backgroundColor: _pageBackground,
        appBar: AppBar(
          title: const TranslatedText('All Topics'),
          backgroundColor: _pageBackground,
          foregroundColor: _textColor,
          elevation: 0,
        ),
        body: const _EmptyState(),
      );
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const TranslatedText('All Topics'),
        backgroundColor: _pageBackground,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent, // removes default Material3 tint line

        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(25),
            ),

            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: _mutedColor,
              isScrollable: false,
              indicator: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TranslatedText('Free (${_freeCourses.length})'),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TranslatedText('Paid (${_paidCourses.length})'),
                  ),
                ),
                Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TranslatedText(_userId == null
                        ? 'Enrollments'
                        : 'Enrollments (${_enrolledCourses.length})'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGrid(_freeCourses),
          _buildGrid(_paidCourses),
          _buildEnrollmentsTab(),
        ],
      ),
    );
  }

  Widget _buildEnrollmentsTab() {
    if (_enrollmentsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _accentColor),
      );
    }

    if (_userId == null) {
      return const _EnrollmentsSignInPrompt();
    }

    if (_enrollmentsError != null) {
      return _CoursesError(
        message: _enrollmentsError!,
        onRetry: ({bool showLoader = true}) =>
            _loadEnrollments(showLoader: showLoader),
      );
    }

    if (_enrolledCourses.isEmpty) {
      return const _EnrollmentsEmptyState();
    }

    // Debug: Print all enrollments in detail
    debugPrint('=== ALL ENROLLMENTS (${_enrolledCourses.length}) ===');
    for (int i = 0; i < _enrolledCourses.length; i++) {
      final e = _enrolledCourses[i];
      debugPrint('[$i] ${e.title} - categoryName: "${e.categoryName}" - price: ${e.price}');
    }
    debugPrint('=== ALL BUNDLES (${_userBundles.length}) ===');
    for (int i = 0; i < _userBundles.length; i++) {
      final b = _userBundles[i];
      debugPrint('[$i] ${b.categoryName} - planType: ${b.planType} - price: ${b.bundlePrice}');
    }

    // Separate bundles by plan type
    final paidBundleEnrollments = _userBundles.where((b) => 
      b.planType == 'BUNDLE'
    ).toList();
    
    final flexibleBundleEnrollments = _userBundles.where((b) => 
      b.planType == 'FLEXIBLE'
    ).toList();
    
    // Free bundles: from user_bundles API with FREE plan_type
    var freeBundleEnrollments = _userBundles.where((b) => 
      b.planType == 'FREE'
    ).toList();
    
    // Also add free individual enrollments with categoryName as virtual free bundles
    final freeEnrollmentsWithCategory = _enrolledCourses.where((e) =>
      e.price == 0 && e.categoryName != null && e.categoryName!.isNotEmpty
    ).toList();
    
    // Convert free enrollments with category to virtual UserBundles
    final Map<String, List<CourseTopic>> freeByCategory = {};
    for (final e in freeEnrollmentsWithCategory) {
      final cat = e.categoryName ?? 'General';
      freeByCategory.putIfAbsent(cat, () => []).add(e);
    }
    
    // Create virtual bundles from free course groups
    for (final entry in freeByCategory.entries) {
      final firstTopic = entry.value.first;
      final virtualFreeBundle = UserBundle(
        id: -1,
        userId: _userId ?? 0,
        categoryId: firstTopic.categoryId,
        categoryName: entry.key,
        bundlePrice: 0,
        planType: 'FREE',
        paymentStatus: 'completed',
        enrolledAt: DateTime.now().toIso8601String(),
        futureTopicsIncluded: true,
        accessibleTopicsCount: entry.value.length,
        description: 'Free Plan',
      );
      
      // Only add if not already in bundles from API
      if (!freeBundleEnrollments.any((b) => b.categoryId == firstTopic.categoryId)) {
        freeBundleEnrollments = [...freeBundleEnrollments, virtualFreeBundle];
      }
    }
    
    debugPrint('=== FILTERED BUNDLES ===');
    debugPrint('Paid Bundles: ${paidBundleEnrollments.length}');
    debugPrint('Flexible Bundles: ${flexibleBundleEnrollments.length}');
    debugPrint('Free Bundles (including virtual): ${freeBundleEnrollments.length}');
    for (var fb in freeBundleEnrollments) {
      debugPrint('  ✅ ${fb.categoryName} (${fb.accessibleTopicsCount} topics)');
    }
    
    final individualEnrollments = _enrolledCourses.where((c) => 
      c.categoryName == null || c.categoryName!.isEmpty
    ).toList();

    return RefreshIndicator(
      onRefresh: () => _loadEnrollments(showLoader: false),
      color: _accentColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Paid Bundle Plans Section
          if (paidBundleEnrollments.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.card_giftcard_rounded,
              title: 'Bundle Plans',
              count: paidBundleEnrollments.length,
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 16),
            ..._buildBundleCardsFromUserBundles(paidBundleEnrollments),
            const SizedBox(height: 24),
          ],

          // Flexible Bundle Plans Section
          if (flexibleBundleEnrollments.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.tune_rounded,
              title: 'Flexible Plans',
              count: flexibleBundleEnrollments.length,
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(height: 16),
            ..._buildFlexibleBundleCards(flexibleBundleEnrollments),
            const SizedBox(height: 24),
          ],

          // Free Bundle Plans Section
          if (freeBundleEnrollments.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.card_giftcard_rounded,
              title: 'Free Plans',
              count: freeBundleEnrollments.length,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 16),
            ..._buildFreeBundleCardsFromUserBundles(freeBundleEnrollments),
            const SizedBox(height: 24),
          ],
          
          // Individual Topics Section
          if (individualEnrollments.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.article_outlined,
              title: 'Individual Topics',
              count: individualEnrollments.length,
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(height: 16),
            ..._buildIndividualCards(individualEnrollments),
          ],
        ],
      ),
    );
  }

  Widget _buildEnrollmentHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF4F46E5),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 12),
              TranslatedText(
                'My Enrollments',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TranslatedText(
            'You have ${_getBundleCount(_enrolledCourses)} bundle and ${_getIndividualCount(_enrolledCourses)} individual topics enrolled',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TranslatedText(
                    'Subscription Validity: Each course subscription is valid for one year from the date of enrollment.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        TranslatedText(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  int _getBundleCount(List<CourseTopic> courses) {
    // Bundle: Only paid courses with category names
    // Must check actual _courses list since enrollment API doesn't return price
    final bundleCourses = courses.where((enrollment) {
      final actualCourse = _courses.firstWhere(
        (c) => c.id == enrollment.id,
        orElse: () => enrollment,
      );
      return actualCourse.price > 0 && enrollment.categoryName != null && enrollment.categoryName!.isNotEmpty;
    }).toList();
    
    final categories = bundleCourses
        .map((c) => c.categoryName)
        .toSet()
        .length;
    return categories;
  }

  int _getIndividualCount(List<CourseTopic> courses) {
    // Individual: Courses without category names
    return courses
        .where((c) => c.categoryName == null || c.categoryName!.isEmpty)
        .length;
  }

  int _getFreeBundleCount(List<CourseTopic> courses) {
    // Free Bundle: Count unique categories for free bundle enrollments
    // Must check actual _courses list since enrollment API doesn't return price
    final freeBundleCourses = courses.where((enrollment) {
      final actualCourse = _courses.firstWhere(
        (c) => c.id == enrollment.id,
        orElse: () => enrollment,
      );
      return actualCourse.price == 0 && enrollment.categoryName != null && enrollment.categoryName!.isNotEmpty;
    }).toList();
    
    final categories = freeBundleCourses
        .map((c) => c.categoryName)
        .toSet()
        .length;
    return categories;
  }

  // Helper: Resolve accurate category name using loaded courses when enrollment uses generic name
  String _resolveCategoryName(int categoryId, String? fallbackName) {
    final match = _courses.firstWhere(
      (c) => c.categoryId == categoryId,
      orElse: () => CourseTopic(
        id: -1,
        title: '',
        description: '',
        categoryId: categoryId,
        categoryName: fallbackName ?? 'General',
        subcategoryId: null,
        subcategoryName: null,
        difficulty: 'Beginner',
        status: 'active',
        isFree: true,
        isFeatured: false,
        price: 0,
        durationMinutes: 0,
        thumbnailUrl: '',
      ),
    );
    return match.categoryName;
  }

  // Helper: Get total topics count for a category using loaded courses
  int _getTopicsCountForCategoryId(int categoryId) {
    return _courses.where((c) => c.categoryId == categoryId).length;
  }

  List<Widget> _buildBundleCards(List<CourseTopic> courses) {
    // Group enrollments by category name
    final Map<String, List<CourseTopic>> groupedByCategory = {};
    for (final course in courses) {
      final category = course.categoryName ?? 'Other';
      groupedByCategory.putIfAbsent(category, () => []).add(course);
    }

    final List<Widget> cards = [];
    groupedByCategory.forEach((categoryNameKey, topics) {
      final categoryId = topics.first.categoryId;
      final categoryName = _resolveCategoryName(categoryId, topics.first.categoryName);
      final topicsCount = _getTopicsCountForCategoryId(categoryId);
      
      // Get actual price from _courses list (enrollment API returns 0 for all)
      final actualCourse = _courses.firstWhere(
        (c) => c.id == topics.first.id,
        orElse: () => topics.first,
      );
      final bundlePrice = actualCourse.price > 0 ? actualCourse.price : 3500.0;

      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF59E0B),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFFF59E0B),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const TranslatedText(
                                'BUNDLE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const TranslatedText(
                                'Topics:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$topicsCount',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const TranslatedText(
                                'Price:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '₹${bundlePrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          TranslatedText(
                            'Future topics included',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BundleTopicsDetailScreen(
                                  categoryId: categoryId,
                                  categoryName: categoryName,
                                  userId: _userId ?? 0,
                                ),
                              ),
                            );
                          },
                          child: const TranslatedText(
                            'View Topics',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
        ),
      );
    });
    return cards;
  }

  List<Widget> _buildFreeBundleCards(List<CourseTopic> courses) {
    // Group enrollments by category name
    final Map<String, List<CourseTopic>> groupedByCategory = {};
    for (final course in courses) {
      final category = course.categoryName ?? 'Other';
      groupedByCategory.putIfAbsent(category, () => []).add(course);
    }

    final List<Widget> cards = [];
    groupedByCategory.forEach((categoryNameKey, topics) {
      final categoryId = topics.first.categoryId;
      final categoryName = _resolveCategoryName(categoryId, topics.first.categoryName);
      final topicsCount = _getTopicsCountForCategoryId(categoryId);

      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF10B981),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFF10B981),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              categoryName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const TranslatedText(
                                'FREE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const TranslatedText(
                            'Topics:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$topicsCount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          TranslatedText(
                            'Future topics included',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BundleTopicsDetailScreen(
                                  categoryId: categoryId,
                                  categoryName: categoryName,
                                  userId: _userId ?? 0,
                                ),
                              ),
                            );
                          },
                          child: const TranslatedText(
                            'View Topics',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
        ),
      );
    });
    return cards;
  }

  // Build cards from UserBundle data for BUNDLE plan type
  List<Widget> _buildBundleCardsFromUserBundles(List<UserBundle> bundles) {
    return bundles.map((bundle) {
      return _buildBundleCard(bundle, const Color(0xFFF59E0B), 'BUNDLE');
    }).toList();
  }

  // Build cards from UserBundle data for FLEXIBLE plan type
  List<Widget> _buildFlexibleBundleCards(List<UserBundle> bundles) {
    return bundles.map((bundle) {
      return _buildBundleCard(bundle, const Color(0xFF6366F1), 'FLEXIBLE');
    }).toList();
  }

  // Build cards from UserBundle data for FREE plan type
  List<Widget> _buildFreeBundleCardsFromUserBundles(List<UserBundle> bundles) {
    return bundles.map((bundle) {
      return _buildBundleCard(bundle, const Color(0xFF10B981), 'FREE');
    }).toList();
  }

  Widget _buildBundleCard(UserBundle bundle, Color color, String planLabel) {
    // For BUNDLE/FLEXIBLE plans, show total topics count
    // For FREE plans, show actual enrolled count from _enrolledCourses
    int displayTopicsCount;
    if (planLabel == 'BUNDLE' || planLabel == 'FLEXIBLE') {
      displayTopicsCount = _getTopicsCountForCategoryId(bundle.categoryId);
    } else {
      // FREE plan: count actual enrolled topics in this category
      displayTopicsCount = _enrolledCourses.where((c) => 
        c.categoryId == bundle.categoryId && c.price == 0
      ).length;
      // Fallback to accessibleTopicsCount if no enrolled courses found
      if (displayTopicsCount == 0) {
        displayTopicsCount = bundle.accessibleTopicsCount;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: color,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatedText(
                          bundle.categoryName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: TranslatedText(
                            planLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const TranslatedText(
                            'Topics:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$displayTopicsCount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      if (bundle.bundlePrice > 0)
                        Row(
                          children: [
                            const TranslatedText(
                              'Price:',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '₹${bundle.bundlePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        bundle.futureTopicsIncluded
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: bundle.futureTopicsIncluded
                            ? const Color(0xFF10B981)
                            : const Color(0xFFDC2626),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      TranslatedText(
                        'Future topics ${bundle.futureTopicsIncluded ? 'included' : 'not included'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: bundle.futureTopicsIncluded
                              ? const Color(0xFF10B981)
                              : const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        debugPrint('Viewing topics for: ${bundle.categoryName} (category ${bundle.categoryId})');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BundleTopicsDetailScreen(
                              categoryId: bundle.categoryId,
                              categoryName: bundle.categoryName,
                              userId: _userId ?? 0,
                            ),
                          ),
                        );
                      },
                      child: const TranslatedText(
                        'View Topics',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

  List<Widget> _buildIndividualCards(List<CourseTopic> courses) {
    return courses.map((course) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.article_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: TranslatedText(
              course.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const TranslatedText(
                      'INDIVIDUAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const TranslatedText(
                    'Enrolled',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              iconSize: 18,
              color: _mutedColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopicDetailScreen(topic: course),
                  ),
                );
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TopicDetailScreen(topic: course),
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.isWishlisted,
    required this.onToggleWishlist,
    required this.onTap,
    this.hidePriceBadge = false,
  });

  final CourseTopic course;
  final bool isWishlisted;
  final Future<void> Function() onToggleWishlist;
  final VoidCallback onTap;
  final bool hidePriceBadge;

  @override
  Widget build(BuildContext context) {
    final isFree = course.isFree || course.price == 0;
    final bool isOwned = course.isEnrolled;

    String priceText(num value) {
      if (value % 1 == 0) {
        return '₹${value.toInt()}';
      }
      return '₹${value.toStringAsFixed(2)}';
    }

    final String priceLabel = isOwned
        ? 'Enrolled'
        : (isFree ? 'Free' : priceText(course.price));
    final Color priceColor = isOwned
        ? const Color(0xFF22C55E)
        : (isFree ? const Color(0xFF10B981) : _accentColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 12,
              offset: Offset(0, 8),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: TopicImage(
                      imageUrl: course.thumbnailUrl,
                      title: course.title,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (!hidePriceBadge)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: priceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        priceLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  top: 10,
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
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TranslatedText(
                      course.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: TranslatedText(
                        _truncateDescription(
                          course.description.isNotEmpty
                              ? course.description
                              : 'Learn ${course.categoryName.toLowerCase()} fundamentals',
                          100,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _mutedColor,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: TranslatedText(
                            course.difficulty.toUpperCase(),
                            style: const TextStyle(
                              color: _accentColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_outlined, 
                              size: 11, 
                              color: _mutedColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 3),
                            TranslatedText(
                              course.durationMinutes > 0
                                  ? '${course.durationMinutes}m'
                                  : 'Self',
                              style: const TextStyle(
                                color: _mutedColor,
                                fontSize: 10,
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



class _WishlistPill extends StatelessWidget {
  const _WishlistPill({required this.isActive, required this.onToggle});
  final bool isActive;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: isActive ? const Color(0xFFEF4444) : _mutedColor.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cast_for_education_outlined,
                size: 64, color: _mutedColor),
            const SizedBox(height: 16),
            const TranslatedText(
              'Courses will appear here soon',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const TranslatedText(
              'Looks like the catalogue is still loading. Pull down to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mutedColor,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentsEmptyState extends StatelessWidget {
  const _EnrollmentsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const _EnrollmentsMessage(
      icon: Icons.school_outlined,
      title: 'No enrollments yet',
      subtitle: 'Start your learning journey by enrolling in a course.',
    );
  }
}

class _EnrollmentsSignInPrompt extends StatelessWidget {
  const _EnrollmentsSignInPrompt();

  @override
  Widget build(BuildContext context) {
    return const _EnrollmentsMessage(
      icon: Icons.lock_outline,
      title: 'Sign in to view enrollments',
      subtitle: 'Log in to keep track of the courses you have joined.',
    );
  }
}

class _EnrollmentsMessage extends StatelessWidget {
  const _EnrollmentsMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: _mutedColor),
            const SizedBox(height: 16),
            TranslatedText(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TranslatedText(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _mutedColor,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoursesError extends StatelessWidget {
  const _CoursesError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function({bool showLoader}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: _mutedColor),
            const SizedBox(height: 16),
            TranslatedText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => onRetry(showLoader: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const TranslatedText('Try again',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
