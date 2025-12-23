import 'dart:async';

import 'screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait orientation only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Firebase and log FCM token
  await Firebase.initializeApp();
  try {
    final status = await Permission.notification.status;
    PermissionStatus permissionResult = status;

    if (status.isDenied) {
      permissionResult = await Permission.notification.request();
    }

    if (permissionResult.isGranted) {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      print('📲 FCM TOKEN: ${token ?? 'unavailable'}');
    } else if (permissionResult.isPermanentlyDenied) {
      print('⚠️ Notifications permanently denied. Enable them in system settings.');
    } else {
      print('⚠️ Notifications denied. Skipping FCM token retrieval.');
    }
  } catch (e) {
    print('⚠️ Failed to fetch FCM token: $e');
  }

  // Log API configuration at startup
  ApiConfig.logConfiguration();
  
  // Show detailed configuration for debugging
  print('🎯 CURRENT API BASE URL: ${ApiConfig.baseUrl}');
  print('🌍 ENVIRONMENT: ${ApiConfig.environmentName}');
  
  runApp(const ThinkCyberApp());
}

class ThinkCyberApp extends StatelessWidget {
  const ThinkCyberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThinkCyber LMS',
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    const primaryBlue = Color(0xFF0D6EFD);
    const deepNavy = Color(0xFF00163A);
    const slate = Color(0xFF1E293B);
    const background = Color(0xFFF5F7FD);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        secondary: const Color(0xFF3B82F6),
      ),
    );

    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: deepNavy,
        letterSpacing: -0.2,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: deepNavy,
        letterSpacing: -0.15,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: deepNavy,
        letterSpacing: -0.1,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: slate,
        letterSpacing: 0.1,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: slate.withValues(alpha: 0.85),
        height: 1.5,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: slate.withValues(alpha: 0.9),
        height: 1.5,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: slate.withValues(alpha: 0.75),
        height: 1.45,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: deepNavy,
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 3,
          shadowColor: primaryBlue.withValues(alpha: 0.35),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: BorderSide(
            color: primaryBlue.withValues(alpha: 0.35),
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 18,
        ),
        labelStyle: TextStyle(color: slate.withValues(alpha: 0.7)),
        hintStyle: TextStyle(color: slate.withValues(alpha: 0.45)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: slate.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: slate.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primaryBlue, width: 1.6),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        margin: EdgeInsets.zero,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: slate.withValues(alpha: 0.1),
      ),
    );
  }
}
