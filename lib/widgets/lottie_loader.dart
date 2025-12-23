import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit? fit;

  const LottieLoader({
    super.key,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'Asset/logo.json',
      width: width ?? 100,
      height: height ?? 100,
      fit: fit ?? BoxFit.contain,
      repeat: true,
      animate: true,
    );
  }
}

/// Full screen loader with centered Lottie animation
class FullScreenLottieLoader extends StatelessWidget {
  final String? message;

  const FullScreenLottieLoader({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LottieLoader(
              width: 150,
              height: 150,
            ),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small inline loader
class InlineLottieLoader extends StatelessWidget {
  final double size;

  const InlineLottieLoader({
    super.key,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return LottieLoader(
      width: size,
      height: size,
    );
  }
}
