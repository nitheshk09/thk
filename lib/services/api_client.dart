import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ThinkCyberApi {
  ThinkCyberApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AppVersionResponse> checkAppVersion({
    required int currentVersionCode,
    required String platform,
  }) async {
    final path =
        '${ApiConfig.appSettingsVersion}?platform=$platform&currentVersionCode=$currentVersionCode';
    final json = await _getJson(path);
    return AppVersionResponse.fromJson(json);
  }

  Future<SignupResponse> signup({
    required String email,
    required String firstName,
    required String lastName,
  }) async {
    final json = await _postJson(
      path: ApiConfig.authSignup,
      payload: {'email': email, 'firstname': firstName, 'lastname': lastName},
    );

    return SignupResponse.fromJson(json);
  }

  Future<GenericResponse> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    return _postJson(
      path: ApiConfig.authVerifySignupOtp,
      payload: {'email': email, 'otp': otp},
    ).then(GenericResponse.fromJson);
  }

  Future<LoginVerificationResponse> verifyLoginOtp({
    required String email,
    required String otp,
    String? fcmToken,
    String? deviceId,
    String? deviceName,
  }) async {
    return _postJson(
      path: ApiConfig.authVerifyLoginOtp,
      payload: {
        'email': email,
        'otp': otp,
        if (fcmToken != null) 'fcmToken': fcmToken,
        if (deviceId != null) 'deviceId': deviceId,
        if (deviceName != null) 'deviceName': deviceName,
      },
    ).then(LoginVerificationResponse.fromJson);
  }

  Future<GenericResponse> sendLoginOtp({required String email}) async {
    return _postJson(
      path: ApiConfig.authSendLoginOtp,
      payload: {'email': email},
    ).then(GenericResponse.fromJson);
  }

  Future<GenericResponse> resendOtp({required String email}) async {
    return _postJson(
      path: ApiConfig.authResendOtp,
      payload: {'email': email},
    ).then(GenericResponse.fromJson);
  }

  Future<TopicResponse> fetchTopics({int? userId}) async {
    final path = ApiConfig.topicsListWithUser(userId);
    final json = await _getJson(path);
    return TopicResponse.fromJson(json);
  }

  Future<TopicDetailResponse> fetchTopicDetail(int id, {int? userId}) async {
    final path = ApiConfig.topicsDetailWithId(id, userId: userId);
    final json = await _getJson(path);
    return TopicDetailResponse.fromJson(json);
  }

  Future<List<CourseTopic>> fetchUserEnrollments({required int userId}) async {
    final payload = await _getJsonList(ApiConfig.enrollmentsUserEnrollmentsWithId(userId));
    
    // Debug: Print complete raw response
    developer.log('=== COMPLETE /enrollments/user/$userId RESPONSE ===');
    developer.log(jsonEncode(payload));
    developer.log('=== END RESPONSE ===');
    
    if (payload.isEmpty) {
      return const [];
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1';
      }
      return false;
    }

    num parsePrice(dynamic value) {
      if (value is num) return value;
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        return parsed ?? 0;
      }
      return 0;
    }

    return payload
        .map(
          (data) => CourseTopic(
            id: (data['topic_id'] ?? data['id']) as int? ?? 0,
            title: data['title'] as String? ?? '',
            description: data['description'] as String? ?? '',
            categoryId: data['category_id'] as int? ?? 0,
            categoryName: data['category_name'] as String? ?? 'General',
            subcategoryId: data['subcategory_id'] as int?,
            subcategoryName: data['subcategory_name'] as String?,
            difficulty: data['difficulty'] as String? ?? 'Beginner',
            status: data['status'] as String? ?? '',
            isFree: parseBool(data['is_free']),
            isFeatured: parseBool(data['is_featured']),
            price: parsePrice(data['price']),
            durationMinutes: data['duration_minutes'] as int? ?? 0,
            thumbnailUrl: data['thumbnail_url'] as String? ?? '',
            isEnrolled: parseBool(data['is_enrolled'] ?? data['isEnrolled']),
            isPaid: parseBool(data['is_paid'] ?? data['isPaid']),
            paymentStatus: (data['payment_status'] ?? data['paymentStatus'])
                as String?,
          ),
        )
        .toList(growable: false);
  }

  Future<List<UserBundle>> fetchUserBundles({required int userId}) async {
    try {
      final json = await _getJson(ApiConfig.enrollmentsUserBundlesWithId(userId));
      
      // Debug: Print complete raw response
      developer.log('=== COMPLETE /enrollments/user-bundles/$userId RESPONSE ===');
      developer.log(jsonEncode(json));
      developer.log('=== END RESPONSE ===');
      
      final bundles = json['bundles'] as List<dynamic>? ?? [];
      return bundles.map((data) {
        return UserBundle(
          id: data['id'] as int? ?? 0,
          userId: data['user_id'] as int? ?? 0,
          categoryId: data['category_id'] as int? ?? 0,
          categoryName: data['category_name'] as String? ?? '',
          bundlePrice: data['bundle_price'] is String
              ? double.tryParse(data['bundle_price'] as String) ?? 0.0
              : (data['bundle_price'] as num?)?.toDouble() ?? 0.0,
          planType: data['plan_type'] as String? ?? 'BUNDLE',
          paymentStatus: data['payment_status'] as String? ?? '',
          enrolledAt: data['enrolled_at'] as String? ?? '',
          futureTopicsIncluded: data['future_topics_included'] == true ||
              data['future_topics_included'] == 'true' ||
              data['future_topics_included'] == 1,
          accessibleTopicsCount: int.tryParse(data['accessible_topics_count']?.toString() ?? '0') ?? 0,
          description: data['description'] as String? ?? '',
        );
      }).toList();
    } catch (e) {
      developer.log('Error fetching user bundles: $e');
      return const [];
    }
  }

  Future<List<CourseTopic>> fetchCategoryTopicsAccess({
    required int userId,
    required int categoryId,
  }) async {
    try {
      print('=== fetchCategoryTopicsAccess START: user $userId, category $categoryId ===');
      
      // Step 1: Get accessible topic IDs
      final json = await _getJson(ApiConfig.categoryTopicsAccessWithIds(userId, categoryId));
      print('✓ API response received');
      
      // Extract accessible topic IDs from response
      final accessibleTopicIds = json['accessibleTopics'] as List<dynamic>? ?? [];
      print('Accessible topic count: ${accessibleTopicIds.length}');
      print('Accessible IDs: $accessibleTopicIds');
      
      final accessibleIds = <int>{};
      for (var id in accessibleTopicIds) {
        if (id is int) {
          accessibleIds.add(id);
        } else if (id is String) {
          final parsed = int.tryParse(id);
          if (parsed != null) accessibleIds.add(parsed);
        }
      }
      
      print('Converted IDs: $accessibleIds');
      
      if (accessibleIds.isEmpty) {
        print('No accessible topics found');
        return const [];
      }
      
      // Step 2: Fetch ALL topics from /topics endpoint
      print('⏳ Fetching all topics from /topics...');
      final topicsResponse = await fetchTopics(userId: userId);
      print('✓ Fetched ${topicsResponse.topics.length} total topics');
      
      // Step 3: Filter to only include accessible topics
      final accessibleTopics = topicsResponse.topics
          .where((topic) => accessibleIds.contains(topic.id))
          .toList();
      
      print('✅ Filtered to ${accessibleTopics.length} accessible topics');
      for (var t in accessibleTopics) {
        print('  - Topic ${t.id}: ${t.title}');
      }
      
      return accessibleTopics;
    } catch (e, st) {
      print('❌ Error in fetchCategoryTopicsAccess: $e');
      print('Stack trace:\n$st');
      return const [];
    }
  }

  Future<MobileEnrollmentResponse> createMobileEnrollment({
    required int userId,
    required int topicId,
    required String email,
  }) async {
    final json = await _postJson(
      path: ApiConfig.enrollmentsMobileEnroll,
      payload: {
        'userId': userId,
        'topicId': topicId,
        'email': email,
      },
    );

    final rawClientSecret =
        (json['clientSecret'] ?? json['client_secret']) as String?;
    final clientSecret = rawClientSecret?.trim();
    if (clientSecret == null || clientSecret.isEmpty) {
      throw ApiException(
        message: 'Unable to start checkout right now. Please try again.',
        statusCode: 500,
      );
    }

    return MobileEnrollmentResponse(
      clientSecret: clientSecret,
      paymentIntentId:
          (json['paymentIntentId'] ?? json['payment_intent_id']) as String?,
    );
  }

  Future<GenericResponse> enrollFreeCourse({
    required int userId,
    required int topicId,
    required String email,
  }) async {
    final json = await _postJson(
      path: ApiConfig.enrollmentsEnroll,
      payload: {
        'userId': userId,
        'topicId': topicId,
        'email': email,
        'currency': 'INR',
      },
    );

    return GenericResponse.fromJson(json);
  }

  Future<GenericResponse> enrollPaidCourse({
    required int userId,
    required int topicId,
    required String email,
    required String paymentId,
  }) async {
    final json = await _postJson(
      path: ApiConfig.enrollmentsEnroll,
      payload: {
        'userId': userId,
        'topicId': topicId,
        'email': email,
        'currency': 'INR',
      },
    );

    return GenericResponse.fromJson(json);
  }

  /// Create Razorpay order for paid course
  Future<Map<String, dynamic>> createOrderForCourse({
    required int userId,
    required int topicId,
    required String email,
  }) async {
    final json = await _postJson(
      path: ApiConfig.enrollmentsCreateOrder,
      payload: {
        'userId': userId,
        'topicId': topicId,
        'email': email,
      },
    );

    return json;
  }

  /// Verify Razorpay payment and complete enrollment
  Future<GenericResponse> verifyPaymentAndEnroll({
    required int userId,
    required int topicId,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    final json = await _postJson(
      path: ApiConfig.enrollmentsVerifyPayment,
      payload: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'userId': userId,
        'topicId': topicId,
      },
    );

    return GenericResponse.fromJson(json);
  }

  /// Create order for bundle purchase (Razorpay)
  Future<Map<String, dynamic>> createOrderForBundle({
    required int userId,
    required int categoryId,
    required String email,
  }) async {
    final json = await _postJson(
      path: ApiConfig.enrollmentsCreateOrder,
      payload: {
        'userId': userId,
        'categoryId': categoryId,
        'email': email,
        'isBundle': true,
      },
    );

    return json;
  }

  /// Verify Razorpay payment and complete bundle enrollment
  Future<GenericResponse> verifyBundlePaymentAndEnroll({
    required int userId,
    required int categoryId,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    final json = await _postJson(
      path: ApiConfig.enrollmentsVerifyBundlePayment,
      payload: {
        'razorpay_order_id': orderId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
        'userId': userId,
        'categoryId': categoryId,
      },
    );

    return GenericResponse.fromJson(json);
  }

  /// Purchase a bundle directly (non-Razorpay flow)
  Future<GenericResponse> purchaseBundle({
    required int userId,
    required int categoryId,
    required String email,
  }) async {
    final json = await _postJson(
      path: '/enrollments/purchase-bundle',
      payload: {
        'userId': userId,
        'categoryId': categoryId,
        'email': email,
      },
    );

    return GenericResponse.fromJson(json);
  }

  /// Purchase an individual topic (no future topics included)
  Future<GenericResponse> purchaseIndividualTopic({
    required int userId,
    required int topicId,
    required String email,
  }) async {
    final json = await _postJson(
      path: '/enrollments/purchase-individual',
      payload: {
        'userId': userId,
        'topicId': topicId,
        'email': email,
      },
    );

    return GenericResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> _postJson({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    final fullUrl = ApiConfig.buildUrl(path);
    final uri = Uri.parse(fullUrl);

    _log('📤 POST Request → $path');
    _log('🔗 Full URL → $fullUrl');
    _log('📦 Payload → ${jsonEncode(payload)}');

    final response = await _client.post(
      uri,
      headers: ApiConfig.defaultHeaders,
      body: jsonEncode(payload),
    );

    _log(
      '📥 Response ← ${response.statusCode} $path ${_truncateResponse(response.body)}',
      isError: response.statusCode >= 400,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException(
      message: _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final fullUrl = ApiConfig.buildUrl(path);
    final uri = Uri.parse(fullUrl);

    _log('📤 GET Request → $path');
    _log('🔗 Full URL → $fullUrl');

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    _log(
      '📥 Response ← ${response.statusCode} $path ${_truncateResponse(response.body)}',
      isError: response.statusCode >= 400,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException(
      message: _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<List<Map<String, dynamic>>> _getJsonList(String path) async {
    final fullUrl = ApiConfig.buildUrl(path);
    final uri = Uri.parse(fullUrl);

    _log('📤 GET List Request → $path');
    _log('🔗 Full URL → $fullUrl');

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    _log(
      '📥 Response ← ${response.statusCode} $path ${_truncateResponse(response.body)}',
      isError: response.statusCode >= 400,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
        }
      }
      return const [];
    }

    throw ApiException(
      message: _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }
  /// Fetch homepage data including FAQs and contact details
  Future<HomepageResponse> fetchHomepage({String languageCode = 'en'}) async {
    final endpoint = '/homepage/$languageCode';
    final json = await _getJson(endpoint);
    return HomepageResponse.fromJson(json);
  }

  /// Fetch active feature plans
  Future<FeaturePlansResponse> fetchFeaturePlans() async {
    final endpoint = '/features-plans/active';
    final json = await _getJson(endpoint);
    return FeaturePlansResponse.fromJson(json);
  }

  /// Fetch categories/bundles
  Future<CategoriesResponse> fetchCategories() async {
    final endpoint = '/categories';
    final json = await _getJson(endpoint);
    return CategoriesResponse.fromJson(json);
  }

  void dispose() {
    _client.close();
  }

  String _extractErrorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        // Check for 'error' field first (as used in your API)
        final error = json['error'];
        if (error is String && error.isNotEmpty) {
          return error;
        }
        // Fallback to 'message' field
        final message = json['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Ignore parsing errors and fall back to generic message.
    }
    return 'Something went wrong. Please try again.';
  }
}

void _log(String message, {bool isError = false}) {
  if (!ApiConfig.isLoggingEnabled) return;
  
  developer.log(
    message,
    name: 'ThinkCyberApi[${ApiConfig.environmentName}]',
    level: isError ? 1000 : 0,
  );
  
  final timestamp = DateTime.now().toIso8601String().substring(11, 23);
  final levelIcon = isError ? '❌' : '✅';
  debugPrint('[$timestamp] $levelIcon ThinkCyberApi[${ApiConfig.environmentName}] | $message');
}

/// Truncate response body for logging to avoid overwhelming logs
String _truncateResponse(String body, {int maxLength = 200}) {
  if (body.length <= maxLength) return body;
  return '${body.substring(0, maxLength)}... [${body.length - maxLength} more chars]';
}

class SignupResponse {
  SignupResponse({
    required this.success,
    required this.message,
    required this.user,
  });

  final bool success;
  final String message;
  final SignupUser user;

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      user: SignupUser.fromJson(
        json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class GenericResponse {
  GenericResponse({required this.success, required this.message});

  final bool success;
  final String message;

  factory GenericResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? false;
    final messageCandidate = json['message'] ?? json['error'];
    final message = messageCandidate is String && messageCandidate.isNotEmpty
        ? messageCandidate
        : (success ? 'Success' : 'Request failed');

    return GenericResponse(success: success, message: message);
  }
}

class MobileEnrollmentResponse {
  MobileEnrollmentResponse({
    required this.clientSecret,
    this.paymentIntentId,
  });

  final String clientSecret;
  final String? paymentIntentId;
}

class SignupUser {
  SignupUser({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.role,
    this.avatar,
  });

  final int id;
  final String name;
  final String email;
  final String status;
  final String role;
  final String? avatar;

  factory SignupUser.fromJson(Map<String, dynamic> json) {
    return SignupUser(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'status': status,
    'role': role,
    if (avatar != null) 'avatar': avatar,
  };
}

class LoginVerificationResponse {
  LoginVerificationResponse({
    required this.success,
    required this.message,
    this.user,
    this.sessionToken,
  });

  final bool success;
  final String message;
  final SignupUser? user;
  final String? sessionToken;

  factory LoginVerificationResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] as bool? ?? false;
    final messageCandidate = json['message'] ?? json['error'];
    final message = messageCandidate is String && messageCandidate.isNotEmpty
        ? messageCandidate
        : (success ? 'Success' : 'Request failed');

    return LoginVerificationResponse(
      success: success,
      message: message,
      sessionToken: json['sessionToken'] as String?,
      user: json['user'] is Map<String, dynamic>
          ? SignupUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TopicResponse {
  TopicResponse({required this.success, required this.topics});

  final bool success;
  final List<CourseTopic> topics;

  factory TopicResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return TopicResponse(
      success: json['success'] as bool? ?? false,
      topics: data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(CourseTopic.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class CourseTopic {
  CourseTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.difficulty,
    required this.status,
    required this.isFree,
    required this.isFeatured,
    required this.price,
    required this.durationMinutes,
    required this.thumbnailUrl,
    this.isEnrolled = false,
    this.isPaid = false,
    this.paymentStatus,
  });

  final int id;
  final String title;
  final String description;
  final int categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String? subcategoryName;
  final String difficulty;
  final String status;
  final bool isFree;
  final bool isFeatured;
  final num price;
  final int durationMinutes;
  final String thumbnailUrl;
  final bool isEnrolled;
  final bool isPaid;
  final String? paymentStatus;

  factory CourseTopic.fromJson(Map<String, dynamic> json) {
    String? _string(List<String> keys, {String? fallback}) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
      return fallback;
    }

    T _value<T>(List<String> keys, {required T fallback}) {
      for (final key in keys) {
        final value = json[key];
        if (value is T) {
          return value;
        }
      }
      return fallback;
    }

    bool _bool(List<String> keys, {required bool fallback}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) {
          return value;
        }
        if (value is String) {
          final normalized = value.trim().toLowerCase();
          if (normalized == 'true' || normalized == '1') {
            return true;
          }
          if (normalized == 'false' || normalized == '0') {
            return false;
          }
        }
        if (value is num) {
          return value != 0;
        }
      }
      return fallback;
    }

    num _num(List<String> keys, {required num fallback}) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) {
          return value;
        }
        if (value is String) {
          final parsed = num.tryParse(value);
          if (parsed != null) {
            return parsed;
          }
        }
      }
      return fallback;
    }

    return CourseTopic(
      id: _value<int>(['id'], fallback: 0),
      title: _string(['title'], fallback: '') ?? '',
      description: _string(['description'], fallback: '') ?? '',
      categoryId: _value<int>(['categoryId', 'category_id'], fallback: 0),
      categoryName:
          _string(['categoryName', 'category_name'], fallback: 'General') ??
              'General',
      subcategoryId: _value<int?>(['subcategoryId', 'subcategory_id'], fallback: null),
      subcategoryName:
          _string(['subcategoryName', 'subcategory_name']),
      difficulty:
          _string(['difficulty'], fallback: 'Beginner') ?? 'Beginner',
      status: _string(['status'], fallback: '') ?? '',
      isFree: _bool(['isFree', 'is_free'], fallback: false),
      isFeatured: _bool(['isFeatured', 'is_featured'], fallback: false),
      price: _num(['price'], fallback: 0),
      durationMinutes:
          _value<int>(['durationMinutes', 'duration_minutes'], fallback: 0),
      thumbnailUrl:
          _string(['thumbnailUrl', 'thumbnail_url'], fallback: '') ?? '',
      isEnrolled: _bool(['isEnrolled', 'is_enrolled'], fallback: false),
      isPaid: _bool(['isPaid', 'is_paid'], fallback: false),
      paymentStatus:
          _string(['paymentStatus', 'payment_status'], fallback: null),
    );
  }

  CourseTopic copyWith({
    int? id,
    String? title,
    String? description,
    int? categoryId,
    String? categoryName,
    int? subcategoryId,
    String? subcategoryName,
    String? difficulty,
    String? status,
    bool? isFree,
    bool? isFeatured,
    num? price,
    int? durationMinutes,
    String? thumbnailUrl,
    bool? isEnrolled,
    bool? isPaid,
    String? paymentStatus,
  }) {
    return CourseTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      isFree: isFree ?? this.isFree,
      isFeatured: isFeatured ?? this.isFeatured,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      isPaid: isPaid ?? this.isPaid,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}

class TopicDetailResponse {
  TopicDetailResponse({required this.success, required this.topic});

  final bool success;
  final TopicDetail topic;

  factory TopicDetailResponse.fromJson(Map<String, dynamic> json) {
    return TopicDetailResponse(
      success: json['success'] as bool? ?? false,
      topic: TopicDetail.fromJson(
        json['data'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class TopicDetail {
  TopicDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.difficulty,
    required this.status,
    required this.isFree,
    required this.price,
    required this.durationMinutes,
    required this.thumbnailUrl,
    required this.isFeatured,
    required this.isPaid,
    required this.isEnrolled,
    required this.paymentStatus,
    required this.learningObjectives,
    required this.targetAudience,
    required this.prerequisites,
    required this.modules,
  });

  final int id;
  final String title;
  final String description;
  final int categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String? subcategoryName;
  final String difficulty;
  final String status;
  final bool isFree;
  final num price;
  final int durationMinutes;
  final String thumbnailUrl;
  final bool isFeatured;
  final bool isPaid;
  final bool isEnrolled;
  final String? paymentStatus;
  final String learningObjectives;
  final List<String> targetAudience;
  final String prerequisites;
  final List<TopicModule> modules;

  TopicDetail copyWith({
    int? id,
    String? title,
    String? description,
    int? categoryId,
    String? categoryName,
    int? subcategoryId,
    String? subcategoryName,
    String? difficulty,
    String? status,
    bool? isFree,
    num? price,
    int? durationMinutes,
    String? thumbnailUrl,
    bool? isFeatured,
    bool? isPaid,
    bool? isEnrolled,
    String? paymentStatus,
    String? learningObjectives,
    List<String>? targetAudience,
    String? prerequisites,
    List<TopicModule>? modules,
  }) {
    return TopicDetail(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      isFree: isFree ?? this.isFree,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isFeatured: isFeatured ?? this.isFeatured,
      isPaid: isPaid ?? this.isPaid,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      learningObjectives: learningObjectives ?? this.learningObjectives,
      targetAudience: targetAudience ?? this.targetAudience,
      prerequisites: prerequisites ?? this.prerequisites,
      modules: modules ?? this.modules,
    );
  }

  factory TopicDetail.fromJson(Map<String, dynamic> json) {
    String? readString(List<String> keys, {String? fallback}) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
      return fallback;
    }

    num readNum(List<String> keys, {required num fallback}) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) {
          return value;
        }
        if (value is String) {
          final parsed = num.tryParse(value);
          if (parsed != null) {
            return parsed;
          }
        }
      }
      return fallback;
    }

    bool readBool(List<String> keys, {required bool fallback}) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) {
          return value;
        }
        if (value is String) {
          final normalized = value.trim().toLowerCase();
          if (normalized == 'true' || normalized == '1') {
            return true;
          }
          if (normalized == 'false' || normalized == '0') {
            return false;
          }
        }
        if (value is num) {
          return value != 0;
        }
      }
      return fallback;
    }

    List<String> readStringList(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is List) {
          return value.whereType<String>().toList(growable: false);
        }
      }
      return const [];
    }

    return TopicDetail(
      id: json['id'] as int? ?? 0,
      title: readString(['title'], fallback: '') ?? '',
      description: readString(['description'], fallback: '') ?? '',
      categoryId: json['categoryId'] as int? ?? json['category_id'] as int? ?? 0,
      categoryName:
          readString(['categoryName', 'category_name'], fallback: 'General') ??
              'General',
      subcategoryId: json['subcategoryId'] as int? ?? json['subcategory_id'] as int?,
      subcategoryName:
          readString(['subcategoryName', 'subcategory_name']),
      difficulty: readString(['difficulty'], fallback: 'Beginner') ?? 'Beginner',
      status: readString(['status'], fallback: '') ?? '',
      isFree: readBool(['isFree', 'is_free'], fallback: false),
      price: readNum(['price'], fallback: 0),
      durationMinutes:
          json['durationMinutes'] as int? ?? json['duration_minutes'] as int? ?? 0,
      thumbnailUrl:
          readString(['thumbnailUrl', 'thumbnail_url'], fallback: '') ?? '',
      isFeatured: readBool(['isFeatured', 'is_featured'], fallback: false),
      isPaid: readBool(['isPaid', 'is_paid'], fallback: false),
      isEnrolled: readBool(['isEnrolled', 'is_enrolled'], fallback: false),
      paymentStatus:
          readString(['paymentStatus', 'payment_status'], fallback: null),
      learningObjectives:
          readString(['learningObjectives', 'learning_objectives'], fallback: '') ??
              '',
      targetAudience:
          readStringList(['targetAudience', 'target_audience']),
      prerequisites:
          readString(['prerequisites'], fallback: '') ?? '',
      modules:
          (json['modules'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(TopicModule.fromJson)
              .toList(growable: false) ??
          const [],
    );
  }
}

