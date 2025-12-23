// lib/config/api_config.dart

/// Centralized API configuration for the ThinkCyber application.
/// 
/// This file contains all API endpoints and configuration settings.
/// To switch between environments (development, staging, production),
/// simply change the [currentEnvironment] variable.
class ApiConfig {
  
  // ==================== ENVIRONMENT CONFIGURATION ====================
  
  /// Current active environment
  /// Change this to switch between different API environments
  static const ApiEnvironment currentEnvironment = ApiEnvironment.development;
  
  // ==================== ENVIRONMENT DEFINITIONS ====================
  
  /// Available API environments
  static const Map<ApiEnvironment, EnvironmentConfig> _environments = {
    ApiEnvironment.development: EnvironmentConfig(
      name: 'Development',
      baseUrl: 'https://api.thinkcyber.info/api',
      timeout: Duration(seconds: 30),
      enableLogging: true,
    ),
    
    ApiEnvironment.staging: EnvironmentConfig(
      name: 'Staging',
      baseUrl: 'https://staging.thinkcyber.com/api',
      timeout: Duration(seconds: 25),
      enableLogging: true,
    ),
    
    ApiEnvironment.production: EnvironmentConfig(
      name: 'Production',
      baseUrl: 'https://api.thinkcyber.com/v1',
      timeout: Duration(seconds: 20),
      enableLogging: false,
    ),
  };
  
  // ==================== CURRENT CONFIGURATION ====================
  
  /// Get current environment configuration
  static EnvironmentConfig get current => _environments[currentEnvironment]!;
  
  /// Current base URL
  static String get baseUrl => current.baseUrl;
  
  /// Current timeout duration
  static Duration get timeout => current.timeout;
  
  /// Whether logging is enabled in current environment
  static bool get isLoggingEnabled => current.enableLogging;
  
  /// Current environment name
  static String get environmentName => current.name;
  
  // ==================== API ENDPOINTS ====================
  
  /// Authentication endpoints
  static const String authSignup = '/auth/signup';
  static const String authSendLoginOtp = '/auth/send-otp';
  static const String authVerifyLoginOtp = '/auth/verify-otp';
  static const String authVerifySignupOtp = '/auth/verify-signup-otp';
  static const String authResendOtp = '/auth/resend-otp';
  static const String authLogout = '/auth/logout';
  static const String authRefreshToken = '/auth/refresh-token';
  
  /// App settings endpoints
  static const String appSettingsVersion = '/app-settings/version';
  
  /// Grouped endpoint helpers for convenience
  static const AuthEndpoints Auth = AuthEndpoints();
  static const TopicEndpoints Topics = TopicEndpoints();
  static const EnrollmentEndpoints Enrollments = EnrollmentEndpoints();
  
  /// Topics/Courses endpoints
  static const String topicsList = '/topics';
  static const String topicsDetail = '/topics'; // Will be appended with /{id}
  
  /// Get topics list endpoint with optional userId parameter
  static String topicsListWithUser(int? userId) => 
      userId != null ? '$topicsList?limit=100000' : topicsList;
  
  /// Get topic detail endpoint with ID and optional userId parameter
  static String topicsDetailWithId(int id, {int? userId}) =>
      userId != null ? '$topicsDetail/$id?userId=$userId' : '$topicsDetail/$id';
  
  /// Enrollment endpoints
  static const String enrollmentsMobileEnroll = '/enrollments/mobile-enroll';
  static const String enrollmentsEnrollFree = '/enrollments/enroll-free';
  static const String enrollmentsEnroll = '/enrollments/enroll';
  static const String enrollmentsCreateOrder = '/enrollments/create-order';
  static const String enrollmentsVerifyPayment = '/enrollments/verify-payment';
  static const String enrollmentsVerifyBundlePayment = '/enrollments/verify-bundle-payment';
  static const String enrollmentsUserEnrollments = '/enrollments/user'; // Will be appended with /{userId}
  static const String enrollmentsUserBundles = '/enrollments/user-bundles'; // Will be appended with /{userId}
  static const String categoryTopicsAccess = '/enrollments/category-topics-access'; // Will be appended with /{userId}/{categoryId}
  
