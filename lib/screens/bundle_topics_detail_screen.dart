import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/translated_text.dart';
import '../widgets/topic_visuals.dart';
import 'topic_detail_screen.dart';

class BundleTopicsDetailScreen extends StatefulWidget {
  const BundleTopicsDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.userId,
  });

  final int categoryId;
  final String categoryName;
  final int userId;

  @override
  State<BundleTopicsDetailScreen> createState() => _BundleTopicsDetailScreenState();
}

class _BundleTopicsDetailScreenState extends State<BundleTopicsDetailScreen> {
  static const Color _accent = Color(0xFF0D6EFD);
  static const int _topicsPerPage = 6;
  
  final ThinkCyberApi _api = ThinkCyberApi();
  List<CourseTopic> _bundleTopics = [];
  bool _loading = true;
  String? _error;
  int _currentPage = 0;
  int _swipeDirection = 1; // 1 for right/next, -1 for left/previous

  @override
  void initState() {
    super.initState();
    _loadBundleTopics();
  }

  Future<void> _loadBundleTopics() async {
    try {
      setState(() => _loading = true);
      
      debugPrint('=== BUNDLE TOPICS DETAIL SCREEN ===');
      debugPrint('User ID: ${widget.userId}');
      debugPrint('Category ID: ${widget.categoryId}');
      debugPrint('Category Name: ${widget.categoryName}');
      
      // Use the category-topics-access API with passed userId
      final topics = await _api.fetchCategoryTopicsAccess(
        userId: widget.userId,
        categoryId: widget.categoryId,
      );
      
      debugPrint('Topics loaded: ${topics.length}');
      for (var t in topics) {
        debugPrint('  - Topic ID ${t.id}: ${t.title}');
      }

      if (mounted) {
        setState(() {
          _bundleTopics = topics;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bundle topics: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load topics. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: TranslatedText(
          widget.categoryName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0D6EFD),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(height: 16),
                      TranslatedText(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadBundleTopics,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const TranslatedText('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D6EFD),
                        ),
                      ),
                    ],
                  ),
                )
              : _bundleTopics.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inbox_rounded,
                            size: 64,
                            color: Color(0xFFD1D5DB),
                          ),
                          const SizedBox(height: 16),
                          const TranslatedText(
                            'No topics in this bundle yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBundleTopics,
                      color: _accent,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: _buildPaginatedTopicsGrid(),
                      ),
                    ),
    );
  }

  Widget _buildPaginatedTopicsGrid() {
    final totalPages = (_bundleTopics.length / _topicsPerPage).ceil();
    final startIndex = _currentPage * _topicsPerPage;
    final endIndex = (startIndex + _topicsPerPage).clamp(0, _bundleTopics.length);
    final pageTopics = _bundleTopics.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with topic count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TranslatedText(
              'Bundle Topics',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_bundleTopics.length} Topics',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Pagination dots
        if (totalPages > 1) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (index) {
              final isActive = _currentPage == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _swipeDirection = index > _currentPage ? 1 : -1;
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
                    color: isActive ? _accent : const Color(0xFFD1D5DB),
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
          Center(
            child: TranslatedText(
              'Page ${_currentPage + 1} of $totalPages',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Swipeable grid with smooth animation
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          transitionBuilder: (child, animation) {
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
                    _swipeDirection = -1;
                    _currentPage--;
                  });
                }
              }
              // Swipe left to next page
              else if (details.primaryVelocity! < 0) {
                if (_currentPage < totalPages - 1) {
                  setState(() {
                    _swipeDirection = 1;
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
  }

  Widget _buildModernTopicCard(CourseTopic topic) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopicDetailScreen(
              topic: topic,
              fromEnrollments: true,
            ),
          ),
        );
      },
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
            // Topic Image - Expanded like dashboard
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  color: Color(0xFFF0F4F8),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: TopicImage(
                        imageUrl: topic.thumbnailUrl,
                        title: topic.title,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    // Enrolled Badge at top right
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
                          'Enrolled',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Card Content - Fixed padding like dashboard
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
                          color: _accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: _accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TranslatedText(
                          topic.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _accent,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Difficulty and Duration badges
                  Row(
                    children: [
                      if (topic.difficulty.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(topic.difficulty).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            topic.difficulty,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getDifficultyColor(topic.difficulty),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (topic.difficulty.isNotEmpty) const SizedBox(width: 4),
                      if (topic.durationMinutes > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${topic.durationMinutes} min',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9CA3AF),
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
        return const Color(0xFF0D6EFD);
      case 'advanced':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }
}