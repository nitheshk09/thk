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
  final Set<String> _processedOtps = <String>{};
  DateTime? _lastOtpRequestTime;
  
  /// Initialize email OTP service
  Future<void> initialize() async {
    try {
      print('📧 Email OTP service initialized');
    } catch (e) {
      print('❌ Failed to initialize Email OTP service: $e');
    }
  }

  /// Mark the time when OTP was requested (to filter old OTPs)
  void markOtpRequested() {
    _lastOtpRequestTime = DateTime.now();
    _processedOtps.clear(); // Clear old processed OTPs
    
    // Convert to IST for display
    final istTime = _lastOtpRequestTime!.add(const Duration(hours: 5, minutes: 30));
    print('🕒 OTP request marked at ${_lastOtpRequestTime!.toIso8601String()} UTC');
    print('🇮🇳 IST Time: ${istTime.toString().substring(0, 19)} IST');
    print('📅 Local Time: ${_lastOtpRequestTime!.toString().substring(0, 19)}');
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
            
            print('📋 New clipboard content detected (${clipboardText.length} chars)');
            
            // If it's a long text (likely email content), use advanced extraction
            if (clipboardText.length > 100) {
              print('📧 Detected long text, using email structure analysis...');
            }
            
            final otp = extractLatestOtpFromText(clipboardText);
            if (otp != null && !_processedOtps.contains(otp)) {
              _processedOtps.add(otp); // Mark as processed
              print('✅ Latest OTP detected in clipboard: $otp');
              onOtpReceived(otp);
              // Stop monitoring after successful detection
              await stopClipboardMonitoring();
            } else if (otp != null) {
              print('⚠️ OTP "$otp" already processed, ignoring...');
            } else {
              print('❌ No valid OTP found in clipboard content');
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
      bool isGmail = email != null && email.toLowerCase().contains('contact.thinkcyber@gmail.com');
      
      // Strategy 1: Try Gmail app directly for Gmail accounts
      if (isGmail) {
        try {
          // Try Gmail app with specific URI schemes
          final gmailAppUris = [
            'googlegmail://',
            'gmail://',
          ];
          
          for (final uriString in gmailAppUris) {
            final uri = Uri.parse(uriString);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              print('📱 Opened Gmail app');
              return true;
            }
          }
        } catch (e) {
          print('⚠️ Gmail app not available: $e');
        }
      }
      
      // Strategy 2: Try generic email app
      try {
        final mailtoUri = Uri.parse('mailto:');
        if (await canLaunchUrl(mailtoUri)) {
          await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
          print('📧 Opened default email app');
          return true;
        }
      } catch (e) {
        print('⚠️ Default email app not available: $e');
      }
      
      // Strategy 3: Fallback to Chrome/Browser with Gmail
      try {
        final webUri = isGmail 
            ? Uri.parse('https://mail.google.com/mail/u/0/#inbox')
            : Uri.parse('https://mail.google.com');
            
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          print('🌐 Opened email in Chrome/Browser');
          return true;
        }
      } catch (e) {
        print('⚠️ Browser not available: $e');
      }
      
      return false;
    } catch (e) {
      print('❌ Error opening email app: $e');
      return false;
    }
  }

  /// Open Gmail app specifically
  Future<bool> openGmailApp() async {
    try {
      // Try multiple Gmail app URI schemes
      final gmailUris = [
        'googlegmail://',
        'gmail://',
        'com.google.android.gm://',
      ];
      
      for (final uriString in gmailUris) {
        try {
          final uri = Uri.parse(uriString);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            print('📱 Successfully opened Gmail app via $uriString');
            return true;
          }
        } catch (e) {
          print('⚠️ Failed to open Gmail with $uriString: $e');
        }
      }
      
      print('📱 Gmail app not found on device');
      return false;
    } catch (e) {
      print('❌ Error trying to open Gmail app: $e');
      return false;
    }
  }

  /// Open Chrome browser with Gmail
  Future<bool> openGmailInChrome() async {
    try {
      // Try Chrome-specific intent first (Android)
      try {
        final chromeUri = Uri.parse('googlechrome://mail.google.com/mail/u/0/#inbox');
        if (await canLaunchUrl(chromeUri)) {
          await launchUrl(chromeUri, mode: LaunchMode.externalApplication);
          print('🌐 Opened Gmail in Chrome app');
          return true;
        }
      } catch (e) {
        print('⚠️ Chrome app not available: $e');
      }
      
      // Fallback to default browser
      final webUri = Uri.parse('https://mail.google.com/mail/u/0/#inbox');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        print('🌐 Opened Gmail in default browser');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error opening Gmail in Chrome: $e');
      return false;
    }
  }

  /// Extract latest OTP from text content with enhanced context awareness
  String? extractLatestOtpFromText(String textContent) {
    try {
      print('🔍 Analyzing text for latest OTP...');
      print('📄 Text length: ${textContent.length} characters');
      
      // Strategy 1: Check if this is specifically from contact.thinkcyber@gmail.com
      if (textContent.toLowerCase().contains('contact.thinkcyber@gmail.com')) {
        print('🎯 Detected email from target sender - applying priority extraction');
        final priorityOtp = _extractOtpFromTargetSender(textContent);
        if (priorityOtp != null) {
          return priorityOtp;
        }
      }
      
      // Strategy 2: Try email structure analysis
      final emailStructureOtp = _extractOtpFromEmailStructure(textContent);
      if (emailStructureOtp != null) {
        return emailStructureOtp;
      }
      
      // Strategy 3: Try timestamp-based extraction
      final timestampOtp = _extractOtpWithTimeContext(textContent);
      if (timestampOtp != null) {
        return timestampOtp;
      }
      
      // Strategy 4: Try position-based extraction (first occurrence is usually latest)
      final positionBasedOtp = _extractFirstOtpByPosition(textContent);
      if (positionBasedOtp != null) {
        return positionBasedOtp;
      }
      
      // Strategy 5: Fallback to regular extraction
      print('🔄 Falling back to basic OTP extraction');
      return extractOtpFromText(textContent);
    } catch (e) {
      print('❌ Error extracting latest OTP: $e');
      return extractOtpFromText(textContent);
    }
  }

  /// Extract OTP specifically from contact.thinkcyber@gmail.com emails with highest priority
  String? _extractOtpFromTargetSender(String textContent) {
    try {
      print('🎯 Extracting OTP from target sender email');
      
      // Split the text by the sender email to isolate their specific content
      final senderPattern = RegExp(r'(from[:\s]+)?contact\.thinkcyber@gmail\.com', caseSensitive: false);
      final parts = textContent.split(senderPattern);
      
      if (parts.length > 1) {
        // The content after the sender is likely the email body
        for (int i = 1; i < parts.length; i++) {
          final emailContent = parts[i].trim();
          
          // Look for OTP in the first 500 characters (usually at the top)
          final topContent = emailContent.length > 500 
              ? emailContent.substring(0, 500) 
              : emailContent;
          
          final otp = extractOtpFromText(topContent);
          if (otp != null) {
            print('✅ Found OTP from target sender: $otp');
            
            // Double check it's a valid OTP format
            if (RegExp(r'^\d{4,8}$').hasMatch(otp)) {
              return otp;
            }
          }
        }
      }
      
      // Alternative approach: look for the most recent OTP near the sender mention
      final lines = textContent.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].toLowerCase();
        
        if (line.contains('contact.thinkcyber@gmail.com')) {
          // Check the next 10 lines for OTP
          final endIndex = (i + 10).clamp(0, lines.length);
          final nearbyContent = lines.sublist(i, endIndex).join('\n');
          
          final otp = extractOtpFromText(nearbyContent);
          if (otp != null) {
            print('✅ Found OTP near target sender mention: $otp');
            return otp;
          }
        }
      }
      
      print('⚠️ No OTP found specifically from target sender');
      return null;
    } catch (e) {
      print('❌ Error extracting OTP from target sender: $e');
      return null;
    }
  }

  /// Extract OTP from email structure (looking for email boundaries and timestamps)
  String? _extractOtpFromEmailStructure(String textContent) {
    try {
      print('🔍 Starting email structure analysis...');
      print('📄 Full text length: ${textContent.length}');
      
      // Enhanced email boundary detection for Gmail/Outlook
      final emailSeparators = [
        'contact.thinkcyber@gmail.com',  // Look specifically for this sender
        'From: contact.thinkcyber@gmail.com',
        'from contact.thinkcyber@gmail.com',
        RegExp(r'On\s+\w+,\s+\w+\s+\d+,\s+\d+\s+at\s+\d+:\d+\s+[AP]M'), // Gmail timestamp pattern
        '-----Original Message-----',
        '--- Original Message ---',
        'From:',
        'Date:',
        'Subject:',
        '>',  // Email reply markers
        '|',  // Some email clients use this
      ];
      
      final emailSections = <Map<String, dynamic>>[];
      
      // Try to split by contact.thinkcyber@gmail.com specifically first
      if (textContent.toLowerCase().contains('contact.thinkcyber@gmail.com')) {
        final parts = textContent.split(RegExp(r'(from[:\s]+contact\.thinkcyber@gmail\.com|contact\.thinkcyber@gmail\.com)', caseSensitive: false));
        print('🎯 Found ${parts.length} parts split by contact.thinkcyber@gmail.com');
        
        for (int i = 0; i < parts.length; i++) {
          final part = parts[i].trim();
          if (part.isNotEmpty) {
            emailSections.add({
              'content': part,
              'index': i,
              'isFromTargetSender': i > 0,  // First part is before the sender match
            });
          }
        }
      }
      
      // If we didn't get good splits, try other separators
      if (emailSections.length <= 1) {
        final lines = textContent.split('\n');
        String currentSection = '';
        int sectionIndex = 0;
        
        for (final line in lines) {
          // Check if this line starts a new email
          bool isNewEmail = false;
          for (final separator in emailSeparators) {
            if (separator is RegExp) {
              if (separator.hasMatch(line)) {
                isNewEmail = true;
                break;
              }
            } else if (line.toLowerCase().contains(separator.toString().toLowerCase())) {
              isNewEmail = true;
              break;
            }
          }
          
          if (isNewEmail && currentSection.isNotEmpty) {
            emailSections.add({
              'content': currentSection.trim(),
              'index': sectionIndex++,
              'isFromTargetSender': currentSection.toLowerCase().contains('contact.thinkcyber@gmail.com'),
            });
            currentSection = line;
          } else {
            currentSection += '\n$line';
          }
        }
        
        // Add the last section
        if (currentSection.isNotEmpty) {
          emailSections.add({
            'content': currentSection.trim(),
            'index': sectionIndex,
            'isFromTargetSender': currentSection.toLowerCase().contains('contact.thinkcyber@gmail.com'),
          });
        }
      }
      
      print('📧 Found ${emailSections.length} email sections');
      
      // Analyze each email section for OTPs with enhanced priority
      String? bestOtp;
      DateTime? bestTime;
      int bestScore = 0;
      
      for (int i = 0; i < emailSections.length; i++) {
        final section = emailSections[i];
        final content = section['content'] as String;
        final isFromTarget = section['isFromTargetSender'] as bool;
        
        final otp = extractOtpFromText(content);
        if (otp != null) {
          int score = 0;
          final timestamp = _extractTimestamp(content);
          
          // Higher score for emails from target sender
          if (isFromTarget) {
            score += 100;
            print('🎯 OTP from target sender: $otp (score +100)');
          }
          
          // Higher score for more recent timestamps
          if (timestamp != null) {
            final now = DateTime.now();
            final ageInMinutes = now.difference(timestamp).inMinutes;
            
            if (ageInMinutes < 5) {
              score += 50;
            } else if (ageInMinutes < 15) {
              score += 30;
            } else if (ageInMinutes < 60) {
              score += 10;
            }
            
              print('📅 Section $i: OTP=$otp, Time=${timestamp != null ? _formatTimestamp(timestamp) : 'null'}, Age=${ageInMinutes}min, Score=$score');            // If this timestamp is newer, it gets preference
            if (bestTime == null || timestamp.isAfter(bestTime)) {
              score += 25;
            }
          } else {
            print('📅 Section $i: OTP=$otp, No timestamp, Score=$score');
          }
          
          // Position-based scoring (earlier sections are often newer)
          if (i == 0) score += 20;
          else if (i == 1) score += 10;
          
          // Content-based scoring
          final contentLower = content.toLowerCase();
          if (contentLower.contains('verification code') || contentLower.contains('otp')) {
            score += 15;
          }
          
          if (score > bestScore) {
            bestScore = score;
            bestOtp = otp;
            bestTime = timestamp;
            print('🏆 New best OTP: $otp (score: $score)');
          }
        }
      }
      
      if (bestOtp != null) {
        print('✅ Selected best OTP from email structure: $bestOtp (score: $bestScore)');
      }
      
      return bestOtp;
    } catch (e) {
      print('❌ Error in email structure analysis: $e');
      return null;
    }
  }

  /// Extract timestamp from email text with enhanced Gmail format support
  DateTime? _extractTimestamp(String text) {
    try {
      final timestampPatterns = [
        // Gmail format: "On Thu, Nov 7, 2025 at 3:45 PM"
        RegExp(r'On\s+\w+,\s+(\w{3})\s+(\d{1,2}),\s+(\d{4})\s+at\s+(\d{1,2}):(\d{2})\s+(AM|PM)', caseSensitive: false),
        // "Nov 7, 2025 at 3:45 PM"
        RegExp(r'(\w{3})\s+(\d{1,2}),\s+(\d{4})\s+at\s+(\d{1,2}):(\d{2})\s+(AM|PM)', caseSensitive: false),
        // "Thursday, November 7, 2025 at 3:45 PM"
        RegExp(r'\w+,\s+(\w+)\s+(\d{1,2}),\s+(\d{4})\s+at\s+(\d{1,2}):(\d{2})\s+(AM|PM)', caseSensitive: false),
        // ISO format: "2025-11-07T15:45:30"
        RegExp(r'(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'),
        // "2025-11-07 15:45:30"
        RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})'),
        // "Today at 3:45 PM"
        RegExp(r'today\s+at\s+(\d{1,2}):(\d{2})\s+(AM|PM)', caseSensitive: false),
        // "Yesterday at 3:45 PM"
        RegExp(r'yesterday\s+at\s+(\d{1,2}):(\d{2})\s+(AM|PM)', caseSensitive: false),
        // "3:45 PM" (today assumed)
        RegExp(r'(?:^|\s)(\d{1,2}):(\d{2})\s+(AM|PM)(?:\s|$)', caseSensitive: false),
        // "15:45" (24-hour format)
        RegExp(r'(?:^|\s)(\d{2}):(\d{2})(?:\s|$)'),
      ];
      
      for (int i = 0; i < timestampPatterns.length; i++) {
        final pattern = timestampPatterns[i];
        final match = pattern.firstMatch(text);
        
        if (match != null) {
          try {
            final now = DateTime.now();
            
            if (i == 0) {
              // Gmail format: "On Thu, Nov 7, 2025 at 3:45 PM"
              final monthName = match.group(1)!;
              final day = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);
              final hour = int.parse(match.group(4)!);
              final minute = int.parse(match.group(5)!);
              final ampm = match.group(6)!.toUpperCase();
              
              final month = _monthNameToNumber(monthName);
              if (month != null) {
                var finalHour = hour;
                if (ampm == 'PM' && hour != 12) finalHour += 12;
                if (ampm == 'AM' && hour == 12) finalHour = 0;
                
                final timestamp = DateTime(year, month, day, finalHour, minute);
                print('📅 Parsed Gmail timestamp: ${_formatTimestamp(timestamp)} from "${match.group(0)}"');
                return timestamp;
              }
            } else if (i == 1) {
              // "Nov 7, 2025 at 3:45 PM"
              final monthName = match.group(1)!;
              final day = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);
              final hour = int.parse(match.group(4)!);
              final minute = int.parse(match.group(5)!);
              final ampm = match.group(6)!.toUpperCase();
              
              final month = _monthNameToNumber(monthName);
              if (month != null) {
                var finalHour = hour;
                if (ampm == 'PM' && hour != 12) finalHour += 12;
                if (ampm == 'AM' && hour == 12) finalHour = 0;
                
                final timestamp = DateTime(year, month, day, finalHour, minute);
                print('📅 Parsed date timestamp: $timestamp from "${match.group(0)}"');
                return timestamp;
              }
            } else if (i == 2) {
              // "Thursday, November 7, 2025 at 3:45 PM"
              final monthName = match.group(1)!;
              final day = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);
              final hour = int.parse(match.group(4)!);
              final minute = int.parse(match.group(5)!);
              final ampm = match.group(6)!.toUpperCase();
              
              final month = _monthNameToNumber(monthName);
              if (month != null) {
                var finalHour = hour;
                if (ampm == 'PM' && hour != 12) finalHour += 12;
                if (ampm == 'AM' && hour == 12) finalHour = 0;
                
                final timestamp = DateTime(year, month, day, finalHour, minute);
                print('📅 Parsed full date timestamp: $timestamp from "${match.group(0)}"');
                return timestamp;
              }
            } else if (i == 3 || i == 4) {
              // ISO or standard date formats
              final year = int.parse(match.group(1)!);
              final month = int.parse(match.group(2)!);
              final day = int.parse(match.group(3)!);
              final hour = int.parse(match.group(4)!);
              final minute = int.parse(match.group(5)!);
              final second = match.groupCount >= 6 ? int.parse(match.group(6)!) : 0;
              
              final timestamp = DateTime(year, month, day, hour, minute, second);
              print('📅 Parsed ISO timestamp: $timestamp from "${match.group(0)}"');
              return timestamp;
            } else if (i == 5) {
              // "Today at 3:45 PM"
              final hour = int.parse(match.group(1)!);
              final minute = int.parse(match.group(2)!);
              final ampm = match.group(3)!.toUpperCase();
              
              var finalHour = hour;
              if (ampm == 'PM' && hour != 12) finalHour += 12;
              if (ampm == 'AM' && hour == 12) finalHour = 0;
              
              final timestamp = DateTime(now.year, now.month, now.day, finalHour, minute);
              print('📅 Parsed "today" timestamp: $timestamp from "${match.group(0)}"');
              return timestamp;
            } else if (i == 6) {
              // "Yesterday at 3:45 PM"
              final hour = int.parse(match.group(1)!);
              final minute = int.parse(match.group(2)!);
              final ampm = match.group(3)!.toUpperCase();
              
              var finalHour = hour;
              if (ampm == 'PM' && hour != 12) finalHour += 12;
              if (ampm == 'AM' && hour == 12) finalHour = 0;
              
              final yesterday = now.subtract(const Duration(days: 1));
              final timestamp = DateTime(yesterday.year, yesterday.month, yesterday.day, finalHour, minute);
              print('📅 Parsed "yesterday" timestamp: $timestamp from "${match.group(0)}"');
              return timestamp;
            } else if (i == 7) {
              // "3:45 PM" (today assumed)
              final hour = int.parse(match.group(1)!);
              final minute = int.parse(match.group(2)!);
              final ampm = match.group(3)!.toUpperCase();
              
              var finalHour = hour;
              if (ampm == 'PM' && hour != 12) finalHour += 12;
              if (ampm == 'AM' && hour == 12) finalHour = 0;
              
              final timestamp = DateTime(now.year, now.month, now.day, finalHour, minute);
              print('📅 Parsed time-only timestamp: $timestamp from "${match.group(0)}"');
              return timestamp;
            }
          } catch (e) {
            print('⚠️ Error parsing timestamp with pattern $i: $e');
          }
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error extracting timestamp: $e');
      return null;
    }
  }

  /// Convert month name to number
  int? _monthNameToNumber(String monthName) {
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
      'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
      'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    return months[monthName.toLowerCase().substring(0, 3)];
  }

  /// Convert UTC DateTime to IST (UTC+5:30)
  DateTime _toIST(DateTime utcTime) {
    return utcTime.add(const Duration(hours: 5, minutes: 30));
  }

  /// Convert IST DateTime to UTC 
  DateTime _toUTC(DateTime istTime) {
    return istTime.subtract(const Duration(hours: 5, minutes: 30));
  }

  /// Format timestamp for display with timezone info
  String _formatTimestamp(DateTime timestamp) {
    final ist = _toIST(timestamp);
    return '${timestamp.toString().substring(0, 19)} UTC / ${ist.toString().substring(0, 19)} IST';
  }

  /// Check if OTP timestamp is recent (within last 15 minutes)
  bool _isRecentOtp(DateTime? otpTimestamp) {
    if (otpTimestamp == null || _lastOtpRequestTime == null) return false;
    
    final timeDiff = _lastOtpRequestTime!.difference(otpTimestamp).inMinutes.abs();
    final isRecent = timeDiff <= 15; // Within 15 minutes is considered recent
    
    print('⏰ OTP age check: ${_formatTimestamp(otpTimestamp)} vs Request: ${_formatTimestamp(_lastOtpRequestTime!)}');
    print('🕓 Age: ${timeDiff}min, Recent: $isRecent');
    
    return isRecent;
  }

  /// Extract first OTP by position (assuming first = latest)
  String? _extractFirstOtpByPosition(String textContent) {
    try {
      final lines = textContent.split('\n');
      
      // Look for OTP in first 30% of the text (usually latest emails appear first)
      final topLines = lines.take((lines.length * 0.3).ceil()).toList();
      
      for (final line in topLines) {
        final otp = extractOtpFromText(line);
        if (otp != null) {
          print('🔝 Found OTP in top section: $otp');
          return otp;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error in position-based extraction: $e');
      return null;
    }
  }

  /// Extract OTP with time context awareness and sender priority
  String? _extractOtpWithTimeContext(String textContent) {
    try {
      final lines = textContent.split('\n');
      String? bestOtp;
      int bestScore = 0;
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        final otp = extractOtpFromText(line);
        
        if (otp != null) {
          int score = 0;
          
          // Get broader context (up to 5 lines before and after)
          final contextStart = (i - 5).clamp(0, lines.length - 1);
          final contextEnd = (i + 5).clamp(0, lines.length - 1);
          final contextLines = lines
              .sublist(contextStart, contextEnd + 1)
              .join(' ')
              .toLowerCase();
          
          // HIGHEST PRIORITY: OTP from contact.thinkcyber@gmail.com
          if (contextLines.contains('contact.thinkcyber@gmail.com')) {
            score += 200;
            print('🎯 PRIORITY: OTP from target sender: $otp (+200 points)');
          }
          
          // Check for Gmail-specific indicators
          if (contextLines.contains('gmail.com') || contextLines.contains('google')) {
            score += 50;
          }
          
          // Higher score for fresh/recent indicators
          if (contextLines.contains(RegExp(r'just\s+now|moments?\s+ago|recently|new|fresh|latest'))) {
            score += 60;
          }
          
          // Check for specific time indicators (prefer very recent times)
          if (contextLines.contains(RegExp(r'(\d+)\s*min'))) {
            final minutes = RegExp(r'(\d+)\s*min').firstMatch(contextLines)?.group(1);
            if (minutes != null) {
              final mins = int.tryParse(minutes) ?? 0;
              if (mins < 2) {
                score += 50; // Very fresh
              } else if (mins < 5) {
                score += 40; // Fresh
              } else if (mins < 15) {
                score += 20; // Somewhat recent
              } else {
                score += 5;  // Old but still relevant
              }
            }
          }
          
          // Look for "today" or current date references
          if (contextLines.contains(RegExp(r'today|nov\s*7|november\s*7'))) {
            score += 35;
          }
          
          // Higher score for verification/security context
          if (contextLines.contains(RegExp(r'verification|security|login|sign\s*in|authenticate|access'))) {
            score += 40;
          }
          
          // Higher score for OTP-specific keywords nearby
          if (contextLines.contains(RegExp(r'otp|one.?time|password|code|pin|token|verification\s+code'))) {
            score += 30;
          }
          
          // Look for urgency indicators
          if (contextLines.contains(RegExp(r'expires?|expir|urgent|immediate'))) {
            score += 25;
          }
          
          // Prefer 6-digit codes over 4-digit (standard OTP length)
          if (otp.length == 6) {
            score += 20;
          } else if (otp.length == 4) {
            score += 10;
          } else {
            score -= 5; // Penalize unusual lengths
          }
          
          // Position-based scoring (earlier in clipboard = more recent)
          final positionRatio = i / lines.length;
          if (positionRatio < 0.2) {
            score += 30; // Very early in text
          } else if (positionRatio < 0.4) {
            score += 15; // Early in text
          } else if (positionRatio > 0.8) {
            score -= 10; // Very late in text (likely old)
          }
          
          // Check if OTP appears in a dedicated line (cleaner extraction)
          if (line.length < 20 && line.contains(otp)) {
            score += 15;
          }
          
          // Look for timestamp context within 3 lines
          final nearbyContext = lines
              .sublist((i - 3).clamp(0, lines.length), (i + 3).clamp(0, lines.length))
              .join(' ');
          
          if (_extractTimestamp(nearbyContext) != null) {
            score += 25;
            print('📅 Found timestamp context for OTP: $otp');
          }
          
          print('🔍 Found OTP "$otp" at line $i with total score: $score');
          
          if (score > bestScore) {
            bestScore = score;
            bestOtp = otp;
            print('🏆 New best OTP candidate: "$otp" (score: $score)');
          }
        }
      }
      
      if (bestOtp != null && bestScore > 20) {
        print('✅ Selected best context-aware OTP: "$bestOtp" (final score: $bestScore)');
        return bestOtp;
      } else if (bestOtp != null) {
        print('⚠️ Found OTP but score too low: "$bestOtp" (score: $bestScore)');
      }
      
      return null;
    } catch (e) {
      print('❌ Error in context-aware OTP extraction: $e');
      return null;
    }
  }

  /// Extract OTP from text content (email or clipboard) - enhanced basic method
  String? extractOtpFromText(String textContent) {
    try {
      // Enhanced OTP patterns with better ordering (most specific first)
      final patterns = [
        // Explicit OTP/code patterns (highest priority)
        RegExp(r'(?:OTP|code|verification\s+code)[:\s]*(\d{4,8})', caseSensitive: false),
        RegExp(r'(?:PIN|token)[:\s]*(\d{4,8})', caseSensitive: false),
        RegExp(r'(?:access\s+code|security\s+code)[:\s]*(\d{4,8})', caseSensitive: false),
        
        // Number patterns with context
        RegExp(r'(?:is|code:|otp:)\s*(\d{6})', caseSensitive: false),  // "Your OTP is 123456"
        RegExp(r'(\d{6})\s*(?:is\s+your|to\s+verify)', caseSensitive: false), // "123456 is your verification code"
        
        // Standalone number patterns (6-digit preferred over 4-digit)
        RegExp(r'\b(\d{6})\b'),           // 6 digit numbers (most common OTP length)
        RegExp(r'\b(\d{4})\b'),           // 4 digit numbers
        RegExp(r'\b(\d{5})\b'),           // 5 digit numbers (less common)
        RegExp(r'\b(\d{8})\b'),           // 8 digit numbers (some systems use longer codes)
        
        // Special formatting patterns
        RegExp(r'(\d{3})\s*[-\s]\s*(\d{3})'),  // "123 456" or "123-456"
        RegExp(r'(\d{2})\s*(\d{2})\s*(\d{2})'), // "12 34 56"
      ];

      // Track all found OTPs to choose the best one
      final foundOtps = <Map<String, dynamic>>[];

      for (int patternIndex = 0; patternIndex < patterns.length; patternIndex++) {
        final pattern = patterns[patternIndex];
        final matches = pattern.allMatches(textContent);
        
        for (final match in matches) {
          String? otp;
          
          if (patternIndex >= patterns.length - 2) {
            // Handle special formatting patterns (combine groups)
            if (match.groupCount >= 2) {
              if (patternIndex == patterns.length - 2) {
                // "123 456" or "123-456" -> "123456"
                otp = (match.group(1) ?? '') + (match.group(2) ?? '');
              } else {
                // "12 34 56" -> "123456"
                otp = (match.group(1) ?? '') + (match.group(2) ?? '') + (match.group(3) ?? '');
              }
            }
          } else {
            otp = match.group(1);
          }
          
          if (otp != null && RegExp(r'^\d+$').hasMatch(otp)) {
            final length = otp.length;
            
            // Only consider reasonable OTP lengths
            if (length >= 4 && length <= 8) {
              int score = 0;
              
              // Priority scoring based on pattern type
              if (patternIndex < 3) {
                score += 100; // Explicit OTP patterns
              } else if (patternIndex < 5) {
                score += 80;  // Contextual patterns
              } else if (length == 6) {
                score += 60;  // Standard 6-digit OTP
              } else if (length == 4) {
                score += 40;  // Common 4-digit OTP
              } else {
                score += 20;  // Other lengths
              }
              
              // Prefer standard lengths
              if (length == 6) score += 20;
              if (length == 4) score += 15;
              
              // Position in text (earlier is likely more recent)
              final position = match.start / textContent.length;
              if (position < 0.3) score += 15;
              else if (position < 0.6) score += 5;
              
              foundOtps.add({
                'otp': otp,
                'score': score,
                'pattern': patternIndex,
                'position': position,
                'match': match.group(0),
              });
              
              print('🔍 Found OTP candidate: "$otp" (length: $length, score: $score, pattern: $patternIndex)');
            }
          }
        }
      }
      
      if (foundOtps.isNotEmpty) {
        // Sort by score (highest first)
        foundOtps.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        
        final bestOtp = foundOtps.first;
        final selectedOtp = bestOtp['otp'] as String;
        
        print('✅ Selected best OTP: "$selectedOtp" (score: ${bestOtp['score']}, from: "${bestOtp['match']}")');
        return selectedOtp;
      }
      
      print('⚠️ No valid OTP pattern found in text');
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
      final content = clipboardData?.text?.trim();
      if (content != null) {
        print('📋 Clipboard content preview: ${content.length > 200 ? content.substring(0, 200) + "..." : content}');
      }
      return content;
    } catch (e) {
      print('❌ Error getting clipboard content: $e');
      return null;
    }
  }

  /// Debug method to analyze clipboard content with detailed OTP extraction analysis
  Future<void> debugClipboardContent() async {
    try {
      final content = await getClipboardContent();
      if (content != null && content.isNotEmpty) {
        print('🔍 === DETAILED CLIPBOARD DEBUG ===');
        print('📄 Full length: ${content.length} characters');
        print('📧 Total lines: ${content.split('\n').length}');
        
        // Check for target sender
        final hasTargetSender = content.toLowerCase().contains('contact.thinkcyber@gmail.com');
        print('🎯 Contains target sender: $hasTargetSender');
        
        if (hasTargetSender) {
          print('📧 Target sender found - showing email context');
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].toLowerCase().contains('contact.thinkcyber@gmail.com')) {
              print('📍 Target sender at line $i: ${lines[i]}');
              
              // Show surrounding context
              final startContext = (i - 2).clamp(0, lines.length);
              final endContext = (i + 5).clamp(0, lines.length);
              for (int j = startContext; j < endContext; j++) {
                final marker = (j == i) ? '>>> ' : '    ';
                print('$marker Line $j: ${lines[j]}');
              }
              break;
            }
          }
        }
        
        // Show first 15 lines for general context
        print('📄 First 15 lines of content:');
        final lines = content.split('\n').take(15).toList();
        for (int i = 0; i < lines.length; i++) {
          print('Line $i: ${lines[i]}');
        }
        
        // Test each extraction strategy
        print('\n🧪 === TESTING EXTRACTION STRATEGIES ===');
        
        // Strategy 1: Target sender specific
        if (hasTargetSender) {
          final targetOtp = _extractOtpFromTargetSender(content);
          print('🎯 Target sender OTP: $targetOtp');
        }
        
        // Strategy 2: Email structure
        final structureOtp = _extractOtpFromEmailStructure(content);
        print('📧 Email structure OTP: $structureOtp');
        
        // Strategy 3: Time context
        final contextOtp = _extractOtpWithTimeContext(content);
        print('⏰ Time context OTP: $contextOtp');
        
        // Strategy 4: Position based
        final positionOtp = _extractFirstOtpByPosition(content);
        print('📍 Position-based OTP: $positionOtp');
        
        // Strategy 5: Basic extraction
        final basicOtp = extractOtpFromText(content);
        print('🔍 Basic extraction OTP: $basicOtp');
        
        // Final result
        print('\n🎯 === FINAL RESULT ===');
        final finalOtp = extractLatestOtpFromText(content);
        print('✅ Final selected OTP: $finalOtp');
        
        // Show all numeric sequences found
        print('\n🔢 All numeric sequences (4-8 digits) found:');
        final numericPattern = RegExp(r'\b(\d{4,8})\b');
        final matches = numericPattern.allMatches(content);
        for (int i = 0; i < matches.length; i++) {
          final match = matches.elementAt(i);
          final number = match.group(1);
          final position = match.start;
          final lineNum = content.substring(0, position).split('\n').length - 1;
          print('  $i: "$number" at line $lineNum, position $position');
        }
        
        print('🔍 === END DETAILED DEBUG ===\n');
      } else {
        print('📋 Clipboard is empty');
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  /// Show current time in different formats for debugging
  void showCurrentTime() {
    final now = DateTime.now();
    final utcNow = now.toUtc();
    final istNow = _toIST(utcNow);
    
    print('🕒 === CURRENT TIME INFO ===');
    print('📍 Device Local Time: ${now.toString()}');
    print('🌍 UTC Time: ${utcNow.toIso8601String()}');  
    print('🇮🇳 IST Time: ${istNow.toString()}');
    print('📊 Your logged time 19:11:39 in IST would be: ${DateTime.parse("2025-11-07 19:11:39")}');
    print('🕒 === END TIME INFO ===\n');
  }

  /// Test method to verify OTP extraction with sample email content
  void testOtpExtraction() {
    print('🧪 === OTP EXTRACTION TEST ===');
    
    // Show current time first
    showCurrentTime();
    
    // Sample email content that simulates a typical Gmail chain with multiple OTPs
    const sampleEmail = '''
From: contact.thinkcyber@gmail.com
Subject: Your OTP Code
Date: Thu, Nov 7, 2025 at 3:45 PM

Your OTP is 123456. This code expires in 10 minutes.

---

On Wed, Nov 6, 2025 at 2:30 PM contact.thinkcyber@gmail.com wrote:
Your OTP is 654321. This code expires in 10 minutes.

--- Older Message ---
From: contact.thinkcyber@gmail.com  
Your verification code is 999888.
    ''';
    
    print('📧 Testing with sample email content...');
    final extractedOtp = extractLatestOtpFromText(sampleEmail);
    print('✅ Extracted OTP: $extractedOtp');
    print('🎯 Expected: 123456 (latest from Nov 7)');
    print('📊 Test Result: ${extractedOtp == "123456" ? "PASS" : "FAIL"}');
    
    // Test with different format
    const sampleEmail2 = '''
Gmail conversation with contact.thinkcyber@gmail.com

Today at 4:15 PM
Your verification code: 789012

Yesterday at 2:30 PM  
Your old code was: 345678
    ''';
    
    print('\n📧 Testing with second format...');
    final extractedOtp2 = extractLatestOtpFromText(sampleEmail2);
    print('✅ Extracted OTP: $extractedOtp2');
    print('🎯 Expected: 789012 (from today)');
    print('📊 Test Result: ${extractedOtp2 == "789012" ? "PASS" : "FAIL"}');
    
    print('🧪 === END TEST ===\n');
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
  
  /// Extract OTP from text (uses enhanced latest OTP detection)
  String? extractOtp(String text) {
    return _emailOtpService.extractLatestOtpFromText(text);
  }
  
  /// Mark when OTP was requested (for filtering old OTPs)
  void markOtpRequested() {
    _emailOtpService.markOtpRequested();
  }
  
  /// Debug clipboard content
  Future<void> debugClipboard() async {
    await _emailOtpService.debugClipboardContent();
  }
  
  /// Test OTP extraction functionality
  void testOtpExtraction() {
    _emailOtpService.testOtpExtraction();
  }
  
  /// Show current time in different formats
  void showCurrentTime() {
    _emailOtpService.showCurrentTime();
  }
}

/// Extension methods for easier OTP extraction
extension EmailOtpExtension on String {
  /// Extract latest OTP from this string
  String? extractOtp() {
    return EmailOtpService().extractLatestOtpFromText(this);
  }
  
  /// Check if string contains OTP pattern
  bool containsOtp() {
    return extractOtp() != null;
  }
}