  /// Get user enrollments endpoint with userId
  static String enrollmentsUserEnrollmentsWithId(int userId) => '$enrollmentsUserEnrollments/$userId';
  
  /// Get user bundles endpoint with userId
  static String enrollmentsUserBundlesWithId(int userId) => '$enrollmentsUserBundles/$userId';
  
  /// Get category topics access endpoint with userId and categoryId
  static String categoryTopicsAccessWithIds(int userId, int categoryId) =>
      '$categoryTopicsAccess/$userId/$categoryId';
  
  /// Payment endpoints
  static const String paymentsCreateIntent = '/payments/create-intent';
  static const String paymentsConfirmPayment = '/payments/confirm';
  static const String paymentsPaymentHistory = '/payments/history';
  static const String paymentsRefund = '/payments/refund';
  
  /// User profile endpoints
  static const String userProfile = '/user/profile';
  static const String userUpdateProfile = '/user/update';
  static const String userChangePassword = '/user/change-password';
  static const String userDeleteAccount = '/user/delete';
  
  /// Analytics endpoints
  static const String analyticsTrackEvent = '/analytics/track';
  static const String analyticsUserProgress = '/analytics/progress';
  
  // ==================== THIRD-PARTY API CONFIGURATIONS ====================
  
  /// Google Translate API configuration
  static const String googleTranslateBaseUrl = 'https://translate.googleapis.com';
  static const String googleTranslateEndpoint = '/translate_a/single';
  
  /// Build complete Google Translate URL
  static String buildGoogleTranslateUrl(String text, String fromLang, String toLang) {
    return '$googleTranslateBaseUrl$googleTranslateEndpoint?client=gtx&sl=$fromLang&tl=$toLang&dt=t&q=${Uri.encodeComponent(text)}';
  }
  
  /// Stripe configuration
  // Note: These should be loaded from environment variables or secure storage
  static const String stripePublishableKeyDev = 'pk_test_your_dev_key_here';
  static const String stripePublishableKeyProd = 'pk_live_your_prod_key_here';
  
  /// Get appropriate Stripe publishable key based on environment
  static String get stripePublishableKey {
    return currentEnvironment == ApiEnvironment.production
        ? stripePublishableKeyProd
        : stripePublishableKeyDev;
  }
  
  // ==================== HELPER METHODS ====================
  
  /// Build complete URL from endpoint
  static String buildUrl(String endpoint) {
    final fullUrl = '$baseUrl$endpoint';
    _logUrlBuild(endpoint, fullUrl);
    return fullUrl;
  }
  
  /// Build complete URL with query parameters
  static String buildUrlWithParams(String endpoint, Map<String, dynamic> params) {
    final uri = Uri.parse('$baseUrl$endpoint');
    final newUri = uri.replace(queryParameters: 
        params.map((key, value) => MapEntry(key, value.toString())));
    final fullUrl = newUri.toString();
    _logUrlBuildWithParams(endpoint, params, fullUrl);
    return fullUrl;
  }
  
  /// Get headers for API requests
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'ThinkCyber-Mobile/1.0.0',
  };
  
  /// Get headers with authentication token
  static Map<String, String> getAuthHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };
  
  /// Check if current environment is production
  static bool get isProduction => currentEnvironment == ApiEnvironment.production;
  
  /// Check if current environment is development
  static bool get isDevelopment => currentEnvironment == ApiEnvironment.development;
  
  /// Check if current environment is staging
  static bool get isStaging => currentEnvironment == ApiEnvironment.staging;
  
  // ==================== LOGGING METHODS ====================
  
  /// Log configuration information at startup
  static void logConfiguration() {
    if (!isLoggingEnabled) return;
    
    _log('🔧 API Configuration Initialized');
    _log('🌍 Environment: $environmentName');
    _log('🔗 Base URL: $baseUrl');
    _log('⏱️  Timeout: ${timeout.inSeconds}s');
    _log('📝 Logging: ${isLoggingEnabled ? 'Enabled' : 'Disabled'}');
    _log('🔒 Production Mode: ${isProduction ? 'Yes' : 'No'}');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
  
  /// Log URL building for endpoint tracking
  static void _logUrlBuild(String endpoint, String fullUrl) {
    if (!isLoggingEnabled) return;
    _log('🔗 URL Built: $endpoint → $fullUrl');
  }
  
  /// Log URL building with parameters
  static void _logUrlBuildWithParams(String endpoint, Map<String, dynamic> params, String fullUrl) {
    if (!isLoggingEnabled) return;
    final paramString = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    _log('🔗 URL Built with params: $endpoint?$paramString → $fullUrl');
  }
  
  /// Core logging method
  static void _log(String message) {
    print('[ApiConfig] $message');
  }
}

