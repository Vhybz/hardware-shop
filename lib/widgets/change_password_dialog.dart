import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/offline_auth_vault.dart';

class ChangePasswordDialog extends StatefulWidget {
  final String? userEmail;

  const ChangePasswordDialog({super.key, this.userEmail});

  static Future<void> show(BuildContext context, {String? userEmail}) async {
    return showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(userEmail: userEmail),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _passwordStrength {
    final text = _newPasswordController.text;
    if (text.isEmpty) return '';
    if (text.length < 6) return 'Weak';
    
    bool hasUpper = text.contains(RegExp(r'[A-Z]'));
    bool hasLower = text.contains(RegExp(r'[a-z]'));
    bool hasDigits = text.contains(RegExp(r'[0-9]'));
    bool hasSpecial = text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    if (text.length >= 8 && hasUpper && hasLower && hasDigits && hasSpecial) {
      return 'Strong';
    }
    if (text.length >= 6 && (hasUpper || hasLower) && hasDigits) {
      return 'Medium';
    }
    return 'Weak';
  }

  Color get _strengthColor {
    switch (_passwordStrength) {
      case 'Weak':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Strong':
        return Colors.green;
      default:
        return Colors.transparent;
    }
  }

  double get _strengthProgress {
    switch (_passwordStrength) {
      case 'Weak':
        return 0.33;
      case 'Medium':
        return 0.66;
      case 'Strong':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirmation do not match.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      final emailToVerify = widget.userEmail ?? currentUser?.email;

      // 1. Verify current password if user email is known
      if (emailToVerify != null && emailToVerify.isNotEmpty) {
        try {
          await client.auth.signInWithPassword(
            email: emailToVerify,
            password: currentPass,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Current password is incorrect. Please check and try again.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // 2. Update to new password
      await client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      // 3. Update local Offline Auth Vault with new password
      if (emailToVerify != null) {
        final currentUser = client.auth.currentUser;
        if (currentUser != null) {
          final userAccount = UserAccount(
            id: currentUser.id,
            email: emailToVerify,
            firstName: 'User',
            surname: '',
            role: UserRole.cashier,
          );
          await OfflineAuthVault.saveUserCredentialsOnline(userAccount, emailToVerify, newPass);
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Password updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update password: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
      title: Row(
        children: [
          Icon(Icons.lock_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify your current password and choose a strong new password.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: AppSpacing.m),

                // Current Password
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter current password';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.m),

                // New Password
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter new password';
                    if (v.trim().length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),

                // Password Strength Bar
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
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Confirm your new password';
                    if (v.trim() != _newPasswordController.text.trim()) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleChangePassword,
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('Update Password'),
        ),
      ],
    );
  }
}
