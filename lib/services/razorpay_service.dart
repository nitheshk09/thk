import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  static final RazorpayService _instance = RazorpayService._internal();
  late Razorpay _razorpay;

  // Callbacks
  Function(PaymentSuccessResponse)? onSuccess;
  Function(PaymentFailureResponse)? onFailure;
  Function(ExternalWalletResponse)? onExternalWallet;

  factory RazorpayService() {
    return _instance;
  }

  RazorpayService._internal() {
    _razorpay = Razorpay();
    _setupListeners();
  }

  void _setupListeners() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    onExternalWallet?.call(response);
  }

  /// Open Razorpay payment dialog with the given options
  void openPayment({
    required String keyId,
    required double amount,
    required String orderId,
    required String name,
    required String description,
    required String email,
    String? phone,
    Map<String, String>? metadata,
  }) {
    final options = {
      'key': keyId,
      'amount': (amount * 100).toInt(), // Convert to paise
      'name': name,
      'description': description,
      'order_id': orderId,
      'prefill': {
        'contact': phone ?? '',
        'email': email,
      },
      'external': {
        'wallets': ['paytm', 'googlepay', 'phonepe'],
      },
      if (metadata != null) 'notes': metadata,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      throw Exception('Failed to open Razorpay: $e');
    }
  }

  /// Clear Razorpay resources
  void clear() {
    _razorpay.clear();
  }

  /// Get Razorpay instance
  Razorpay get instance => _razorpay;
}
