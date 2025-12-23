// test/api_config_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:thinkcyber/config/api_config.dart';

void main() {
  group('ApiConfig Tests', () {
    test('should have valid base URL for all environments', () {
      expect(ApiConfig.baseUrl, isNotEmpty);
      expect(ApiConfig.baseUrl, startsWith('http'));
    });

    test('should build correct endpoint URLs', () {
      final signupUrl = ApiConfig.buildUrl(ApiConfig.Auth.signup);
      expect(signupUrl, contains('/auth/signup'));
      expect(signupUrl, startsWith(ApiConfig.baseUrl));
    });

    test('should handle topic endpoints correctly', () {
      final topicsUrl = ApiConfig.Topics.listWithUser(123);
      expect(topicsUrl, equals('/topics?userId=123'));

      final topicDetailUrl = ApiConfig.Topics.detailWithId(5, userId: 123);
      expect(topicDetailUrl, equals('/topics/5?userId=123'));

      final topicDetailUrlNoUser = ApiConfig.Topics.detailWithId(5);
      expect(topicDetailUrlNoUser, equals('/topics/5'));
    });

    test('should have correct headers', () {
      final headers = ApiConfig.defaultHeaders;
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['Accept'], equals('application/json'));

      final authHeaders = ApiConfig.getAuthHeaders('test_token');
      expect(authHeaders['Authorization'], equals('Bearer test_token'));
    });

    test('should build Google Translate URL correctly', () {
      final url = ApiConfig.GoogleTranslate.buildUrl('hello', 'en', 'hi');
      expect(url, contains('translate.googleapis.com'));
      expect(url, contains('sl=en'));
      expect(url, contains('tl=hi'));
      expect(url, contains('hello'));
    });

    test('should have environment-specific configurations', () {
      expect(ApiConfig.environmentName, isNotEmpty);
      expect(ApiConfig.timeout, greaterThan(Duration.zero));
      
      // Logging should be disabled in production
      if (ApiConfig.isProduction) {
        expect(ApiConfig.isLoggingEnabled, isFalse);
      }
    });

    test('should build URLs with query parameters', () {
      final url = ApiConfig.buildUrlWithParams('/test', {'param1': 'value1', 'param2': 123});
      expect(url, contains('param1=value1'));
      expect(url, contains('param2=123'));
    });
  });
}