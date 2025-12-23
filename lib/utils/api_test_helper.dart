// lib/utils/api_test_helper.dart

import '../config/api_config.dart';
import '../services/api_client.dart';

/// Utility class to help test and verify API configuration
class ApiTestHelper {
  
  /// Print current API configuration details
  static void printCurrentConfiguration() {
    print('');
    print('🔧 ═══════════════════════════════════════════════════════════');
    print('🔧 API CONFIGURATION TEST');
    print('🔧 ═══════════════════════════════════════════════════════════');
    print('🌍 Environment: ${ApiConfig.environmentName}');
    print('🔗 Base URL: ${ApiConfig.baseUrl}');
    print('⏱️  Timeout: ${ApiConfig.timeout.inSeconds} seconds');
    print('📝 Logging Enabled: ${ApiConfig.isLoggingEnabled}');
    print('🔒 Is Production: ${ApiConfig.isProduction}');
    print('🔧 ═══════════════════════════════════════════════════════════');
    print('');
    
    // Test URL building
    print('📍 ENDPOINT URL TESTS:');
    print('   Auth Signup: ${ApiConfig.buildUrl(ApiConfig.authSignup)}');
    print('   Topics List: ${ApiConfig.buildUrl(ApiConfig.topicsList)}');
    print('   Topics with User: ${ApiConfig.buildUrl(ApiConfig.topicsListWithUser(123))}');
    print('   Topic Detail: ${ApiConfig.buildUrl(ApiConfig.topicsDetailWithId(456, userId: 123))}');
    print('   User Enrollments: ${ApiConfig.buildUrl(ApiConfig.enrollmentsUserEnrollmentsWithId(789))}');
    print('');
  }
  
  /// Test a simple API call to verify the configuration works
  static Future<void> testApiCall() async {
    print('🧪 Testing API call with current configuration...');
    
    final api = ThinkCyberApi();
    
    try {
      // Try to fetch topics (this will show in logs which URL is being called)
      print('🔄 Making test API call to fetch topics...');
      final response = await api.fetchTopics(userId: 999);
      
      if (response.success) {
        print('✅ API call successful! Got ${response.topics.length} topics');
      } else {
        print('⚠️  API call returned success=false, but connection worked');
      }
      
    } catch (e) {
      print('❌ API call failed: $e');
      print('   This might be expected if the new URL is not yet ready');
      print('   Check the logs above to see which URL was actually called');
    } finally {
      api.dispose();
    }
    
    print('');
  }
  
  /// Show environment comparison
  static void showEnvironmentComparison() {
    print('🌍 ═══════════════════════════════════════════════════════════');
    print('🌍 ENVIRONMENT COMPARISON');
    print('🌍 ═══════════════════════════════════════════════════════════');
    
    const environments = ApiEnvironment.values;
    
    for (final env in environments) {
      final oldCurrent = ApiConfig.currentEnvironment;
      
      // Temporarily get config for each environment (this is just for display)
      print('');
      if (env == ApiConfig.currentEnvironment) {
        print('🟢 ${env.name} (CURRENT ACTIVE ENVIRONMENT)');
      } else {
        print('⚪ ${env.name}');
      }
      
      // Note: We can't actually change the environment at runtime,
      // but we can show what each would be
      switch (env) {
        case ApiEnvironment.development:
          print('   Base URL: https://api.thinkcyber.info/api');
          print('   Timeout: 30s');
          print('   Logging: Enabled');
          break;
        case ApiEnvironment.staging:
          print('   Base URL: https://staging.thinkcyber.com/api');
          print('   Timeout: 25s');
          print('   Logging: Enabled');
          break;
        case ApiEnvironment.production:
          print('   Base URL: https://api.thinkcyber.com/v1');
          print('   Timeout: 20s');
          print('   Logging: Disabled');
          break;
      }
    }
    print('🌍 ═══════════════════════════════════════════════════════════');
    print('');
  }
  
  /// Show all available endpoints with their full URLs
  static void showAllEndpoints() {
    print('🎯 ═══════════════════════════════════════════════════════════');
    print('🎯 ALL AVAILABLE ENDPOINTS');
    print('🎯 ═══════════════════════════════════════════════════════════');
    
    print('');
    print('🔐 Authentication Endpoints:');
    print('   Signup: ${ApiConfig.buildUrl(ApiConfig.authSignup)}');
    print('   Send OTP: ${ApiConfig.buildUrl(ApiConfig.authSendLoginOtp)}');
    print('   Verify Login OTP: ${ApiConfig.buildUrl(ApiConfig.authVerifyLoginOtp)}');
    print('   Verify Signup OTP: ${ApiConfig.buildUrl(ApiConfig.authVerifySignupOtp)}');
    print('   Resend OTP: ${ApiConfig.buildUrl(ApiConfig.authResendOtp)}');
    
    print('');
    print('📚 Topics/Courses Endpoints:');
    print('   List Topics: ${ApiConfig.buildUrl(ApiConfig.topicsList)}');
    print('   List with User: ${ApiConfig.buildUrl(ApiConfig.topicsListWithUser(123))}');
    print('   Topic Detail: ${ApiConfig.buildUrl(ApiConfig.topicsDetailWithId(456))}');
    print('   Topic Detail with User: ${ApiConfig.buildUrl(ApiConfig.topicsDetailWithId(456, userId: 123))}');
    
    print('');
    print('📋 Enrollment Endpoints:');
    print('   Mobile Enroll: ${ApiConfig.buildUrl(ApiConfig.enrollmentsMobileEnroll)}');
    print('   Free Enroll: ${ApiConfig.buildUrl(ApiConfig.enrollmentsEnrollFree)}');
    print('   User Enrollments: ${ApiConfig.buildUrl(ApiConfig.enrollmentsUserEnrollmentsWithId(789))}');
    
    print('');
    print('💳 Payment Endpoints:');
    print('   Create Intent: ${ApiConfig.buildUrl(ApiConfig.paymentsCreateIntent)}');
    print('   Confirm Payment: ${ApiConfig.buildUrl(ApiConfig.paymentsConfirmPayment)}');
    
    print('🎯 ═══════════════════════════════════════════════════════════');
    print('');
  }
}

/// Extension to add name property to ApiEnvironment enum
extension ApiEnvironmentExtension on ApiEnvironment {
  String get name {
    switch (this) {
      case ApiEnvironment.development:
        return 'Development';
      case ApiEnvironment.staging:
        return 'Staging';
      case ApiEnvironment.production:
        return 'Production';
    }
  }
}