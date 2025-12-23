/// Razorpay Configuration
/// This file contains Razorpay API credentials and configuration
class RazorpayConfig {
  /// Your Razorpay Key ID
  /// Get this from your Razorpay dashboard: https://dashboard.razorpay.com/app/keys
  static const String keyId = 'rzp_test_RqI7nlhP3DcWxr';

  /// Your Razorpay Key Secret
  /// Keep this secure and never commit to version control
  /// Use environment variables or secure storage in production
  static const String keySecret = 'p4dZTD5gIGUcLvn7LFO0DVt7';

  /// Merchant name to display in payment dialog
  static const String merchantName = 'ThinkCyber LMS';

  /// Merchant description
  static const String merchantDescription = 'Cybersecurity Learning Platform';

  /// Supported payment methods
  static const List<String> supportedWallets = [
    'paytm',
    'googlepay',
    'phonepe',
  ];

  /// Razorpay API base URL
  static const String apiBaseUrl = 'https://api.razorpay.com/v1';

  /// Currency code
  static const String currency = 'INR';

  /// Validate configuration
  static bool isConfigured() {
    return keyId != 'YOUR_RAZORPAY_KEY_ID' &&
        keyId.isNotEmpty &&
        keySecret != 'YOUR_RAZORPAY_KEY_SECRET' &&
        keySecret.isNotEmpty;
  }
}