// ==================== SUPPORTING CLASSES ====================

/// API Environment enumeration
enum ApiEnvironment {
  development,
  staging,
  production,
}

/// Environment configuration class
class EnvironmentConfig {
  const EnvironmentConfig({
    required this.name,
    required this.baseUrl,
    required this.timeout,
    required this.enableLogging,
  });

  final String name;
  final String baseUrl;
  final Duration timeout;
  final bool enableLogging;
}

/// Auth endpoint accessors (namespaced convenience)
class AuthEndpoints {
  const AuthEndpoints();

  String get signup => ApiConfig.authSignup;
  String get sendLoginOtp => ApiConfig.authSendLoginOtp;
  String get verifyLoginOtp => ApiConfig.authVerifyLoginOtp;
  String get verifySignupOtp => ApiConfig.authVerifySignupOtp;
  String get resendOtp => ApiConfig.authResendOtp;
  String get logout => ApiConfig.authLogout;
  String get refreshToken => ApiConfig.authRefreshToken;
}

/// Topic endpoint accessors (namespaced convenience)
class TopicEndpoints {
  const TopicEndpoints();

  String get list => ApiConfig.topicsList;
  String listWithUser(int? userId) => ApiConfig.topicsListWithUser(userId);
  String detail(int id) => ApiConfig.topicsDetailWithId(id);
  String detailWithUser(int id, {int? userId}) =>
      ApiConfig.topicsDetailWithId(id, userId: userId);
}

/// Enrollment endpoint accessors (namespaced convenience)
class EnrollmentEndpoints {
  const EnrollmentEndpoints();

  String get mobileEnroll => ApiConfig.enrollmentsMobileEnroll;
  String get enrollFree => ApiConfig.enrollmentsEnrollFree;
  String get enroll => ApiConfig.enrollmentsEnroll;
  String get createOrder => ApiConfig.enrollmentsCreateOrder;
  String get verifyPayment => ApiConfig.enrollmentsVerifyPayment;
  String get verifyBundlePayment => ApiConfig.enrollmentsVerifyBundlePayment;
  String userEnrollments(int userId) =>
      ApiConfig.enrollmentsUserEnrollmentsWithId(userId);
  String userBundles(int userId) =>
      ApiConfig.enrollmentsUserBundlesWithId(userId);
  String categoryTopicsAccess(int userId, int categoryId) =>
      ApiConfig.categoryTopicsAccessWithIds(userId, categoryId);
}

// ==================== USAGE EXAMPLES ====================

/// Example usage:
/// 
/// ```dart
/// // Get current base URL
/// String apiUrl = ApiConfig.baseUrl;
/// 
/// // Build endpoint URL
/// String signupUrl = ApiConfig.buildUrl(ApiConfig.Auth.signup);
/// 
/// // Build URL with parameters
/// String topicsUrl = ApiConfig.buildUrlWithParams(
///   ApiConfig.Topics.list, 
///   {'userId': 123, 'limit': 10}
/// );
/// 
/// // Get appropriate headers
/// Map<String, String> headers = ApiConfig.defaultHeaders;
/// Map<String, String> authHeaders = ApiConfig.getAuthHeaders('your_token');
/// 
/// // Use specific endpoints
/// String topicDetailUrl = ApiConfig.buildUrl(
///   ApiConfig.Topics.detailWithId(5, userId: 123)
/// );
/// ```
