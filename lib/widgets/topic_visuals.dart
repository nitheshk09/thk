import 'package:flutter/material.dart';

// Default gradient for all topics
LinearGradient topicGradientFor(String seed) {
  return const LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// Default fallback image path
const String kDefaultTopicImage = 'Asset/fallback_preview.png';

String topicHeroTag(int topicId, [String? context]) => 
  context != null ? 'topic-thumbnail-$topicId-$context' : 'topic-thumbnail-$topicId';

class TopicThumbnailFallback extends StatelessWidget {
  const TopicThumbnailFallback({
    super.key,
    this.gradient,
    required this.title,
  });

  final LinearGradient? gradient;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: Image.asset(
        kDefaultTopicImage,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If fallback_preview.png fails, try thk.png as backup
          return Image.asset(
            'Asset/thk.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Ultimate fallback to a simple colored container with icon
              return Container(
                color: const Color(0xFF4F46E5),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Widget for topic images with proper fallback chain
class TopicImage extends StatelessWidget {
  const TopicImage({
    super.key,
    required this.imageUrl,
    required this.title,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String imageUrl;
  final String title;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    // Always use fallback image to show consistent preview
    return Container(
      width: width,
      height: height,
      child: TopicThumbnailFallback(title: title),
    );
  }
}
