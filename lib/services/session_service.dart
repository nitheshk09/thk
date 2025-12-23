import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class SessionService {
  static const String _keyAuthenticated = 'thinkcyber_authenticated';
  static const String _keySessionToken = 'thinkcyber_session_token';
  static const String _keySessionTimestamp = 'thinkcyber_session_timestamp';
  static const String _keyEmail = 'thinkcyber_email';
  static const String _keyUser = 'thinkcyber_user';
  static const String _keyUserId = 'thinkcyber_user_id';
  static const String _keyUserName = 'thinkcyber_user_name';
  static const String _keyUserRole = 'thinkcyber_user_role';
  static const String _keyUserStatus = 'thinkcyber_user_status';
  static const String _keyOnboarded = 'thinkcyber_onboarded';
  
  // Session duration: 7 days in milliseconds
  // You can adjust this as needed: 
  // - 24 hours: 24 * 60 * 60 * 1000
  // - 7 days: 7 * 24 * 60 * 60 * 1000
  // - 30 days: 30 * 24 * 60 * 60 * 1000
  static const int sessionDurationMs = 7 * 24 * 60 * 60 * 1000; // 7 days

  /// Check if user is authenticated and session is valid
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuth = prefs.getBool(_keyAuthenticated) ?? false;
    
    if (!isAuth) return false;
    
    return await isSessionValid();
  }

  /// Check if current session is still valid (not expired)
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionTimestamp = prefs.getInt(_keySessionTimestamp) ?? 0;
    
    if (sessionTimestamp == 0) return false;
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    return (currentTime - sessionTimestamp) < sessionDurationMs;
  }

  /// Check if user has completed onboarding
  static Future<bool> hasOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarded) ?? false;
  }

  /// Save user session after successful login
  static Future<void> saveSession({
    required String email,
    required LoginVerificationResponse response,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keySessionToken, response.sessionToken ?? '');
    await prefs.setString(_keyEmail, email);
    await prefs.setInt(_keySessionTimestamp, DateTime.now().millisecondsSinceEpoch);
    
    if (response.user != null) {
      await prefs.setString(_keyUser, jsonEncode(response.user!.toJson()));
      await prefs.setInt(_keyUserId, response.user!.id);
      await prefs.setString(_keyUserName, response.user!.name);
      await prefs.setString(_keyUserRole, response.user!.role);
      await prefs.setString(_keyUserStatus, response.user!.status);
    }
    
    await prefs.setBool(_keyAuthenticated, response.success);
  }

  /// Clear all session data (logout or session expired)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove(_keyAuthenticated);
    await prefs.remove(_keySessionToken);
    await prefs.remove(_keySessionTimestamp);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserStatus);
    // Note: We don't clear onboarding status so user doesn't see onboarding again
  }

  /// Mark onboarding as completed
  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarded, true);
  }

  /// Get current user data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!await isAuthenticated()) return null;
    
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    
    if (userJson == null) return null;
    
    try {
      return jsonDecode(userJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Get current session token
  static Future<String?> getSessionToken() async {
    if (!await isAuthenticated()) return null;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySessionToken);
  }

  /// Get current user email
  static Future<String?> getUserEmail() async {
    if (!await isAuthenticated()) return null;
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  /// Refresh session timestamp (call this when user is active)
  static Future<void> refreshSession() async {
    if (await isAuthenticated()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySessionTimestamp, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Get session age in hours
  static Future<int> getSessionAgeInHours() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionTimestamp = prefs.getInt(_keySessionTimestamp) ?? 0;
    
    if (sessionTimestamp == 0) return 0;
    
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final ageMs = currentTime - sessionTimestamp;
    return (ageMs / (60 * 60 * 1000)).floor(); // Convert to hours
  }
}