class TopicModule {
  TopicModule({
    required this.id,
    required this.title,
    required this.description,
    required this.videos,
    this.orderIndex = 0,
    this.isActive = true,
    this.isEnrolled = false,
    this.durationMinutes = 0,
  });

  final int id;
  final String title;
  final String description;
  final List<TopicVideo> videos;
  final int orderIndex;
  final bool isActive;
  final bool isEnrolled;
  final int durationMinutes;

  factory TopicModule.fromJson(Map<String, dynamic> json) {
    return TopicModule(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      orderIndex: json['orderIndex'] as int? ?? json['order_index'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
      isEnrolled:
          json['isEnrolled'] as bool? ?? json['is_enrolled'] as bool? ?? false,
      durationMinutes:
          json['durationMinutes'] as int? ?? json['duration_minutes'] as int? ?? 0,
      videos:
          (json['videos'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(TopicVideo.fromJson)
              .toList(growable: false) ??
          const [],
    );
  }
}

class TopicVideo {
  TopicVideo({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
  });

  final int id;
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;

  factory TopicVideo.fromJson(Map<String, dynamic> json) {
    String? readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    return TopicVideo(
      id: json['id'] as int? ?? 0,
      title: readString(['title']) ?? '',
      videoUrl: readString(['videoUrl', 'video_url']) ?? '',
      thumbnailUrl: readString(['thumbnailUrl', 'thumbnail_url']),
    );
  }
}

class ApiException implements Exception {
  ApiException({required this.message, required this.statusCode});

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// Homepage API Models
class HomepageResponse {
  HomepageResponse({
    required this.success,
    required this.data,
  });

  final bool success;
  final HomepageData data;

  factory HomepageResponse.fromJson(Map<String, dynamic> json) {
    return HomepageResponse(
      success: json['success'] as bool? ?? false,
      data: HomepageData.fromJson(
        json['data'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class HomepageData {
  HomepageData({
    required this.id,
    required this.language,
    required this.hero,
    required this.about,
    required this.contact,
    required this.faqs,
  });

  final String id;
  final String language;
  final HeroSection hero;
  final About about;
  final Contact contact;
  final List<FAQ> faqs;

  factory HomepageData.fromJson(Map<String, dynamic> json) {
    return HomepageData(
      id: json['id'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      hero: HeroSection.fromJson(
        json['hero'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      about: About.fromJson(
        json['about'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      contact: Contact.fromJson(
        json['contact'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      faqs: (json['faqs'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(FAQ.fromJson)
              .toList() ??
          [],
    );
  }
}

class HeroSection {
  HeroSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.backgroundImage,
  });

  final String id;
  final String title;
  final String subtitle;
  final String backgroundImage;

  factory HeroSection.fromJson(Map<String, dynamic> json) {
    return HeroSection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      backgroundImage: json['backgroundImage'] as String? ?? '',
    );
  }
}

class About {
  About({
    required this.id,
    required this.title,
    required this.content,
    required this.image,
    required this.features,
  });

  final String id;
  final String title;
  final String content;
  final String image;
  final List<dynamic> features;

  factory About.fromJson(Map<String, dynamic> json) {
    return About(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      image: json['image'] as String? ?? '',
      features: json['features'] as List? ?? [],
    );
  }
}

class Contact {
  Contact({
    required this.id,
    required this.email,
    required this.phone,
    required this.address,
    required this.hours,
    required this.description,
    required this.supportEmail,
    required this.salesEmail,
    required this.socialLinks,
  });

  final String id;
  final String email;
  final String phone;
  final String? address;
  final String? hours;
  final String? description;
  final String supportEmail;
  final String salesEmail;
  final Map<String, dynamic> socialLinks;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String?,
      hours: json['hours'] as String?,
      description: json['description'] as String?,
      supportEmail: json['supportEmail'] as String? ?? '',
      salesEmail: json['salesEmail'] as String? ?? '',
      socialLinks: json['socialLinks'] as Map<String, dynamic>? ?? {},
    );
  }
}

class FAQ {
  FAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.order,
    required this.isActive,
  });

  final String id;
  final String question;
  final String answer;
  final int order;
  final bool isActive;

  factory FAQ.fromJson(Map<String, dynamic> json) {
    return FAQ(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class FeaturePlan {
  FeaturePlan({
    required this.id,
    required this.name,
    required this.features,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String features;
  final String description;
  final String status;
  final String createdAt;
  final String updatedAt;

  factory FeaturePlan.fromJson(Map<String, dynamic> json) {
    return FeaturePlan(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      features: json['features'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class FeaturePlansResponse {
  FeaturePlansResponse({
    required this.success,
    required this.data,
  });

  final bool success;
  final List<FeaturePlan> data;

  factory FeaturePlansResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    return FeaturePlansResponse(
      success: json['success'] as bool? ?? false,
      data: dataList
          .map((item) => FeaturePlan.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CourseCategory {
  CourseCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.topicsCount,
    required this.planType,
    required this.bundlePrice,
    required this.price,
    required this.flexiblePurchase,
    required this.displayOrder,
  });

  final int id;
  final String name;
  final String description;
  final int topicsCount;
  final String planType;
  final String bundlePrice;
  final String? price;
  final bool flexiblePurchase;
  final int displayOrder;

  factory CourseCategory.fromJson(Map<String, dynamic> json) {
    return CourseCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      topicsCount: json['topics_count'] as int? ?? 0,
      planType: json['plan_type'] as String? ?? 'FLEXIBLE',
      bundlePrice: json['bundle_price'] as String? ?? '0.00',
      price: json['price'] as String?,
      flexiblePurchase: json['flexible_purchase'] as bool? ?? false,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }
}

class CategoriesResponse {
  CategoriesResponse({
    required this.success,
    required this.data,
  });

  final bool success;
  final List<CourseCategory> data;

  factory CategoriesResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List<dynamic>? ?? [];
    return CategoriesResponse(
      success: json['success'] as bool? ?? false,
      data: dataList
          .map((item) => CourseCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
class UserBundle {
  UserBundle({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.bundlePrice,
    required this.planType,
    required this.paymentStatus,
    required this.enrolledAt,
    required this.futureTopicsIncluded,
    required this.accessibleTopicsCount,
    required this.description,
  });

  final int id;
  final int userId;
  final int categoryId;
  final String categoryName;
  final double bundlePrice;
  final String planType; // BUNDLE, FLEXIBLE, FREE
  final String paymentStatus;
  final String enrolledAt;
  final bool futureTopicsIncluded;
  final int accessibleTopicsCount;
  final String description;
}

class AppVersionResponse {
  AppVersionResponse({
    required this.success,
    required this.message,
    this.data,
  });

  final bool success;
  final String message;
  final AppVersionInfo? data;

  factory AppVersionResponse.fromJson(Map<String, dynamic> json) {
    return AppVersionResponse(
      success: json['success'] == true,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? AppVersionInfo.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AppVersionInfo {
  AppVersionInfo({
    required this.message,
    required this.forceUpdate,
    required this.updateRequired,
    required this.minVersionCode,
    required this.latestVersionCode,
    this.latestVersionName,
    this.iosStoreUrl,
    this.androidStoreUrl,
  });

  final String message;
  final bool forceUpdate;
  final bool updateRequired;
  final int minVersionCode;
  final int latestVersionCode;
  final String? latestVersionName;
  final String? iosStoreUrl;
  final String? androidStoreUrl;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      message: json['message'] as String? ?? '',
      forceUpdate: json['forceUpdate'] == true,
      updateRequired: json['updateRequired'] == true,
      minVersionCode: (json['minVersionCode'] as num?)?.toInt() ?? 0,
      latestVersionCode: (json['latestVersionCode'] as num?)?.toInt() ?? 0,
      latestVersionName: json['latestVersionName'] as String?,
      iosStoreUrl: json['iosStoreUrl'] as String?,
      androidStoreUrl: json['androidStoreUrl'] as String?,
    );
  }
}
