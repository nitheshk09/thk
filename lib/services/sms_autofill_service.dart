// lib/services/email_otp_service.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to handle Email OTP functionality and clipboard monitoring
class EmailOtpService {
  static final EmailOtpService _instance = EmailOtpService._internal();
  factory EmailOtpService() => _instance;
  EmailOtpService._internal();

  Timer? _clipboardTimer;
  String? _lastClipboardContent;
  
  /// Initialize email OTP service
  Future<void> initialize() async {
    try {
      print('📧 Email OTP service initialized');
    } catch (e) {
      print('❌ Failed to initialize Email OTP service: $e');
    }
  }

  /// Start monitoring clipboard for OTP codes
  Future<void> startClipboardMonitoring({
    required Function(String) onOtpReceived,
    Function(String)? onError,
  }) async {
    try {
      // Stop any existing monitoring
      await stopClipboardMonitoring();
      
      // Start clipboard monitoring
      _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        try {
          final clipboardData = await Clipboard.getData('text/plain');
          final clipboardText = clipboardData?.text?.trim() ?? '';
          
          if (clipboardText.isNotEmpty && clipboardText != _lastClipboardContent) {
            _lastClipboardContent = clipboardText;
            
            final otp = extractOtpFromText(clipboardText);
            if (otp != null) {
              print('✅ OTP detected in clipboard: $otp');
              onOtpReceived(otp);
              // Stop monitoring after successful detection
              await stopClipboardMonitoring();
            }
          }
        } catch (e) {
          print('⚠️ Clipboard monitoring error: $e');
        }
      });
      
      print('📋 Started monitoring clipboard for OTP...');
    } catch (e) {
      print('❌ Failed to start clipboard monitoring: $e');
      onError?.call(e.toString());
    }
  }

  /// Stop clipboard monitoring
  Future<void> stopClipboardMonitoring() async {
    try {
      _clipboardTimer?.cancel();
      _clipboardTimer = null;
      print('🛑 Stopped clipboard monitoring');
    } catch (e) {
      print('⚠️ Error stopping clipboard monitoring: $e');
    }
  }

  /// Open email app for user to check OTP
  Future<bool> openEmailApp({String? email}) async {
    try {
      Uri emailUri;
      
      if (email != null && email.isNotEmpty) {
        // Try to open Gmail app with specific email
        if (email.toLowerCase().contains('gmail.com')) {
          emailUri = Uri.parse('googlegmail://');
        } else {
          // Generic email app
          emailUri = Uri.parse('mailto:');
        }
      } else {
        // Open default email app
        emailUri = Uri.parse('mailto:');
      }
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        print('📧 Opened email app');
        return true;
      } else {
        // Fallback - try to open Gmail web
        final webUri = Uri.parse('https://mail.google.com');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          print('📧 Opened email in browser');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error opening email app: $e');
      return false;
    }
  }

  /// Extract OTP from text content (email or clipboard)
  String? extractOtpFromText(String textContent) {
    try {
      // Common OTP patterns
      final patterns = [
        RegExp(r'\b(\d{6})\b'),           // 6 digit numbers
        RegExp(r'\b(\d{4})\b'),           // 4 digit numbers  
        RegExp(r'OTP[:\s]*(\d+)', caseSensitive: false),        // "OTP: 123456"
        RegExp(r'code[:\s]*(\d+)', caseSensitive: false), // "code: 123456"
        RegExp(r'verification[:\s]*(\d+)', caseSensitive: false), // "verification: 123456"
        RegExp(r'pin[:\s]*(\d+)', caseSensitive: false), // "PIN: 123456"
        RegExp(r'token[:\s]*(\d+)', caseSensitive: false), // "token: 123456"
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(textContent);
        if (match != null) {
          final otp = match.group(1);
          if (otp != null && (otp.length == 4 || otp.length == 6)) {
            print('� Extracted OTP from text: $otp');
            return otp;
          }
        }
      }
      
      print('⚠️ No OTP pattern found in text: ${textContent.length > 50 ? textContent.substring(0, 50) + '...' : textContent}');
      return null;
    } catch (e) {
      print('❌ Error extracting OTP from text: $e');
      return null;
    }
  }

  /// Copy text to clipboard
  Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      print('📋 Copied to clipboard: $text');
    } catch (e) {
      print('❌ Error copying to clipboard: $e');
    }
  }

  /// Get current clipboard content
  Future<String?> getClipboardContent() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      return clipboardData?.text?.trim();
    } catch (e) {
      print('❌ Error getting clipboard content: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    stopClipboardMonitoring();
  }
}

/// Mixin to easily add email OTP functionality to any widget
mixin EmailOtpMixin {
  final EmailOtpService _emailOtpService = EmailOtpService();
  
  /// Start clipboard monitoring for OTP
  Future<void> startOtpClipboardMonitoring({
    required Function(String) onOtpReceived,
    Function(String)? onError,
  }) async {
    await _emailOtpService.startClipboardMonitoring(
      onOtpReceived: onOtpReceived,
      onError: onError,
    );
  }
  
  /// Stop clipboard monitoring
  Future<void> stopOtpClipboardMonitoring() async {
    await _emailOtpService.stopClipboardMonitoring();
  }
  
  /// Open email app for user to check OTP
  Future<bool> openEmailApp({String? email}) async {
    return await _emailOtpService.openEmailApp(email: email);
  }
  
  /// Extract OTP from text
  String? extractOtp(String text) {
    return _emailOtpService.extractOtpFromText(text);
  }
}

/// Extension methods for easier OTP extraction
extension EmailOtpExtension on String {
  /// Extract OTP from this string
  String? extractOtp() {
    return EmailOtpService().extractOtpFromText(this);
  }
  
  /// Check if string contains OTP pattern
  bool containsOtp() {
    return extractOtp() != null;
  }
}
