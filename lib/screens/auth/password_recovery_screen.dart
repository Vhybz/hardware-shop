import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../services/sms_service.dart';
import '../../services/offline_auth_vault.dart';
import '../../services/theme_provider.dart';

class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  ConsumerState<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends ConsumerState<PasswordRecoveryScreen> {
  int _step = 0; // 0: Account Lookup, 1: Verify OTP, 2: New Password, 3: Success

  // Form Controllers
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Password Visibility
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Account State
  String? _matchedUserId;
  String? _matchedUserEmail;
  String? _matchedUserPhone;
  String? _matchedUserName;
  String? _generatedOtp;

  // Timer & Async State
  Timer? _timer;
  int _secondsRemaining = 300; // 5 minutes validity
  bool _isLoading = false;

  // Password Strength
  double _strengthProgress = 0;
  String _passwordStrength = 'None';
  Color _strengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  String get _timerText {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _checkPasswordStrength() {
    final pass = _newPasswordController.text;
    double score = 0;

    if (pass.isEmpty) {
      setState(() {
        _strengthProgress = 0;
        _passwordStrength = 'None';
        _strengthColor = Colors.grey;
      });
      return;
    }

    if (pass.length >= 6) score += 0.25;
    if (pass.length >= 10) score += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(pass)) score += 0.25;
    if (RegExp(r'[0-9]').hasMatch(pass)) score += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass)) score += 0.1;

    setState(() {
      _strengthProgress = score;
      if (score <= 0.25) {
        _passwordStrength = 'Weak';
        _strengthColor = Colors.red;
      } else if (score <= 0.6) {
        _passwordStrength = 'Fair';
        _strengthColor = Colors.orange;
      } else if (score <= 0.8) {
        _passwordStrength = 'Good';
        _strengthColor = Colors.blue;
      } else {
        _passwordStrength = 'Strong';
        _strengthColor = Colors.green;
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 3)}';
  }

  // ---------------------------------------------------------------------------
  // STEP 1: Account Lookup
  // ---------------------------------------------------------------------------
  Future<void> _handleStep1AccountLookup() async {
    final rawInput = _identifierController.text.trim();
    if (rawInput.isEmpty) {
      _showError('Please enter your registered Email Address or Phone Number.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final vaultUser = OfflineAuthVault.getAccount(rawInput);
      Map<String, dynamic>? userRecord;
      if (vaultUser != null) {
        userRecord = vaultUser;
      }

      if (userRecord == null) {
        _showError('No account found matching "$rawInput". Please verify and try again.');
        setState(() => _isLoading = false);
        return;
      }

      final String? userPhone = userRecord['phone']?.toString().trim();
      if (userPhone == null || userPhone.isEmpty) {
        _showError('No phone number registered for this account. Please contact your system administrator.');
        setState(() => _isLoading = false);
        return;
      }

      // Generate Cryptographically Secure 6-Digit OTP
      final String code = (100000 + Random.secure().nextInt(900000)).toString();

      // Send SMS OTP via SMS Gateway
      final bool smsSent = await SmsService.sendVerificationCodeSms(userPhone, code);

      if (!smsSent) {
        _showError('Failed to send SMS OTP code. Please check internet connection or contact support.');
        setState(() => _isLoading = false);
        return;
      }

      // Save state
      _matchedUserId = userRecord['id']?.toString();
      _matchedUserEmail = userRecord['email']?.toString();
      _matchedUserPhone = userPhone;
      _matchedUserName = userRecord['first_name']?.toString() ?? 'Valued Staff';
      _generatedOtp = code;

      _startTimer();
      _showSuccess('SMS OTP code dispatched to ${_maskPhone(userPhone)}.');

      setState(() {
        _step = 1;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Account Lookup Error: $e');
      _showError('An unexpected error occurred during account lookup: $e');
      setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 2: OTP Verification
  // ---------------------------------------------------------------------------
  Future<void> _handleStep2VerifyOtp() async {
    final enteredCode = _otpController.text.trim();

    if (enteredCode.isEmpty) {
      _showError('Please enter the 6-digit verification code.');
      return;
    }

    if (_secondsRemaining <= 0) {
      _showError('The verification code has expired. Please tap Resend SMS to get a new code.');
      return;
    }

    if (enteredCode != _generatedOtp) {
      _showError('Invalid verification code. Please check the SMS and try again.');
      return;
    }

    _timer?.cancel();
    _showSuccess('Code verified successfully! You may now set a new password.');

    setState(() => _step = 2);
  }

  Future<void> _handleResendOtp() async {
    if (_matchedUserPhone == null) return;

    setState(() => _isLoading = true);

    final String newCode = (100000 + Random.secure().nextInt(900000)).toString();
    final bool smsSent = await SmsService.sendVerificationCodeSms(_matchedUserPhone!, newCode);

    if (smsSent) {
      _generatedOtp = newCode;
      _startTimer();
      _otpController.clear();
      _showSuccess('New SMS OTP code sent to ${_maskPhone(_matchedUserPhone!)}.');
    } else {
      _showError('Failed to resend SMS OTP code. Please try again later.');
    }

    setState(() => _isLoading = false);
  }

  // ---------------------------------------------------------------------------
  // STEP 3: Password Update
  // ---------------------------------------------------------------------------
  Future<void> _handleStep3UpdatePassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showError('Please fill in both password fields.');
      return;
    }

    if (newPass.length < 6) {
      _showError('New password must be at least 6 characters long.');
      return;
    }

    if (newPass != confirmPass) {
      _showError('Passwords do not match. Please ensure both fields match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_matchedUserEmail != null) {
        await OfflineAuthVault.updatePassword(_matchedUserEmail!, newPass);
      }

      // 3. Save new password hash in local Offline Auth Vault only after successful online update
      if (_matchedUserEmail != null) {
        await OfflineAuthVault.saveUserCredentialsOnline(
          UserAccount(
            id: _matchedUserId!,
            email: _matchedUserEmail!,
            firstName: _matchedUserName ?? 'Staff',
            surname: '',
            role: UserRole.cashier,
          ),
          _matchedUserEmail!,
          newPass,
        );
      }

      setState(() {
        _step = 3;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Password Update Error: $e');
      _showError('Failed to update password: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final Color activePrimary = themeState.primaryColor;
    final bool isMonochromeWhite = activePrimary.toARGB32() == 0xFFFFFFFF;

    final Color primaryAccent = isMonochromeWhite ? const Color(0xFF18181B) : activePrimary;
    final Color cardBg = isMonochromeWhite ? Colors.white : (theme.cardTheme.color ?? const Color(0xFF18181B));
    final Color textColor = isMonochromeWhite ? const Color(0xFF18181B) : (theme.brightness == Brightness.dark ? Colors.white : const Color(0xFF18181B));
    final Color pageBg = isMonochromeWhite ? const Color(0xFFF8FAFC) : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        title: const Text('Password Recovery'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: cardBg,
              elevation: isMonochromeWhite ? 2 : 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                side: BorderSide(color: isMonochromeWhite ? const Color(0xFFCBD5E1) : primaryAccent.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _step == 3 ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
                        size: 48,
                        color: _step == 3 ? Colors.green : primaryAccent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),

                    // Title
                    Text(
                      _step == 0
                          ? 'Account Lookup'
                          : (_step == 1
                              ? 'Enter Verification Code'
                              : (_step == 2 ? 'Create New Password' : 'Password Reset Successful!')),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s),

                    // Step Indicator Progress Bar
                    if (_step < 3) ...[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStepDot(0, '1. Account', primaryAccent, textColor),
                            _buildStepLine(0, primaryAccent),
                            _buildStepDot(1, '2. Verify', primaryAccent, textColor),
                            _buildStepLine(1, primaryAccent),
                            _buildStepDot(2, '3. Password', primaryAccent, textColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),
                    ],

                    // STEP CONTENT
                    if (_step == 0) _buildStep1UI(theme, primaryAccent, textColor, isMonochromeWhite),
                    if (_step == 1) _buildStep2UI(theme, primaryAccent, textColor, isMonochromeWhite),
                    if (_step == 2) _buildStep3UI(theme, primaryAccent, textColor, isMonochromeWhite),
                    if (_step == 3) _buildSuccessUI(theme, primaryAccent, textColor, isMonochromeWhite),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepDot(int stepIndex, String label, Color primaryAccent, Color textColor) {
    final bool isActive = _step >= stepIndex;
    final bool isCurrent = _step == stepIndex;
    final color = isActive ? primaryAccent : Colors.grey.shade400;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isCurrent ? 28 : 22,
          height: isCurrent ? 28 : 22,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '${stepIndex + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isActive ? textColor : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep, Color primaryAccent) {
    final bool isActive = _step > afterStep;
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      color: isActive ? primaryAccent : Colors.grey.shade300,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 UI
  // ---------------------------------------------------------------------------
  Widget _buildStep1UI(ThemeData theme, Color primaryAccent, Color textColor, bool isMonochromeWhite) {
    final Color buttonBg = isMonochromeWhite 
        ? const Color(0xFF18181B) 
        : (primaryAccent.toARGB32() == 0xFFF59E0B ? const Color(0xFFF59E0B) : primaryAccent);
    final Color buttonFg = isMonochromeWhite 
        ? Colors.white 
        : (primaryAccent.toARGB32() == 0xFFF59E0B ? const Color(0xFF18181B) : Colors.white);

    return Column(
      children: [
        Text(
          'Enter your registered Email Address or Phone Number to receive a 6-digit SMS verification code.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: isMonochromeWhite ? const Color(0xFF475569) : Colors.grey),
        ),
        const SizedBox(height: AppSpacing.l),
        TextField(
          controller: _identifierController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Email Address or Phone Number',
            labelStyle: TextStyle(color: isMonochromeWhite ? const Color(0xFF64748B) : Colors.grey),
            hintText: 'e.g. user@example.com or 0542562486',
            hintStyle: TextStyle(color: isMonochromeWhite ? const Color(0xFF94A3B8) : Colors.grey),
            prefixIcon: Icon(Icons.person_search_rounded, color: primaryAccent),
            filled: true,
            fillColor: isMonochromeWhite ? const Color(0xFFF1F5F9) : theme.inputDecorationTheme.fillColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _handleStep1AccountLookup(),
        ),
        const SizedBox(height: AppSpacing.l),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleStep1AccountLookup,
            icon: _isLoading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: buttonFg))
                : const Icon(Icons.sms_rounded),
            label: Text(_isLoading ? 'Searching...' : 'Send SMS Verification Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonFg,
              elevation: isMonochromeWhite ? 2 : 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 UI
  // ---------------------------------------------------------------------------
  Widget _buildStep2UI(ThemeData theme, Color primaryAccent, Color textColor, bool isMonochromeWhite) {
    final bool isExpired = _secondsRemaining <= 0;
    final Color buttonBg = isMonochromeWhite 
        ? const Color(0xFF18181B) 
        : (primaryAccent.toARGB32() == 0xFFF59E0B ? const Color(0xFFF59E0B) : primaryAccent);
    final Color buttonFg = isMonochromeWhite 
        ? Colors.white 
        : (primaryAccent.toARGB32() == 0xFFF59E0B ? const Color(0xFF18181B) : Colors.white);

    return Column(
      children: [
        Text(
          'A 6-digit SMS verification code was dispatched to ${_maskPhone(_matchedUserPhone!)}.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: textColor),
        ),
        const SizedBox(height: AppSpacing.m),

        // Countdown Timer Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isExpired ? Colors.red.shade50 : primaryAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isExpired ? Colors.red : primaryAccent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpired ? Icons.error_outline_rounded : Icons.timer_rounded,
                size: 18,
                color: isExpired ? Colors.red : primaryAccent,
              ),
              const SizedBox(width: 8),
              Text(
                isExpired ? 'Code Expired' : 'Expires in: $_timerText',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isExpired ? Colors.red : primaryAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.l),

        // OTP Code Input Field
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8.0, color: textColor),
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: '6-Digit OTP Code',
            labelStyle: TextStyle(color: isMonochromeWhite ? const Color(0xFF64748B) : Colors.grey),
            counterText: '',
            filled: true,
            fillColor: isMonochromeWhite ? const Color(0xFFF1F5F9) : theme.inputDecorationTheme.fillColor,
            prefixIcon: Icon(Icons.password_rounded, color: primaryAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _handleStep2VerifyOtp(),
        ),
        const SizedBox(height: AppSpacing.l),

        // Verify Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: (_secondsRemaining > 0 && !_isLoading) ? _handleStep2VerifyOtp : null,
            icon: const Icon(Icons.verified_user_rounded),
            label: const Text('Verify Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonFg,
              elevation: isMonochromeWhite ? 2 : 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.m),

        // Resend Code Option
        TextButton.icon(
          onPressed: _isLoading ? null : _handleResendOtp,
          icon: Icon(Icons.refresh_rounded, size: 18, color: primaryAccent),
          label: Text(
            isExpired ? 'Resend Verification Code Now' : 'Didn\'t receive code? Resend SMS',
            style: TextStyle(color: primaryAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 UI
  // ---------------------------------------------------------------------------
  Widget _buildStep3UI(ThemeData theme, Color primaryAccent, Color textColor, bool isMonochromeWhite) {
    final Color buttonBg = isMonochromeWhite 
        ? const Color(0xFF18181B) 
        : (primaryAccent.toARGB32() == 0xFFF59E0B ? const Color(0xFFF59E0B) : primaryAccent);
    final Color buttonFg = isMonochromeWhite 
        ? Colors.white 
        : (primaryAccent.toARGB32() == 0xFFF59E0B ? const Color(0xFF18181B) : Colors.white);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set a strong new password for your account.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: isMonochromeWhite ? const Color(0xFF475569) : Colors.grey),
        ),
        const SizedBox(height: AppSpacing.l),

        // New Password
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          style: TextStyle(color: textColor),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'New Password',
            labelStyle: TextStyle(color: isMonochromeWhite ? const Color(0xFF64748B) : Colors.grey),
            prefixIcon: Icon(Icons.key_rounded, color: primaryAccent),
            filled: true,
            fillColor: isMonochromeWhite ? const Color(0xFFF1F5F9) : theme.inputDecorationTheme.fillColor,
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // Password Strength Indicator
        if (_newPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _strengthProgress,
                    color: _strengthColor,
                    backgroundColor: Colors.grey.shade300,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _passwordStrength,
                style: TextStyle(
                  color: _strengthColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.m),

        // Confirm Password
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            labelStyle: TextStyle(color: isMonochromeWhite ? const Color(0xFF64748B) : Colors.grey),
            prefixIcon: Icon(Icons.lock_reset_rounded, color: primaryAccent),
            filled: true,
            fillColor: isMonochromeWhite ? const Color(0xFFF1F5F9) : theme.inputDecorationTheme.fillColor,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _handleStep3UpdatePassword(),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleStep3UpdatePassword,
            icon: _isLoading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: buttonFg))
                : const Icon(Icons.check_circle_rounded),
            label: Text(_isLoading ? 'Updating Password...' : 'Reset Password'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonFg,
              elevation: isMonochromeWhite ? 2 : 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step Success UI
  // ---------------------------------------------------------------------------
  Widget _buildSuccessUI(ThemeData theme, Color primaryAccent, Color textColor, bool isMonochromeWhite) {
    final Color buttonBg = isMonochromeWhite 
        ? const Color(0xFF18181B) 
        : (primaryAccent.toARGB32() == 0xFFF59E0B ? const Color(0xFFF59E0B) : primaryAccent);
    final Color buttonFg = isMonochromeWhite 
        ? Colors.white 
        : (primaryAccent.toARGB32() == 0xFFF59E0B ? const Color(0xFF18181B) : Colors.white);

    return Column(
      children: [
        Text(
          'Hello ${_matchedUserName ?? "Valued Staff"}${_matchedUserEmail != null ? " (${_matchedUserEmail!})" : ""}, your account password has been reset successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: textColor),
        ),
        const SizedBox(height: AppSpacing.m),
        Text(
          'You can now return to the login screen and sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: isMonochromeWhite ? const Color(0xFF64748B) : Colors.grey),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Back to Login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonFg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
