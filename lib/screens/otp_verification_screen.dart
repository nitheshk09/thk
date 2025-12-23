import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_client.dart';
import '../services/translation_service.dart';
import '../services/localization_service.dart';
import '../services/session_service.dart';
import '../widgets/translated_text.dart';

enum OtpFlowType { signup, login }

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.flow,
  });

  final String email;
  final OtpFlowType flow;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  final _api = ThinkCyberApi();

  bool _isSubmitting = false;
  bool _isResending = false;
  final Map<String, String> _translations = {};
  
  // Timer variables
  Timer? _timer;
  int _resendTimer = 120; // 2 minutes in seconds
  bool _canResend = false;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _api.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📱 OTP Screen - App lifecycle changed to: $state');
    
    // When app resumes (user comes back from checking email), restore focus
    if (state == AppLifecycleState.resumed) {
      if (mounted && _otpController.text.length < 6) {
        debugPrint('🔍 OTP Screen - App resumed, current OTP length: ${_otpController.text.length}');
        // Ensure system keyboard is shown
        SystemChannels.textInput.invokeMethod('TextInput.show');
        
        // Multiple delayed attempts to ensure focus is restored
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            debugPrint('🎯 OTP Screen - First focus attempt');
            FocusScope.of(context).requestFocus(_otpFocusNode);
            SystemChannels.textInput.invokeMethod('TextInput.show');
          }
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_otpFocusNode.hasFocus) {
            debugPrint('🎯 OTP Screen - Second focus attempt (backup)');
            FocusScope.of(context).requestFocus(_otpFocusNode);
            SystemChannels.textInput.invokeMethod('TextInput.show');
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ OTP Screen - App paused');
    } else if (state == AppLifecycleState.inactive) {
      debugPrint('⏸️ OTP Screen - App inactive');
    }
  }

  String _translateSync(String text) {
    return _translations[text] ?? text;
  }

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutExpo,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideController.forward();
    _fadeController.forward();
    
    _preloadTranslations();
    _startResendTimer();
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Request focus after frame is built and show keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          debugPrint('🎯 OTP Screen - Initial focus request on initState');
          FocusScope.of(context).requestFocus(_otpFocusNode);
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
    });
  }

  void _startResendTimer() {
    _timer?.cancel();
    
    setState(() {
      _resendTimer = 120;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _preloadTranslations() async {
    final service = TranslationService();
    final localization = LocalizationService();
    final targetLang = localization.languageCode;
    
    final texts = [
      'OTP code',
      'Enter your code',
      'Code should be 6 digits',
      'Something went wrong. Try again.',
      'Could not resend OTP. Try again.',
    ];
    
    for (final text in texts) {
      _translations[text] = await service.translate(text, 'en', targetLang);
    }
    
    if (mounted) setState(() {});
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final localPart = parts[0];
    final domain = parts[1];
    
    if (localPart.length <= 2) return email;
    
    final visibleStart = localPart.substring(0, 2);
    final maskedPart = '*' * (localPart.length - 2);
    return '$visibleStart$maskedPart@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
              theme.colorScheme.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background elements
            _buildBackgroundElements(),

            // Main content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                  children: [
                    // Top section with logo and back button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),

                      const Spacer(),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: size.height * 0.02),

                            // Logo section with fade animation
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                children: [
                                  Image.asset(
                                    'Asset/thk.png',
                                    height: 60,
                                   ),
                                  const SizedBox(height: 12),

                                   Text(
                                    'Increase Security Awareness In Public',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: size.height * 0.02),
                          ],
                        ),
                      ),

                      // Bottom card with glassmorphism
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, size.height * 0.5 * _slideAnimation.value),
                              child: child,
                            );
                          },
                          child: _buildVerificationCard(theme, size),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundElements() {
    return Stack(
      children: [
        // Floating orbs
        Positioned(
          top: -100,
          right: -50,
          child: _FloatingOrb(
            size: 300,
            color: Colors.blue.withOpacity(0.15),
            duration: 6,
          ),
        ),
        Positioned(
          top: 150,
          left: -100,
          child: _FloatingOrb(
            size: 250,
            color: Colors.purple.withOpacity(0.15),
            duration: 8,
          ),
        ),
        Positioned(
          bottom: -80,
          left: 50,
          child: _FloatingOrb(
            size: 200,
            color: Colors.cyan.withOpacity(0.12),
            duration: 7,
          ),
        ),

        // Grid pattern overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCard(ThemeData theme, Size size) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final availableHeight = constraints.maxHeight - keyboardHeight;
            
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 40, 24, math.max(24, keyboardHeight + 16)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight > 0 ? availableHeight - 80 : 400,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title section with improved styling
                    const Text(
                      'Email Verification',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    const TranslatedText(
                      'Enter the verification code sent to your email',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),
                    
                    // Email with edit button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 18,
                            color: const Color(0xFF2E7DFF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _maskEmail(widget.email),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                      
                    const SizedBox(height: 24),

                    // OTP Input boxes
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Visual OTP boxes
                          GestureDetector(
                            onTap: () {
                              FocusScope.of(context).requestFocus(_otpFocusNode);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (index) {
                                return _OtpBox(
                                  controller: _otpController,
                                  index: index,
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Hidden TextField for keyboard input - kept accessible for focus
                          SizedBox(
                            height: 0,
                            child: IgnorePointer(
                              ignoring: false,
                              child: TextField(
                                controller: _otpController,
                                focusNode: _otpFocusNode,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                maxLength: 6,
                                autofocus: false,
                                enableInteractiveSelection: false,
                                showCursor: false,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                style: const TextStyle(
                                  color: Colors.transparent,
                                  fontSize: 1,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                onChanged: (value) {
                                  debugPrint('📝 OTP input changed: ${value.length}/6');
                                  if (mounted) {
                                    setState(() {});
                                    if (value.length == 6) {
                                      FocusScope.of(context).unfocus();
                                    }
                                  }
                                },
                                onTap: () {
                                  debugPrint('👆 OTP TextField tapped');
                                  // Ensure cursor is at the end
                                  _otpController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: _otpController.text.length),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                      
                    const SizedBox(height: 20),

                    // Resend timer/button
                    Center(
                      child: _isResending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _canResend
                              ? TextButton(
                                  onPressed: _isSubmitting ? null : _resendOtp,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2E7DFF),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded, size: 18),
                                      SizedBox(width: 8),
                                      TranslatedText(
                                        'Resend OTP',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                  ),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Resend available in ',
                                        ),
                                        TextSpan(
                                          text: _formatTime(_resendTimer),
                                          style: const TextStyle(
                                            color: Color(0xFF2E7DFF),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                    ),

                    const SizedBox(height: 20),

                    // Verify button
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7DFF),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF2E7DFF).withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TranslatedText(
                                  'Verify',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.verified_rounded, size: 18),
                              ],
                            ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // Validate OTP length
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText(_translateSync('Code should be 6 digits')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.flow == OtpFlowType.signup) {
        final response = await _api.verifySignupOtp(
          email: widget.email,
          otp: _otpController.text.trim(),
        );
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(response.message)));

        if (response.success) {
          Navigator.of(context).pop(true);
        }
      } else {
        final fcmToken = await _fetchFcmToken();
        final deviceId = await _fetchDeviceId();
        final deviceName = await _fetchDeviceName();
        final response = await _api.verifyLoginOtp(
          email: widget.email,
          otp: _otpController.text.trim(),
          fcmToken: fcmToken,
          deviceId: deviceId,
          deviceName: deviceName,
        );

        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(response.message)));

        if (response.success) {
          await SessionService.saveSession(email: widget.email, response: response);
          if (!mounted) return;
          Navigator.of(context).pop(true);
        }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: TranslatedText(_translateSync('Something went wrong. Try again.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _fetchFcmToken() async {
    try {
      final hasPermission = await _ensureNotificationPermission();
      if (!hasPermission) return null;

      final messaging = FirebaseMessaging.instance;
      return await messaging.getToken();
    } catch (e) {
      debugPrint('⚠️ Failed to fetch FCM token: $e');
      return null;
    }
  }

  Future<String?> _fetchDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await info.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await info.iosInfo;
        return iosInfo.identifierForVendor;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Failed to fetch device ID: $e');
      return null;
    }
  }

  Future<String?> _fetchDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await info.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}'.trim();
      } else if (Platform.isIOS) {
        final iosInfo = await info.iosInfo;
        return iosInfo.name;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Failed to fetch device name: $e');
      return null;
    }
  }

  Future<bool> _ensureNotificationPermission() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      var status = await Permission.notification.status;
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Notifications are blocked. Enable them in Settings.')),
        );
        await openAppSettings();
        return false;
      }

      status = await Permission.notification.request();
      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Notifications denied forever. Please enable in Settings.')),
        );
        await openAppSettings();
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Notifications denied. Some alerts may be missed.')),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Notification permission check failed: $e');
    }

    return false;
  }

  Future<void> _resendOtp() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isResending = true);
    try {
      final response = await _api.resendOtp(email: widget.email);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(response.message)));
      
      // Restart the timer after successful resend
      _startResendTimer();
    } on ApiException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: TranslatedText(_translateSync('Could not resend OTP. Try again.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }


}

// Floating orb animation widget
class _FloatingOrb extends StatefulWidget {
  final double size;
  final Color color;
  final int duration;

  const _FloatingOrb({
    required this.size,
    required this.color,
    required this.duration,
  });

  @override
  State<_FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<_FloatingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _controller.value * 30 - 15,
            _controller.value * 40 - 20,
          ),
          child: Transform.scale(
            scale: 1.0 + (_controller.value * 0.15),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color,
                    widget.color.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Grid pattern painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }

    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final int index;

  const _OtpBox({
    required this.controller,
    required this.index,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final char = widget.index < text.length ? text[widget.index] : '';
    final hasValue = char.isNotEmpty;

    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue ? const Color(0xFF2E7DFF) : const Color(0xFFE2E8F0),
          width: hasValue ? 2 : 1,
        ),
        boxShadow: hasValue
            ? [
                BoxShadow(
                  color: const Color(0xFF2E7DFF).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          char,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: hasValue ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
