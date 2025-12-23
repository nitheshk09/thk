import 'api_client.dart';

/// Enrollment purchase type enum
enum PurchaseType {
  free,      // Topic is free
  bundle,    // Purchased as part of category bundle (includes future topics)
  individual, // Individual topic purchase (no future topics)
}

/// Represents a user's enrollment record for a topic
class EnrollmentRecord {
  EnrollmentRecord({
    required this.id,
    required this.topicId,
    required this.userId,
    required this.enrolledAt,
    required this.purchaseType,
    this.categoryId,
    required this.includeFutureTopics,
    this.topicCreatedAt,
  });

  final int id;
  final int topicId;
  final int userId;
  final DateTime enrolledAt;
  final PurchaseType purchaseType;
  final int? categoryId;  // Only set for bundle purchases
  final bool includeFutureTopics;
  final DateTime? topicCreatedAt;  // When the topic was created

  /// Check if this is a bundle purchase that includes future topics
  bool get isBundleWithFutureTopics =>
      purchaseType == PurchaseType.bundle && includeFutureTopics;

  /// Check if this is an individual purchase (no future topics)
  bool get isIndividualPurchase => purchaseType == PurchaseType.individual;

  /// Check if this is a free topic
  bool get isFree => purchaseType == PurchaseType.free;

