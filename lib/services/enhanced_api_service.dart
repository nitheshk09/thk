// lib/services/enhanced_api_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Enhanced API service with comprehensive error handling, timeout management,
/// and centralized configuration support.
class EnhancedApiService {
  EnhancedApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _authToken;

  // ==================== AUTHENTICATION ====================

  /// Set authentication token for subsequent requests
  void setAuthToken(String? token) {
    _authToken = token;
    _log('Auth token ${token != null ? 'set' : 'cleared'}');
  }

  /// Get current authentication token
  String? get authToken => _authToken;

  /// Clear authentication token
  void clearAuthToken() {
    _authToken = null;
    _log('Auth token cleared');
  }

  // ==================== HTTP METHODS ====================

  /// Make a GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? customHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return _makeRequest<T>(
      method: 'GET',
      endpoint: endpoint,
      queryParams: queryParams,
      customHeaders: customHeaders,
      parser: parser,
    );
  }

  /// Make a POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? customHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return _makeRequest<T>(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      customHeaders: customHeaders,
      parser: parser,
    );
  }

  /// Make a PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? customHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return _makeRequest<T>(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      customHeaders: customHeaders,
      parser: parser,
    );
  }

  /// Make a DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? customHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    return _makeRequest<T>(
      method: 'DELETE',
      endpoint: endpoint,
      customHeaders: customHeaders,
      parser: parser,
    );
  }

  // ==================== CORE REQUEST METHOD ====================

  /// Core method for making HTTP requests with comprehensive error handling
  Future<ApiResponse<T>> _makeRequest<T>({
    required String method,
    required String endpoint,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? body,
    Map<String, String>? customHeaders,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    try {
      // Build URL with query parameters
      final uri = _buildUri(endpoint, queryParams);
      
      // Prepare headers
      final headers = _buildHeaders(customHeaders);
      
      // Log request
      _logRequest(method, endpoint, body, queryParams);

      // Make HTTP request with timeout
      final response = await _executeRequest(
        method: method,
        uri: uri,
        headers: headers,
        body: body,
      ).timeout(
        ApiConfig.timeout,
        onTimeout: () {
          throw ApiTimeoutException(
            message: 'Request timed out after ${ApiConfig.timeout.inSeconds} seconds',
            endpoint: endpoint,
          );
        },
      );

      // Log response
      _logResponse(response, endpoint);

      // Handle response
      return _handleResponse<T>(response, endpoint, parser);

    } on SocketException catch (e) {
      _logError('Network error for $endpoint: ${e.message}');
      return ApiResponse<T>.failure(
        ApiNetworkException(
          message: 'No internet connection. Please check your network.',
          endpoint: endpoint,
          originalException: e,
        ),
      );
    } on HttpException catch (e) {
      _logError('HTTP error for $endpoint: ${e.message}');
      return ApiResponse<T>.failure(
        ApiHttpException(
          message: e.message,
          endpoint: endpoint,
          originalException: e,
        ),
      );
    } on FormatException catch (e) {
      _logError('JSON parsing error for $endpoint: ${e.message}');
      return ApiResponse<T>.failure(
        ApiParsingException(
          message: 'Invalid response format from server.',
          endpoint: endpoint,
          originalException: e,
        ),
      );
    } on ApiTimeoutException catch (e) {
      _logError('Timeout error for $endpoint: ${e.message}');
      return ApiResponse<T>.failure(e);
    } catch (e) {
      _logError('Unexpected error for $endpoint: $e');
      return ApiResponse<T>.failure(
        ApiUnexpectedException(
          message: 'An unexpected error occurred. Please try again.',
          endpoint: endpoint,
          originalException: e,
        ),
      );
    }
  }

  // ==================== HELPER METHODS ====================

  /// Build URI with query parameters
  Uri _buildUri(String endpoint, Map<String, dynamic>? queryParams) {
    final baseUri = Uri.parse(ApiConfig.buildUrl(endpoint));
    
    if (queryParams == null || queryParams.isEmpty) {
      return baseUri;
    }

    return baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        ...queryParams.map((key, value) => MapEntry(key, value.toString())),
      },
    );
  }

  /// Build request headers
  Map<String, String> _buildHeaders(Map<String, String>? customHeaders) {
    final headers = <String, String>{
      ...ApiConfig.defaultHeaders,
      if (_authToken != null) ...ApiConfig.getAuthHeaders(_authToken!),
      if (customHeaders != null) ...customHeaders,
    };

    return headers;
  }

  /// Execute HTTP request based on method
  Future<http.Response> _executeRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
  }) {
    final encodedBody = body != null ? jsonEncode(body) : null;

    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        return _client.put(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return _client.delete(uri, headers: headers);
      default:
        throw UnsupportedError('HTTP method $method is not supported');
    }
  }

  /// Handle HTTP response and convert to ApiResponse
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    String endpoint,
    T Function(Map<String, dynamic>)? parser,
  ) {
    // Parse response body
    Map<String, dynamic> responseData;
    try {
      responseData = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return ApiResponse<T>.failure(
        ApiParsingException(
          message: 'Failed to parse server response.',
          endpoint: endpoint,
          statusCode: response.statusCode,
          originalException: e,
        ),
      );
    }

    // Check if request was successful
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        if (parser != null) {
          final data = parser(responseData);
          return ApiResponse<T>.success(data, response.statusCode);
        } else {
          return ApiResponse<T>.success(
            responseData as T,
            response.statusCode,
          );
        }
      } catch (e) {
        return ApiResponse<T>.failure(
          ApiParsingException(
            message: 'Failed to parse response data.',
            endpoint: endpoint,
            statusCode: response.statusCode,
            originalException: e,
          ),
        );
      }
    } else {
      // Handle error responses
      final errorMessage = _extractErrorMessage(responseData);
      return ApiResponse<T>.failure(
        ApiServerException(
          message: errorMessage,
          endpoint: endpoint,
          statusCode: response.statusCode,
          serverResponse: responseData,
        ),
      );
    }
  }

  /// Extract error message from server response
  String _extractErrorMessage(Map<String, dynamic> responseData) {
    // Try different possible error message fields
    final errorFields = ['error', 'message', 'detail', 'description'];
    
    for (final field in errorFields) {
      final value = responseData[field];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    return 'An error occurred while processing your request.';
  }

  // ==================== LOGGING ====================

  /// Log request details
  void _logRequest(
    String method,
    String endpoint,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  ) {
    if (!ApiConfig.isLoggingEnabled) return;

    final queryString = queryParams?.isNotEmpty == true
        ? '?${queryParams!.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';
    
    final bodyString = body != null ? ' ${jsonEncode(body)}' : '';
    
    _log('Request → $method $endpoint$queryString$bodyString');
  }

  /// Log response details
  void _logResponse(http.Response response, String endpoint) {
    if (!ApiConfig.isLoggingEnabled) return;

    final statusIcon = response.statusCode >= 200 && response.statusCode < 300 
        ? '✅' 
        : '❌';
    
    _log('Response $statusIcon ${response.statusCode} $endpoint ${_truncateBody(response.body)}');
  }

  /// Log error messages
  void _logError(String message) {
    if (!ApiConfig.isLoggingEnabled) return;
    _log(message, isError: true);
  }

  /// Core logging method
  void _log(String message, {bool isError = false}) {
    developer.log(
      message,
      name: 'EnhancedApiService[${ApiConfig.environmentName}]',
      level: isError ? 1000 : 0,
    );
    debugPrint('EnhancedApiService[${ApiConfig.environmentName}] | ${isError ? 'ERROR' : 'INFO'} | $message');
  }

  /// Truncate response body for logging
  String _truncateBody(String body, {int maxLength = 500}) {
    if (body.length <= maxLength) return body;
    return '${body.substring(0, maxLength)}... [truncated]';
  }

  // ==================== CLEANUP ====================

  /// Dispose resources
  void dispose() {
    _client.close();
    _log('API service disposed');
  }
}

