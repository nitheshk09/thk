import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/session_service.dart';
import '../services/api_client.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _backgroundController;
  late final AnimationController _logoController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  Widget? _destination;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    final logoCurve = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    );
    _logoOpacity = Tween<double>(begin: 0.75, end: 1).animate(logoCurve);
    _logoScale = Tween<double>(begin: 0.94, end: 1.05).animate(logoCurve);

    _prepareNavigation();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _prepareNavigation() async {
    final isAuthenticated = await SessionService.isAuthenticated();
    final hasOnboarded = await SessionService.hasOnboarded();

    // If session expired, clear it automatically
    if (!isAuthenticated && await SessionService.isSessionValid() == false) {
      await SessionService.clearSession();
    }

    final Widget destination = isAuthenticated
        ? const MainNavigationScreen()
        : hasOnboarded
            ? const LoginScreen()
            : const OnboardingScreen();

    if (!mounted) return;

    setState(() => _destination = destination);

    final canProceed = await _checkVersionAndMaybePrompt();
    if (!canProceed || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted || _navigated) return;
    _navigate(destination);
  }

  void _navigate(Widget destination) {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: destination,
        ),
      ),
    );
  }

  Future<bool> _checkVersionAndMaybePrompt() async {
    ThinkCyberApi? api;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 1;

      api = ThinkCyberApi();
      final response = await api.checkAppVersion(
        currentVersionCode: currentCode,
        platform: Platform.isIOS ? 'ios' : 'android',
      );

      if (!mounted) return false;
      final info = response.data;
      if (response.success != true || info == null) {
        return true;
      }

      final hasUpdate = info.latestVersionCode > currentCode;
      final shouldForce = info.forceUpdate || info.updateRequired || hasUpdate;

      if (!hasUpdate) {
        return true;
      }

      await _showUpdateDialog(info, packageInfo.appName, force: shouldForce);
      return !shouldForce;
    } catch (e) {
      debugPrint('⚠️ Version check failed: $e');
      return true;
    } finally {
      api?.dispose();
    }
  }

  Future<void> _showUpdateDialog(
      AppVersionInfo info,
      String appName, {
        required bool force,
      }) async {
    if (!mounted) return;

    final titleText = (appName.trim().isNotEmpty) ? appName.trim() : 'Update Available';
    final messageText = info.message.trim().isNotEmpty
        ? info.message.trim()
        : 'We’ve improved performance and fixed bugs. Update now for the best experience.';

    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (context) {
        final theme = Theme.of(context);
        return WillPopScope(
          onWillPop: () async => !force,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header (premium look)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.82),
                        ],
                      ),
                    ),

                    // https://play.google.com/store/apps/details?id=com.edu.thinkcyber
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'Asset/thk.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                force ? 'This update is required to continue.' : 'New version available',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.90),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (info.latestVersionName != null && info.latestVersionName!.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Text(
                              'v${info.latestVersionName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          messageText,
                          style: TextStyle(
                            fontSize: 13.8,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.system_update_alt_rounded, size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Update now to keep using the app.',
                                  style: TextStyle(
                                    fontSize: 12.8,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openStore(info),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Update Now',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _openStore(AppVersionInfo info) async {
    final url = Platform.isIOS
        ? (info.iosStoreUrl?.isNotEmpty == true
            ? info.iosStoreUrl
            : 'https://apps.apple.com/app/thinkcyber/id123456789')
        : 'https://play.google.com/store/apps/details?id=com.edu.thinkcyber';
    if (url == null || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1), // Indigo
              Color(0xFF4F46E5), // Indigo darker
              Color(0xFF2563EB), // Blue
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Animated background circles
            Positioned(
              top: -100,
              right: -100,
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _backgroundController.value * 2 * math.pi,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_backgroundController.value * 2 * math.pi,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Main content
            Center(
              child: FadeTransition(
                opacity: _logoOpacity,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo with contrasting background
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.95),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'Asset/thk.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // App title with modern styling
                      const Text(
                        'ThinkCyber',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tagline
                      const Text(
                        'Learn • Secure • Empower',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 50),
                      // Loading indicator with modern design
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom accent line
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
