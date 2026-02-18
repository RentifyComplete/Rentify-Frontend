import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class LoginHeaderWidget extends StatefulWidget {
  const LoginHeaderWidget({super.key});

  @override
  State<LoginHeaderWidget> createState() => _LoginHeaderWidgetState();
}

class _LoginHeaderWidgetState extends State<LoginHeaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _barWidthAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _barWidthAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // viewPadding.top is the true hardware status bar height,
    // unaffected by SafeArea — works even without SafeArea in parent
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Stack(
        children: [
          // ── Dark navy gradient background ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              6.w,
              statusBarHeight + 1.5.h,
              6.w,
              4.h,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D1B2A),
                  Color(0xFF1A2E46),
                  Color(0xFF1C3758),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Gold accent bar ──
                AnimatedBuilder(
                  animation: _barWidthAnim,
                  builder: (context, _) => Container(
                    width: _barWidthAnim.value * 36,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC8A95A), Color(0x4DC8A95A)],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 1.5.h),

                // ── Brand name + tagline ──
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // RENTIFY wordmark
                        Text(
                          'RENTIFY',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 4,
                            height: 1.0,
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        // Tagline
                        Text(
                          'YOUR HOME. CONNECTED.',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w300,
                            color: const Color(0xFF7DB8F0),
                            letterSpacing: 3.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 2.h),

                // ── Welcome text ──
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 0.6.h),
                        Text(
                          'Sign in to your account to continue',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withOpacity(0.5),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Subtle building-grid pattern overlay ──
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BuildingPatternPainter(),
              ),
            ),
          ),

          // ── City skyline at the bottom ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: CustomPaint(
                size: Size(double.infinity, 72),
                painter: _SkylinePainter(),
              ),
            ),
          ),

          // ── Light beam accent ──
          Positioned(
            top: 0,
            bottom: 0,
            left: 55.w,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.12,
                child: Container(
                  width: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF4A90D9).withOpacity(0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Building grid pattern painter ──
class _BuildingPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90D9).withOpacity(0.05)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── City skyline painter ──
class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90D9).withOpacity(0.10)
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Draw simplified building silhouettes
    final buildings = [
      // [x, y-from-bottom, width, height]
      [0.0, 0.0, 0.07 * w, 0.5 * h],
      [0.08 * w, 0.0, 0.10 * w, 0.75 * h],
      [0.19 * w, 0.0, 0.07 * w, 0.4 * h],
      [0.27 * w, 0.0, 0.11 * w, 0.65 * h],
      [0.39 * w, 0.0, 0.09 * w, 0.9 * h],
      [0.49 * w, 0.0, 0.07 * w, 0.55 * h],
      [0.57 * w, 0.0, 0.11 * w, 0.7 * h],
      [0.69 * w, 0.0, 0.08 * w, 0.45 * h],
      [0.78 * w, 0.0, 0.11 * w, 0.8 * h],
      [0.90 * w, 0.0, 0.10 * w, 0.5 * h],
    ];

    for (final b in buildings) {
      final bx = b[0];
      final bw = b[2];
      final bh = b[3];
      path.addRect(Rect.fromLTWH(bx, h - bh, bw, bh));
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}