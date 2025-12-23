import 'package:flutter/material.dart';

import '../services/wishlist_store.dart';
import '../widgets/topic_visuals.dart' show topicGradientFor;
import '../widgets/translated_text.dart';
import '../widgets/lottie_loader.dart';
import 'topic_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final WishlistStore _wishlist = WishlistStore.instance;
  late final VoidCallback _listener;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    _wishlist.addListener(_listener);
    _hydrate();
  }

  @override
  void dispose() {
    _wishlist.removeListener(_listener);
    super.dispose();
  }

  Future<void> _hydrate() async {
    await _wishlist.hydrate();
    if (!mounted) return;
    setState(() => _hydrated = true);
  }

  @override
  Widget build(BuildContext context) {
    final courses = _wishlist.courses;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const TranslatedText('Wishlist'),
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
      ),
      body: !_hydrated
          ? const Center(child: LottieLoader(width: 120, height: 120))
          : courses.isEmpty
          ? const _EmptyWishlist()
          : RefreshIndicator(
              color: const Color(0xFF2E7DFF),
              onRefresh: _hydrate,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final saved = courses[index];
                  return _WishlistCourseCard(
                    course: saved,
                    onOpen: () {
                      final topic = saved.toCourseTopic();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TopicDetailScreen(topic: topic),
                        ),
                      );
                    },
                    onRemove: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await _wishlist.remove(saved.id);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: TranslatedText('Removed from wishlist')),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _WishlistCourseCard extends StatelessWidget {
  const _WishlistCourseCard({
    required this.course,
    required this.onOpen,
    required this.onRemove,
  });

  final SavedCourse course;
  final VoidCallback onOpen;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topic = course.toCourseTopic();
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
        : (isFree ? 'Free' : priceText(topic.price));  // Will be translated in UI
    final Color priceColor = isOwned
        ? const Color(0xFF22C55E)
        : (isFree ? Colors.green : const Color(0xFF2E7DFF));

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            _WishlistThumbnail(course: course),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TranslatedText(
                    course.description.isNotEmpty
                        ? course.description
                        : 'Course description will be available soon.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _TagChip(label: course.categoryName, translate: true),
                      _TagChip(label: course.difficulty, translate: true),
                      _TagChip(
                        label: priceLabel,
                        backgroundColor: priceColor.withValues(alpha: 0.12),
                        foregroundColor: priceColor,
                        translate: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => onRemove(),
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5757)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistThumbnail extends StatelessWidget {
  const _WishlistThumbnail({required this.course});

  final SavedCourse course;

  @override
  Widget build(BuildContext context) {
    if (course.thumbnailUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          course.thumbnailUrl,
          width: 82,
          height: 82,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _GradientFallback(course: course),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: _GradientFallback(course: course),
    );
  }
}

class _GradientFallback extends StatelessWidget {
  const _GradientFallback({required this.course});

  final SavedCourse course;

  @override
  Widget build(BuildContext context) {
    final gradient = topicGradientFor(course.title);
    final initials = course.title.isNotEmpty
        ? course.title.trim()[0].toUpperCase()
        : 'C';

    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.translate = false,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool translate;

  @override
  Widget build(BuildContext context) {
    final Color bg = backgroundColor ?? const Color(0xFF2E7DFF).withValues(alpha: 0.12);
    final Color fg = foregroundColor ?? const Color(0xFF2E7DFF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: translate
          ? TranslatedText(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )
          : Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }
}

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.favorite_border_rounded,
              size: 72,
              color: Color(0xFFCBD5F5),
            ),
            SizedBox(height: 16),
            TranslatedText(
              'No saved courses yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 10),
            TranslatedText(
              'Tap the heart on any course to build your wishlist.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