// ==================== RESPONSE WRAPPER ====================

/// Generic API response wrapper
class ApiResponse<T> {
  const ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
    this.statusCode,
  });

  final bool isSuccess;
  final T? data;
  final ApiException? error;
  final int? statusCode;

  /// Create successful response
  factory ApiResponse.success(T data, int statusCode) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  /// Create failure response
  factory ApiResponse.failure(ApiException error) {
    return ApiResponse._(
      isSuccess: false,
      error: error,
      statusCode: error.statusCode,
    );
  }

  /// Check if response is successful
  bool get isFailure => !isSuccess;

  /// Get data or throw error if failed
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw error ?? ApiUnexpectedException(
      message: 'Unknown error occurred',
      endpoint: 'unknown',
    );
  }
}

// ==================== EXCEPTION CLASSES ====================

/// Base API exception class
abstract class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.endpoint,
    this.statusCode,
    this.originalException,
  });

  final String message;
  final String endpoint;
  final int? statusCode;
  final dynamic originalException;

  @override
  String toString() => '$runtimeType: $message (endpoint: $endpoint, status: $statusCode)';
}

/// Network connectivity exception
class ApiNetworkException extends ApiException {
  const ApiNetworkException({
    required super.message,
    required super.endpoint,
    super.originalException,
  }) : super(statusCode: null);
}