  factory EnrollmentRecord.fromJson(Map<String, dynamic> json) {
    return EnrollmentRecord(
      id: json['id'] as int? ?? 0,
      topicId: json['topic_id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      enrolledAt: json['enrolled_at'] != null
          ? DateTime.parse(json['enrolled_at'] as String)
          : DateTime.now(),
      purchaseType: _parsePurchaseType(json['purchase_type'] as String?),
      categoryId: json['category_id'] as int?,
      includeFutureTopics: json['include_future_topics'] as bool? ?? false,
      topicCreatedAt: json['topic_created_at'] != null
          ? DateTime.parse(json['topic_created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'topic_id': topicId,
    'user_id': userId,
    'enrolled_at': enrolledAt.toIso8601String(),
    'purchase_type': _purchaseTypeToString(purchaseType),
    'category_id': categoryId,
    'include_future_topics': includeFutureTopics,
    'topic_created_at': topicCreatedAt?.toIso8601String(),
  };

  EnrollmentRecord copyWith({
    int? id,
    int? topicId,
    int? userId,
    DateTime? enrolledAt,
    PurchaseType? purchaseType,
    int? categoryId,
    bool? includeFutureTopics,
    DateTime? topicCreatedAt,
  }) {
    return EnrollmentRecord(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      userId: userId ?? this.userId,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      purchaseType: purchaseType ?? this.purchaseType,
      categoryId: categoryId ?? this.categoryId,
      includeFutureTopics: includeFutureTopics ?? this.includeFutureTopics,
      topicCreatedAt: topicCreatedAt ?? this.topicCreatedAt,
    );
  }
}

/// Service to manage user enrollments and access control
class EnrollmentService {
  static final EnrollmentService _instance = EnrollmentService._internal();
  factory EnrollmentService() => _instance;
  EnrollmentService._internal();

  final ThinkCyberApi _api = ThinkCyberApi();

  /// Check if user has access to a specific topic
  /// 
  /// Returns true if:
  /// - Topic is free
  /// - User has an enrollment record AND
  ///   - For individual purchases: enrolled for this exact topic
  ///   - For bundles: enrolled for the category AND topic was added before purchase OR bundle includes future topics
  bool hasAccessToTopic({
    required CourseTopic topic,
    required List<EnrollmentRecord> enrollments,
  }) {
    // Free topics always accessible
    if (topic.isFree) {
      return true;
    }

    // Find relevant enrollment record
    final enrollment = _findRelevantEnrollment(topic, enrollments);
    if (enrollment == null) {
      return false;
    }

    // Individual purchase: only this topic
    if (enrollment.isIndividualPurchase) {
      return enrollment.topicId == topic.id;
    }

    // Bundle purchase: check category and time
    if (enrollment.purchaseType == PurchaseType.bundle) {
      // Must be in the same category
      if (enrollment.categoryId != topic.categoryId) {
        return false;
      }

      // If bundle includes future topics, grant access
      if (enrollment.includeFutureTopics) {
        return true;
      }

      // If bundle doesn't include future topics, check if topic existed at purchase time
      if (enrollment.topicCreatedAt != null) {
        return enrollment.topicCreatedAt!.isBefore(enrollment.enrolledAt) ||
               enrollment.topicCreatedAt!.isAtSameMomentAs(enrollment.enrolledAt);
      }

      // Default to true if we can't determine creation time
      return true;
    }

    return false;
  }

  /// Get the purchase type for a topic
  PurchaseType? getPurchaseType({
    required CourseTopic topic,
    required List<EnrollmentRecord> enrollments,
  }) {
    final enrollment = _findRelevantEnrollment(topic, enrollments);
    return enrollment?.purchaseType;
  }

  /// Check if user has bundle access for a category
  bool hasBundleAccess({
    required int categoryId,
    required List<EnrollmentRecord> enrollments,
  }) {
    return enrollments.any(
      (e) =>
          e.purchaseType == PurchaseType.bundle &&
          e.categoryId == categoryId,
    );
  }

  /// Check if user has individual access to a specific topic
  bool hasIndividualAccess({
    required int topicId,
    required List<EnrollmentRecord> enrollments,
  }) {
    return enrollments.any(
      (e) =>
          e.purchaseType == PurchaseType.individual &&
          e.topicId == topicId,
    );
  }

  /// Get all categories the user has bundle access to
  List<int> getBundleCategories(List<EnrollmentRecord> enrollments) {
    return enrollments
        .where((e) => e.purchaseType == PurchaseType.bundle && e.categoryId != null)
        .map((e) => e.categoryId!)
        .toList();
  }

  /// Find the most relevant enrollment record for a topic
  /// Preference: Bundle > Individual > None
  EnrollmentRecord? _findRelevantEnrollment(
    CourseTopic topic,
    List<EnrollmentRecord> enrollments,
  ) {
    // Check for bundle enrollment for this category
    final bundleEnrollment = enrollments.firstWhere(
      (e) =>
          e.purchaseType == PurchaseType.bundle &&
          e.categoryId == topic.categoryId,
      orElse: () => null as EnrollmentRecord,
    );

    if (bundleEnrollment != null) {
      return bundleEnrollment;
    }

    // Check for individual enrollment for this topic
    return enrollments.firstWhere(
      (e) =>
          e.purchaseType == PurchaseType.individual &&
          e.topicId == topic.id,
      orElse: () => null as EnrollmentRecord,
    );
  }

  /// Purchase a category bundle
  /// 
  /// This will create enrollments for all topics in the category
  Future<bool> purchaseBundle({
    required int userId,
    required int categoryId,
    required String email,
  }) async {
    try {
      final response = await _api.purchaseBundle(
        userId: userId,
        categoryId: categoryId,
        email: email,
      );
      return response.success;
    } catch (e) {
      print('Error purchasing bundle: $e');
      return false;
    }
  }

  /// Purchase an individual topic
  Future<bool> purchaseIndividualTopic({
    required int userId,
    required int topicId,
    required String email,
  }) async {
    try {
      final response = await _api.purchaseIndividualTopic(
        userId: userId,
        topicId: topicId,
        email: email,
      );
      return response.success;
    } catch (e) {
      print('Error purchasing topic: $e');
      return false;
    }
  }
}

/// Helper function to convert string to PurchaseType
PurchaseType _parsePurchaseType(String? value) {
  switch (value?.toLowerCase()) {
    case 'bundle':
      return PurchaseType.bundle;
    case 'individual':
      return PurchaseType.individual;
    case 'free':
      return PurchaseType.free;
    default:
      return PurchaseType.individual;
  }
}

/// Helper function to convert PurchaseType to string
String _purchaseTypeToString(PurchaseType type) {
  return type.toString().split('.').last;
}
