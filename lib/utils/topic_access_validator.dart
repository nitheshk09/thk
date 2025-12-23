import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/enrollment_service.dart';

/// Utility class for checking topic access based on enrollment and purchase type
class TopicAccessValidator {
  static final TopicAccessValidator _instance =
      TopicAccessValidator._internal();
  factory TopicAccessValidator() => _instance;
  TopicAccessValidator._internal();

  final _enrollmentService = EnrollmentService();

  /// Check if user has access to a topic
  bool canAccessTopic({
    required CourseTopic topic,
    required List<EnrollmentRecord> enrollments,
  }) {
    return _enrollmentService.hasAccessToTopic(
      topic: topic,
      enrollments: enrollments,
    );
  }

  /// Get access status with reason
  TopicAccessStatus getAccessStatus({
    required CourseTopic topic,
    required List<EnrollmentRecord>? enrollments,
  }) {
    enrollments ??= [];

    // Free topics
    if (topic.isFree) {
      return TopicAccessStatus(
        hasAccess: true,
        reason: 'free_topic',
        message: 'Free topic - Available to all',
      );
    }

    // No enrollments
    if (enrollments.isEmpty) {
      return TopicAccessStatus(
        hasAccess: false,
        reason: 'not_enrolled',
        message: 'Not enrolled in this topic',
      );
    }

    // Check for bundle access
    final bundleEnrollment = enrollments.firstWhere(
      (e) =>
          e.purchaseType == PurchaseType.bundle &&
          e.categoryId == topic.categoryId,
      orElse: () => null as EnrollmentRecord,
    );

    if (bundleEnrollment != null) {
      if (bundleEnrollment.includeFutureTopics) {
        return TopicAccessStatus(
          hasAccess: true,
          reason: 'bundle_with_future',
          message: 'Included in category bundle (with future topics)',
          enrollmentType: 'bundle',
        );
      } else {
        // Check if topic was created before purchase
        if (bundleEnrollment.topicCreatedAt != null) {
          final hasAccess = bundleEnrollment.topicCreatedAt!
              .isBefore(bundleEnrollment.enrolledAt);
          if (hasAccess) {
            return TopicAccessStatus(
              hasAccess: true,
              reason: 'bundle_existing_topic',
              message:
                  'Included in category bundle (topic existed at purchase)',
              enrollmentType: 'bundle',
            );
          } else {
            return TopicAccessStatus(
              hasAccess: false,
              reason: 'bundle_no_future',
              message:
                  'This topic was added after your bundle purchase. Future topics not included.',
              enrollmentType: 'bundle',
            );
          }
        }
        return TopicAccessStatus(
          hasAccess: true,
          reason: 'bundle_existing_topic',
          message: 'Included in category bundle',
          enrollmentType: 'bundle',
        );
      }
    }

    // Check for individual access
    final individualEnrollment = enrollments.firstWhere(
      (e) =>
          e.purchaseType == PurchaseType.individual &&
          e.topicId == topic.id,
      orElse: () => null as EnrollmentRecord,
    );

    if (individualEnrollment != null) {
      return TopicAccessStatus(
        hasAccess: true,
        reason: 'individual_purchase',
        message: 'Individual topic purchase',
        enrollmentType: 'individual',
      );
    }

    return TopicAccessStatus(
      hasAccess: false,
      reason: 'not_enrolled',
      message: 'Not enrolled in this topic',
    );
  }

  /// Get upgrade suggestion based on access status
  String getUpgradeSuggestion({
    required CourseTopic topic,
    required List<EnrollmentRecord>? enrollments,
  }) {
    final status = getAccessStatus(topic: topic, enrollments: enrollments);

    switch (status.reason) {
      case 'bundle_no_future':
        return 'Upgrade to a bundle that includes future topics to get access to this topic.';
      case 'not_enrolled':
        return 'Purchase this topic individually or buy a bundle for the ${topic.categoryName} category.';
      case 'free_topic':
      case 'bundle_with_future':
      case 'bundle_existing_topic':
      case 'individual_purchase':
        return '';
      default:
        return 'Contact support for assistance with access.';
    }
  }

  /// Get purchasable options for a topic
  List<PurchaseOption> getPurchaseOptions({
    required CourseTopic topic,
    required double bundlePrice,
  }) {
    final options = <PurchaseOption>[];

    if (topic.isFree) {
      options.add(
        PurchaseOption(
          type: 'enroll_free',
          label: 'Enroll Now',
          description: 'Free access',
          price: 0,
        ),
      );
    } else {
      // Individual purchase option
      options.add(
        PurchaseOption(
          type: 'individual',
          label: 'Buy Individual Topic',
          description:
              'Access this topic only (no future topics in ${topic.categoryName})',
          price: topic.price.toDouble(),
        ),
      );

      // Bundle purchase option
      if (bundlePrice > 0) {
        final savings = (topic.price * 0.2).toDouble(); // Estimated savings
        options.add(
          PurchaseOption(
            type: 'bundle',
            label: 'Buy ${topic.categoryName} Bundle',
            description:
                'All topics in ${topic.categoryName} + future topics included',
            price: bundlePrice,
            savings: savings,
          ),
        );
      }
    }

    return options;
  }

  /// Validate bundle purchase eligibility
  bool canPurchaseBundle({
    required int categoryId,
    required List<EnrollmentRecord>? enrollments,
  }) {
    enrollments ??= [];
    // User cannot purchase bundle if already have one
    return !enrollments.any(
      (e) =>
          e.purchaseType == PurchaseType.bundle &&
          e.categoryId == categoryId,
    );
  }

  /// Get topics user has access to in a category
  List<CourseTopic> getAccessibleTopicsInCategory({
    required String categoryName,
    required List<CourseTopic> allTopics,
    required List<EnrollmentRecord>? enrollments,
  }) {
    enrollments ??= [];
    return allTopics.where((topic) {
      if (topic.categoryName != categoryName) return false;
      return canAccessTopic(topic: topic, enrollments: enrollments!);
    }).toList();
  }
}

/// Status object for topic access
class TopicAccessStatus {
  final bool hasAccess;
  final String reason; // free_topic, bundle_with_future, bundle_existing_topic, bundle_no_future, individual_purchase, not_enrolled
  final String message;
  final String? enrollmentType; // 'bundle' or 'individual' or null

  TopicAccessStatus({
    required this.hasAccess,
    required this.reason,
    required this.message,
    this.enrollmentType,
  });
}

/// Purchase option for a topic
class PurchaseOption {
  final String type; // 'enroll_free', 'individual', 'bundle'
  final String label;
  final String description;
  final double price;
  final double? savings;

  PurchaseOption({
    required this.type,
    required this.label,
    required this.description,
    required this.price,
    this.savings,
  });

  bool get isFree => price == 0;
}