/// HTTP protocol exception
class ApiHttpException extends ApiException {
  const ApiHttpException({
    required super.message,
    required super.endpoint,
    super.statusCode,
    super.originalException,
  });
}

/// Server error response exception
class ApiServerException extends ApiException {
  const ApiServerException({
    required super.message,
    required super.endpoint,
    required super.statusCode,
    this.serverResponse,
    super.originalException,
  });

  final Map<String, dynamic>? serverResponse;
}

/// JSON parsing exception
class ApiParsingException extends ApiException {
  const ApiParsingException({
    required super.message,
    required super.endpoint,
    super.statusCode,
    super.originalException,
  });
}

/// Request timeout exception
class ApiTimeoutException extends ApiException {
  const ApiTimeoutException({
    required super.message,
    required super.endpoint,
    super.originalException,
  }) : super(statusCode: 408);
}

/// Unexpected/unknown exception
class ApiUnexpectedException extends ApiException {
  const ApiUnexpectedException({
    required super.message,
    required super.endpoint,
    super.statusCode,
    super.originalException,
  });
}

// ==================== USAGE EXAMPLES ====================

/// Example usage:
/// 
/// ```dart
/// final apiService = EnhancedApiService();
/// 
/// // Set authentication token
/// apiService.setAuthToken('your_jwt_token_here');
/// 
/// // Make a GET request
/// final response = await apiService.get<List<CourseTopic>>(
///   ApiConfig.Topics.list,
///   queryParams: {'userId': 123},
///   parser: (json) => (json['data'] as List)
///       .map((item) => CourseTopic.fromJson(item))
///       .toList(),
/// );
/// 
/// if (response.isSuccess) {
///   final topics = response.data!;
///   print('Loaded ${topics.length} topics');
/// } else {
///   print('Error: ${response.error!.message}');
///   // Handle specific error types
///   if (response.error is ApiNetworkException) {
///     // Show network error UI
///   } else if (response.error is ApiServerException) {
///     // Show server error UI
///   }
/// }
/// 
/// // Make a POST request
/// final postResponse = await apiService.post<GenericResponse>(
///   ApiConfig.Auth.login,
///   body: {'email': 'user@example.com', 'password': 'password'},
///   parser: (json) => GenericResponse.fromJson(json),
/// );
/// ```