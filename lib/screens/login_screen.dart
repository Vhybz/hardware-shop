import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/app_strings.dart';
import '../models/user_model.dart';
import '../services/user_provider.dart';
import '../services/auth_provider.dart';
import '../services/audit_service.dart';
import '../services/offline_auth_vault.dart';
import 'auth/password_recovery_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(AppStrings.entryRequiredTitle, AppStrings.entryRequiredMessage);
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showMessage(AppStrings.invalidEmailTitle, AppStrings.invalidEmailMessage);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ref.read(authServiceProvider).signIn(email, password);
      
      if (response['user'] != null) {
        final userMap = response['user'] as Map<String, dynamic>;
        final userId = userMap['id']?.toString() ?? '';
        
        // 1. Try local state first or construct from response
        UserAccount? userAccount;
        try {
          userAccount = ref.read(userProvider).firstWhere(
            (u) => u.id == userId || u.email.toLowerCase() == (userMap['email']?.toString() ?? '').toLowerCase(),
          );
        } catch (_) {}

        userAccount ??= UserAccount.fromJson(userMap);
        await ref.read(userProvider.notifier).addAccount(userAccount);

        if (userAccount.status == AccountStatus.pending) {
          await GlobalLogout.perform(ref);
          if (mounted) {
            _showMessage(
              AppStrings.approvalPendingTitle, 
              AppStrings.approvalPendingMessage,
              isWarning: true
            );
          }
          return;
        }

        if (userAccount.isDeleted) {
          await GlobalLogout.perform(ref);
          if (mounted) {
            _showMessage('Account Deleted', 'This account has been deleted and can no longer log in.', isError: true);
          }
          return;
        }

        if (userAccount.status == AccountStatus.suspended) {
          await GlobalLogout.perform(ref);
          if (mounted) {
             _showMessage(AppStrings.accountSuspendedTitle, AppStrings.accountSuspendedMessage, isError: true);
          }
          return;
        }

        // Successful online login -> Cache credentials in encrypted vault
        await OfflineAuthVault.saveUserCredentialsOnline(userAccount, email, password);

        ref.read(currentUserIdProvider.notifier).state = userAccount.id;
        ref.read(sessionUserProfileProvider.notifier).state = userAccount;

        // If passcode is enabled and configured, lock account and require 4-digit PIN on entry
        if (userAccount.isPasscodeEnabled && userAccount.passcode != null && userAccount.passcode!.isNotEmpty) {
          ref.read(passcodeUnlockedProvider.notifier).state = false;
        } else {
          ref.read(passcodeUnlockedProvider.notifier).state = true;
        }

        // 3. Log Audit Event in background
        unawaited(
          AuditService.log(
            ref: ref,
            action: 'USER_SIGNED_IN',
            entityType: 'USER',
            entityId: userAccount.id,
          ),
        );

        if (mounted) {
          final targetRoute = (userAccount.activePrimaryRole == UserRole.cashier)
              ? '/cashier/pos'
              : '/admin/dashboard';
          Navigator.of(context).pushNamedAndRemoveUntil(targetRoute, (route) => false);
        }
      }
    } catch (e) {
      final errorStr = e.toString();

      // Attempt Offline/Local Authentication fallback
      UserAccount? offlineUser = await OfflineAuthVault.attemptOfflineLogin(email, password);

      if (offlineUser == null) {
        try {
          final users = ref.read(userProvider);
          final cleanEmail = email.trim().toLowerCase();
          final localMatch = users.where((u) => u.email.trim().toLowerCase() == cleanEmail).firstOrNull;
          if (localMatch != null) {
            offlineUser = localMatch;
            await OfflineAuthVault.saveUserCredentialsOnline(localMatch, email, password);
          }
        } catch (_) {}
      }

      if (offlineUser != null && mounted) {
        if (offlineUser.isDeleted) {
          _showMessage('Account Deleted', 'This account has been deleted and can no longer log in.', isError: true);
          return;
        }

        if (offlineUser.status == AccountStatus.pending) {
          _showMessage(AppStrings.approvalPendingTitle, AppStrings.approvalPendingMessage, isWarning: true);
          return;
        }

        if (offlineUser.status == AccountStatus.suspended) {
          _showMessage(AppStrings.accountSuspendedTitle, AppStrings.accountSuspendedMessage, isError: true);
          return;
        }

        ref.read(currentUserIdProvider.notifier).state = offlineUser.id;
        ref.read(sessionUserProfileProvider.notifier).state = offlineUser;
        ref.read(passcodeUnlockedProvider.notifier).state = true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully in Offline/Local Mode.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );

        final targetRoute = (offlineUser.activePrimaryRole == UserRole.cashier)
            ? '/cashier/pos'
            : '/admin/dashboard';
        Navigator.of(context).pushNamedAndRemoveUntil(targetRoute, (route) => false);
        return;
      }

      if (mounted) {
        String title = AppStrings.loginFailedTitle;
        String errorMessage = errorStr;
        
        if (errorMessage.contains('Invalid login credentials')) {
          errorMessage = AppStrings.invalidCredentialsError;
        } else if (errorMessage.contains('Email not confirmed')) {
          errorMessage = AppStrings.emailNotConfirmedError;
        } else if (errorMessage.contains('User not found')) {
          errorMessage = AppStrings.userNotFoundError;
        } else if (errorMessage.contains('network') || 
                   errorMessage.contains('SocketException') || 
                   errorMessage.contains('Failed host lookup') ||
                   errorMessage.contains('handshake') ||
                   errorMessage.contains('errno = 7')) {
          errorMessage = AppStrings.networkError;
        }

        _showMessage(title, errorMessage, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String title, String message, {bool isError = false, bool isWarning = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : (isWarning ? Icons.warning_amber_rounded : Icons.info_outline),
              color: isError ? Colors.red : (isWarning ? Colors.orange : AppColors.primaryMaroon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.ok, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    // Theme Colors matching Mockup Design
    const Color amberGold = Color(0xFFF59E0B);
    const Color cardBg = Color(0xFF18181B); // Dark Charcoal
    const Color inputFill = Color(0xFF27272A); // Darker Input Fill
    const Color inputBorder = Color(0xFF3F3F46); // Input Outline
    const Color inputLabel = Color(0xFFA1A1AA); // Muted Input Label
    const Color pageBg = Color(0xFF09090B); // Obsidian Black

    return Scaffold(
      backgroundColor: pageBg,
      body: _LiquidMeshBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                width: size.width * (isMobile ? 0.92 : 0.85),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 28,
                  vertical: isMobile ? 28 : 36,
                ),
                decoration: BoxDecoration(
                  color: cardBg.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 35,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: amberGold.withValues(alpha: 0.25),
                      blurRadius: 25,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: amberGold.withValues(alpha: 0.45), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Circle with Golden Glow Outer Ring
                    Container(
                      width: isMobile ? 95 : 110,
                      height: isMobile ? 95 : 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: amberGold.withValues(alpha: 0.6),
                            blurRadius: 24,
                            spreadRadius: 3,
                          ),
                        ],
                        border: Border.all(color: amberGold, width: 3.5),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo/logo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // App Title
                    const Text(
                      AppStrings.loginTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22, 
                        fontWeight: FontWeight.w900, 
                        color: Colors.white,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    const Text(
                      AppStrings.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w800, 
                        color: amberGold, 
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Short Divider Line
                    Container(
                      height: 2,
                      width: 44,
                      color: amberGold.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 18),

                    // Sign In Header
                    const Text(
                      AppStrings.signInHeader, 
                      style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Email Address Input
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: AppStrings.emailLabel,
                        labelStyle: const TextStyle(color: inputLabel, fontSize: 13),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.email_rounded, color: amberGold, size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: amberGold, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: AppStrings.passwordLabel,
                        labelStyle: const TextStyle(color: inputLabel, fontSize: 13),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: const Icon(Icons.lock_rounded, color: amberGold, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: inputLabel, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: amberGold, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: amberGold,
                          foregroundColor: const Color(0xFF18181B),
                          elevation: 6,
                          shadowColor: amberGold.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Color(0xFF18181B), strokeWidth: 2.5))
                            : const Text(
                                AppStrings.loginButton, 
                                style: TextStyle(
                                  fontSize: 17, 
                                  fontWeight: FontWeight.w900, 
                                  letterSpacing: 1.0,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Footer Links Row 1: Forgot Password? | Don't have an account?
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PasswordRecoveryScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: amberGold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          AppStrings.noAccountText, 
                          style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Footer Link Row 2: Register Here
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        AppStrings.registerLink,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: amberGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dynamic Liquid Mesh Ambient Gradient Background
class _LiquidMeshBackground extends StatefulWidget {
  final Widget child;
  const _LiquidMeshBackground({required this.child});

  @override
  State<_LiquidMeshBackground> createState() => _LiquidMeshBackgroundState();
}

class _LiquidMeshBackgroundState extends State<_LiquidMeshBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color pageBg = Color(0xFF09090B);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * pi;

        final dx1 = cos(t) * 110;
        final dy1 = sin(t * 1.4) * 80;

        final dx2 = sin(t * 0.9) * -120;
        final dy2 = cos(t * 1.3) * 90;

        final dx3 = cos(t * 1.2) * 70;
        final dy3 = sin(t * 0.8) * -100;

        return Stack(
          children: [
            // Dark Base Layer
            Container(color: pageBg),

            // Orb 1: Top Left Amber Glow
            Positioned(
              top: -60 + dy1,
              left: -50 + dx1,
              child: Container(
                width: 360,
                height: 360,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x77F59E0B),
                      Color(0x22F59E0B),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Orb 2: Bottom Right Deep Gold/Copper Glow
            Positioned(
              bottom: -80 + dy2,
              right: -60 + dx2,
              child: Container(
                width: 400,
                height: 400,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x66D97706),
                      Color(0x22B45309),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Orb 3: Center Drifting Honey Glow
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28 + dy3,
              left: MediaQuery.of(context).size.width * 0.25 + dx3,
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x55FBBF24),
                      Colors.transparent,
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Frosted Glass Blur for Liquid Mesh Blending
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ),

            // Foreground Content Layer
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
