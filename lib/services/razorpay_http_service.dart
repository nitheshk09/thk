import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/razorpay_config.dart';

class RazorpayHttpService {
  static final _basicAuth = 'Basic ' +
      base64Encode(utf8.encode('${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}'));

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': _basicAuth,
  };

  /// 1. Create an Order
  static Future<Map<String, dynamic>> createOrder({
    required int amount,
    required String currency,
    String? receipt,
    bool paymentCapture = true,
    Map<String, dynamic>? notes,
  }) async {
    final url = Uri.parse('${RazorpayConfig.apiBaseUrl}/orders');
    final body = jsonEncode({
      'amount': amount, // in paise
      'currency': currency,
      'receipt': receipt,
      'payment_capture': paymentCapture ? 1 : 0,
      if (notes != null) 'notes': notes,
    });
    final response = await http.post(url, headers: _headers, body: body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create order: ${response.body}');
    }
  }

  /// 2. Capture a Payment
  static Future<Map<String, dynamic>> capturePayment({
    required String paymentId,
    required int amount,
    required String currency,
  }) async {
    final url = Uri.parse('${RazorpayConfig.apiBaseUrl}/payments/$paymentId/capture');
    final body = jsonEncode({
      'amount': amount, // in paise
      'currency': currency,
    });
    final response = await http.post(url, headers: _headers, body: body);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to capture payment: ${response.body}');
    }
  }

  /// 3. Refund a Payment
  static Future<Map<String, dynamic>> refundPayment({
    required String paymentId,
    int? amount, // in paise (optional, full refund if not provided)
    Map<String, dynamic>? notes,
  }) async {
    final url = Uri.parse('${RazorpayConfig.apiBaseUrl}/payments/$paymentId/refund');
    final body = jsonEncode({
      if (amount != null) 'amount': amount,
      if (notes != null) 'notes': notes,
    });
    final response = await http.post(url, headers: _headers, body: body);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to refund payment: ${response.body}');
    }
  }

  /// 4. Fetch Payment Details
  static Future<Map<String, dynamic>> fetchPaymentDetails(String paymentId) async {
    final url = Uri.parse('${RazorpayConfig.apiBaseUrl}/payments/$paymentId');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch payment details: ${response.body}');
    }
  }
}
