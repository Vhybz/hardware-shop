import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/auth_provider.dart';
import '../services/user_provider.dart';
import '../services/offline_auth_vault.dart';
import '../models/user_model.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _breathingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _motionAnimation;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0.08, end: 0.22).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _motionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _checkAuthAndNavigate();
  }

  bool _hasNavigated = false;

  void _navigate(String route) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, route);
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    // Start animation without blocking auth check
    _controller.forward(from: 0.0);
    final startTime = DateTime.now();

    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      UserAccount? userAccount;

      if (currentUser != null) {
        ref.read(currentUserIdProvider.notifier).state = currentUser.id;

        try {
          final users = await ref
              .read(userProvider.notifier)
              .service
              .getUsers()
              .timeout(const Duration(milliseconds: 1500));

          try {
            userAccount = users.firstWhere((u) => u.id == currentUser.id);
          } catch (_) {
            userAccount = null;
          }
        } catch (e) {
          debugPrint('Splash Auth Timeout/Error (Offline Mode): $e');
        }
      }

      // If online fetch returned null or internet is off, load cached offline vault profile
      userAccount ??= await OfflineAuthVault.getLastSavedUserProfile();

      // Ensure animation has played at least 1.2 seconds so user sees splash branding
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 1200) {
        await Future.delayed(Duration(milliseconds: 1200 - elapsed));
      }

      if (!mounted) return;

      if (userAccount != null && userAccount.status == AccountStatus.approved) {
        ref.read(sessionUserProfileProvider.notifier).state = userAccount;
        ref.read(currentUserIdProvider.notifier).state = userAccount.id;

        if (userAccount.isPasscodeEnabled &&
            userAccount.passcode != null &&
            userAccount.passcode!.isNotEmpty) {
          ref.read(passcodeUnlockedProvider.notifier).state = false;
        } else {
          ref.read(passcodeUnlockedProvider.notifier).state = true;
        }

        switch (userAccount.activePrimaryRole) {
          case UserRole.admin:
          case UserRole.superAdmin:
            _navigate('/admin');
            break;
          case UserRole.cashier:
            _navigate('/cashier');
            break;
        }
        return;
      }
    } catch (e) {
      debugPrint('Splash: Auth check error: $e');
    }

    _navigate('/onboarding');
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgBottom = Color(0xFF09090B); // Deep Hardware Black
    const accentYellow = Color(0xFFCC7722); // Hardware DeWalt Amber Yellow (#CC7722)

    final size = MediaQuery.of(context).size;
    final double tapeWidth = math.min(320.0, size.width * 0.88);

    return Scaffold(
      backgroundColor: bgBottom,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Gradient matching inspiration mood
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breathingAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 1.2,
                      colors: [
                        accentYellow.withValues(alpha: _breathingAnimation.value),
                        const Color(0xFF1C1917),
                        bgBottom,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Foreground Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final progress = _motionAnimation.value;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. CIRCULAR AVATAR LOGO WITH WHITE BORDER (Matching Inspiration)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                width: 145,
                                height: 145,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: Colors.white, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: accentYellow.withValues(alpha: 0.25),
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/logo/logo.jpg',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // 2. APP NAME & SUBTITLE
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                const Text(
                                  'ADOM MMOROSO ENT.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'HARDWARE (WHOLE & RETAIL)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 52),

                          // 3. TAPE MEASURE PROGRESS BAR ANIMATION
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SizedBox(
                              width: tapeWidth,
                              height: 90,
                              child: CustomPaint(
                                size: Size(tapeWidth, 90),
                                painter: _TapeMeasureProgressBarPainter(
                                  progress: progress,
                                  accentColor: accentYellow,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 4. DIGITAL PERCENTAGE ONLY
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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

/// CustomPainter that renders a realistic hardware tape measure with its steel ruler extending out as a progress bar.
class _TapeMeasureProgressBarPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color accentColor;

  _TapeMeasureProgressBarPainter({
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Dimensions
    const double caseWidth = 72.0;
    const double caseHeight = 76.0;
    const double caseLeft = 8.0;
    final double caseTop = (height - caseHeight) / 2;

    const double bladeHeight = 22.0;
    final double bladeTop = caseTop + (caseHeight - bladeHeight) / 2;
    const double slotX = caseLeft + caseWidth - 8.0;
    final double maxBladeLength = width - slotX - 16.0;
    final double currentBladeLength = (maxBladeLength * progress).clamp(0.0, maxBladeLength);

    // -------------------------------------------------------------------------
    // 1. EXTENDING STEEL RULER BLADE (Progress Bar)
    // -------------------------------------------------------------------------
    if (currentBladeLength > 0) {
      final bladeRect = Rect.fromLTWH(slotX, bladeTop, currentBladeLength, bladeHeight);

      // Metallic Steel Blade Yellow Gradient
      final bladeGradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFEF08A), // Top Highlight
          Color(0xFFFBBF24), // Vibrant Blade Yellow
          Color(0xFFF59E0B), // Deep Amber Base
        ],
        stops: [0.0, 0.4, 1.0],
      ).createShader(bladeRect);

      canvas.drawRect(bladeRect, Paint()..shader = bladeGradient);

      // Top and bottom thin border lines
      final borderPaint = Paint()
        ..color = const Color(0xFFB45309)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(bladeRect, borderPaint);

      // Central metallic glare line
      canvas.drawLine(
        Offset(slotX, bladeTop + 4),
        Offset(slotX + currentBladeLength, bladeTop + 4),
        Paint()..color = Colors.white.withValues(alpha: 0.4)..strokeWidth = 1.2,
      );

      // Ruler Tick Marks & Measurements
      final tickPaint = Paint()
        ..color = const Color(0xFF18181B)
        ..strokeWidth = 1.0;

      const double tickSpacing = 5.0;
      int unitIndex = 0;

      // Clip tick marks to the current extended blade length
      canvas.save();
      canvas.clipRect(bladeRect);

      for (double x = slotX + 4; x <= slotX + currentBladeLength; x += tickSpacing) {
        final bool isMajor = (unitIndex % 4 == 0);
        final bool isMedium = (unitIndex % 2 == 0);

        final double topTickLen = isMajor ? 7.0 : (isMedium ? 4.5 : 2.5);
        final double bottomTickLen = isMajor ? 6.0 : (isMedium ? 4.0 : 2.0);

        // Top edge ticks (metric / cm)
        canvas.drawLine(Offset(x, bladeTop), Offset(x, bladeTop + topTickLen), tickPaint);

        // Bottom edge ticks (inches)
        canvas.drawLine(Offset(x, bladeTop + bladeHeight), Offset(x, bladeTop + bladeHeight - bottomTickLen), tickPaint);

        // Draw numbers at major ticks
        if (isMajor && x + 8 <= slotX + currentBladeLength) {
          final numberVal = (unitIndex ~/ 4) + 1;
          final TextPainter tp = TextPainter(
            text: TextSpan(
              text: '$numberVal',
              style: TextStyle(
                color: (numberVal % 5 == 0) ? const Color(0xFFDC2626) : const Color(0xFF18181B),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          tp.paint(canvas, Offset(x - (tp.width / 2), bladeTop + (bladeHeight - tp.height) / 2));
        }

        unitIndex++;
      }
      canvas.restore();

      // -----------------------------------------------------------------------
      // 2. STEEL END HOOK (At the leading tip)
      // -----------------------------------------------------------------------
      final double hookX = slotX + currentBladeLength;
      final hookRect = Rect.fromLTWH(hookX, bladeTop - 2, 6, bladeHeight + 4);

      // Chrome Hook Gradient
      final hookGradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFE2E8F0),
          Color(0xFF94A3B8),
          Color(0xFF475569),
        ],
      ).createShader(hookRect);

      // Steel Hook Plate
      canvas.drawRRect(
        RRect.fromRectAndRadius(hookRect, const Radius.circular(2)),
        Paint()..shader = hookGradient,
      );

      // Downward Lip of Hook
      canvas.drawRect(
        Rect.fromLTWH(hookX + 4, bladeTop + bladeHeight + 2, 3, 5),
        Paint()..color = const Color(0xFF475569),
      );

      // Hook Rivets
      final rivetPaint = Paint()..color = const Color(0xFF1E293B);
      canvas.drawCircle(Offset(hookX + 2.5, bladeTop + 5), 1.2, rivetPaint);
      canvas.drawCircle(Offset(hookX + 2.5, bladeTop + bladeHeight - 5), 1.2, rivetPaint);
    }

    // -------------------------------------------------------------------------
    // 3. REALISTIC TAPE MEASURE CASING (Left side)
    // -------------------------------------------------------------------------
    final caseRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(caseLeft, caseTop, caseWidth, caseHeight),
      const Radius.circular(16),
    );

    // Casing Shadow
    canvas.drawRRect(
      caseRRect.shift(const Offset(3, 4)),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    // Yellow Body Gradient
    final caseGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFDE047),
        Color(0xFFF59E0B),
        Color(0xFFD97706),
        Color(0xFFB45309),
      ],
      stops: [0.0, 0.35, 0.7, 1.0],
    ).createShader(Rect.fromLTWH(caseLeft, caseTop, caseWidth, caseHeight));

    canvas.drawRRect(caseRRect, Paint()..shader = caseGradient);

    // Dark Rubber Bumper Overmolding
    final rubberPaint = Paint()..color = const Color(0xFF18181B);

    // Bottom & Top-left Rubber Bumpers
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(caseLeft, caseTop + caseHeight - 16, caseWidth - 10, 16),
        bottomLeft: const Radius.circular(16),
      ),
      rubberPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(caseLeft, caseTop, 18, caseHeight),
        topLeft: const Radius.circular(16),
        bottomLeft: const Radius.circular(16),
      ),
      rubberPaint,
    );

    // Red Lock Switch Button (Top)
    final lockSwitchRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(caseLeft + 22, caseTop + 4, 18, 10),
      const Radius.circular(3),
    );
    canvas.drawRRect(lockSwitchRect, Paint()..color = const Color(0xFFDC2626));
    canvas.drawRRect(
      lockSwitchRect,
      Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );

    // Center Circular Brand Badge ("8m / 26ft")
    final badgeCenter = Offset(caseLeft + (caseWidth / 2) + 2, caseTop + (caseHeight / 2) + 2);
    const double badgeRadius = 18.0;

    canvas.drawCircle(badgeCenter, badgeRadius, rubberPaint);
    canvas.drawCircle(
      badgeCenter,
      badgeRadius - 2,
      Paint()..color = accentColor..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // Badge Text
    final TextPainter badgeTp = TextPainter(
      text: const TextSpan(
        text: '8m\n26ft',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    badgeTp.paint(canvas, Offset(badgeCenter.dx - (badgeTp.width / 2), badgeCenter.dy - (badgeTp.height / 2)));

    // Outlet Slot Mouth (Right)
    final slotRect = Rect.fromLTWH(slotX - 2, bladeTop - 2, 6, bladeHeight + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(slotRect, const Radius.circular(2)),
      rubberPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TapeMeasureProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
