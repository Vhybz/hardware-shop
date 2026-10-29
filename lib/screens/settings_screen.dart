import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../core/constants.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_sidebar.dart';
import '../services/menu_service.dart';
import '../services/user_provider.dart';
import '../services/theme_provider.dart';
import '../services/offline_sync_service.dart';
import '../services/app_settings_provider.dart';
import '../services/auth_provider.dart';
import '../widgets/role_pop_scope.dart';
import '../widgets/change_password_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<Color> themeColors = [
    Color(0xFFF59E0B), // Hardware Amber Yellow (Featured)
    Color(0xFFFFFFFF), // Monochrome Pure White & Black
    Color(0xFF18181B), // Industrial Onyx Black
    Color(0xFFEAB308), // Construction Gold Yellow
    Color(0xFFEA580C), // Industrial Tool Orange
    Color(0xFF10B981), // Safety Green
    Color(0xFF0284C7), // Vibrant Sky Blue
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final themeState = ref.watch(themeProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/settings';

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'Settings & Preferences'),
        drawer: isDesktop ? null : Drawer(
          child: AppSidebar(
            userId: user.id,
            userName: user.name,
            userRole: user.activePrimaryRole.name.toUpperCase(),
            currentRoute: currentRoute,
            items: MenuService.getMenuItemsForUser(user),
            onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
          ),
        ),
        body: Row(
          children: [
            if (isDesktop)
              AppSidebar(
                userId: user.id,
                userName: user.name,
                userRole: user.activePrimaryRole.name.toUpperCase(),
                currentRoute: currentRoute,
                items: MenuService.getMenuItemsForUser(user),
                onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Personalization', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('Customize your workstation appearance and system behavior', 
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: AppSpacing.xl),
                        
                        _buildSection(
                          context,
                          'Display Mode',
                          Icons.palette_outlined,
                          [
                            _buildThemeModeSelector(ref, themeState, theme),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),

                        _buildSection(
                          context,
                          'Interface Color Accent',
                          Icons.color_lens_outlined,
                          [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.m),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Select a vibrant accent color for your workstation UI:', 
                                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: themeColors.map((color) => _buildColorDot(ref, color, themeState.primaryColor)).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),

                        _buildSection(
                          context,
                          'Notifications & Alerts',
                          Icons.notifications_active_outlined,
                          [
                            SwitchListTile(
                              secondary: const Icon(Icons.storefront_outlined),
                              title: const Text('Enable Wholesale & B2B Mode'),
                              subtitle: const Text('Turn on wholesale prices, price brackets, customer tiers, and cashier wholesale mode'),
                              value: appSettings.enableWholesale,
                              activeThumbColor: theme.colorScheme.primary,
                              onChanged: (v) => ref.read(appSettingsProvider.notifier).toggleWholesale(v),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.vibration),
                              title: const Text('Push Notifications'),
                              subtitle: const Text('Receive real-time alerts for stock transfers and system updates'),
                              value: appSettings.pushNotificationsEnabled, 
                              activeThumbColor: theme.colorScheme.primary,
                              onChanged: (v) => ref.read(appSettingsProvider.notifier).togglePushNotifications(v),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.volume_up_outlined),
                              title: const Text('System Sounds'),
                              subtitle: const Text('Play beeps during barcode/QR scanning'),
                              value: appSettings.systemSoundsEnabled,
                              activeThumbColor: theme.colorScheme.primary,
                              onChanged: (v) => ref.read(appSettingsProvider.notifier).toggleSystemSounds(v),
                            ),
                            const Divider(height: 1),
                            SwitchListTile(
                              secondary: const Icon(Icons.touch_app_outlined),
                              title: const Text('Haptic Feedback'),
                              subtitle: const Text('Vibrate on successful scans'),
                              value: appSettings.hapticFeedbackEnabled,
                              activeThumbColor: theme.colorScheme.primary,
                              onChanged: (v) => ref.read(appSettingsProvider.notifier).toggleHapticFeedback(v),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),

                        _buildSection(
                          context,
                          'Security',
                          Icons.security_outlined,
                          [
                            SwitchListTile(
                              secondary: const Icon(Icons.pin_rounded),
                              title: const Text('Use 4-Digit Security PIN', maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(user.isPasscodeEnabled 
                                ? 'PIN protection active • Screen lock and fast handover enabled' 
                                : 'PIN protection disabled',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              value: user.isPasscodeEnabled,
                              activeThumbColor: theme.colorScheme.primary,
                              onChanged: (bool enabled) async {
                                if (enabled) {
                                  if (user.passcode == null || user.passcode!.isEmpty) {
                                    _showPinSetupDialog(context, ref, user);
                                  } else {
                                    await ref.read(userProvider.notifier).setPasscodeEnabled(user.id, true);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('4-Digit Security PIN enabled.'), backgroundColor: Colors.green),
                                      );
                                    }
                                  }
                                } else {
                                  await ref.read(userProvider.notifier).setPasscodeEnabled(user.id, false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('4-Digit Security PIN disabled.'), backgroundColor: Colors.orange),
                                    );
                                  }
                                }
                              },
                            ),
                            if (user.isPasscodeEnabled) ...[
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.pin_outlined),
                                title: const Text('Configure Security PIN'),
                                subtitle: Text(user.passcode != null && user.passcode!.isNotEmpty
                                    ? 'PIN is configured (• • • •)' 
                                    : 'No PIN set (Click to set)'),
                                trailing: TextButton(
                                  onPressed: () => _showPinSetupDialog(context, ref, user),
                                  child: Text(
                                    user.passcode != null && user.passcode!.isNotEmpty ? 'CHANGE PIN' : 'SET PIN',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.lock_clock_outlined, color: Colors.orange),
                                title: const Text('Lock Account Now', style: TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: const Text('Instantly lock your screen with your 4-digit PIN'),
                                trailing: ElevatedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    ref.read(passcodeUnlockedProvider.notifier).state = false;
                                  },
                                  icon: const Icon(Icons.lock_rounded, size: 16),
                                  label: const Text('LOCK NOW'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryMaroon,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.lock_outline),
                              title: const Text('Update Password'),
                              subtitle: const Text('Keep your account secure with regular updates'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showChangePasswordDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),

                        _buildSection(
                          context,
                          'Storage & Data',
                          Icons.storage_rounded,
                          [
                            ListTile(
                              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                              title: const Text('Clear Local Cache', style: TextStyle(color: Colors.red)),
                              subtitle: const Text('Frees up space and forces fresh data sync'),
                              onTap: () => _showClearCacheDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),

                        _buildSection(
                          context,
                          'Danger Zone & Account Removal',
                          Icons.warning_amber_rounded,
                          [
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.m),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Delete Account Permanently',
                                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Permanently remove your account and all personal profile data.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showDeleteAccountDialog(context, ref, user),
                                      icon: const Icon(Icons.delete_forever_rounded, size: 16),
                                      label: const Text('DELETE ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        Center(
                          child: Text('Version 1.0.0+1 • Hardware & Building Materials POS Enterprise', 
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                        ),
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 60),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Cache?'),
        content: const Text('This will delete all offline data stored on this device. Pending sync items may be lost. You will need to re-download fresh inventory data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              await OfflineSyncService.clearAllCache();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared. Refreshing data...'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CLEAR DATA'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref, UserAccount user) {
    final confirmController = TextEditingController();
    bool isDeleting = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete account "${user.name}" (${user.email})?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your account access will be revoked and you will be signed out immediately. Your historical sales and audit records will remain safely preserved in the database.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Type DELETE below to confirm account removal.',
                          style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Type DELETE to confirm',
                    border: OutlineInputBorder(),
                    hintText: 'DELETE',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton.icon(
              onPressed: (confirmController.text.trim() != 'DELETE' || isDeleting)
                  ? null
                  : () async {
                      setDialogState(() {
                        isDeleting = true;
                        errorMessage = null;
                      });

                      try {
                        final navigator = Navigator.of(context, rootNavigator: true);
                        final messenger = ScaffoldMessenger.of(context);

                        // 1. Delete user from system/database
                        await ref.read(userProvider.notifier).deleteUser(user.id);

                        // 2. Perform global sign out
                        await GlobalLogout.perform(ref);

                        if (context.mounted) {
                          navigator.pop(); // Close dialog
                          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Account permanently deleted.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isDeleting = false;
                          errorMessage = 'Failed to delete account: $e';
                        });
                      }
                    },
              icon: isDeleting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text(isDeleting ? 'DELETING...' : 'DELETE MY ACCOUNT NOW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, List<Widget> children) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.m),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildThemeModeSelector(WidgetRef ref, ThemeState state, ThemeData theme) {
    final bool isLightPrimary = theme.colorScheme.primary.computeLuminance() > 0.28 || theme.colorScheme.primary.toARGB32() == 0xFFF59E0B;
    final Color selectedFg = isLightPrimary ? const Color(0xFF18181B) : Colors.white;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined), label: Text('Auto')),
        ],
        selected: {state.mode},
        onSelectionChanged: (newSelection) {
          ref.read(themeProvider.notifier).setThemeMode(newSelection.first);
        },
        style: ButtonStyle(
          side: WidgetStateProperty.all(BorderSide(color: theme.dividerColor)),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return theme.colorScheme.primary;
            }
            return theme.cardTheme.color;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) {
              return selectedFg;
            }
            return theme.colorScheme.onSurface;
          }),
        ),
      ),
    );
  }

  String _getColorName(Color color) {
    switch (color.toARGB32()) {
      case 0xFFF59E0B: return 'Hardware Amber Yellow';
      case 0xFFFFFFFF: return 'Monochrome Pure White';
      case 0xFF18181B:
      case 0xFF121212: return 'Industrial Onyx Black';
      case 0xFFEAB308: return 'Construction Gold';
      case 0xFFEA580C: return 'Tool Safety Orange';
      case 0xFF10B981:
      case 0xFF1B5E20: return 'Safety Stock Green';
      case 0xFF0284C7:
      case 0xFF0D47A1: return 'Sky Blue';
      case 0xFF880E4F: return 'Deep Rose Pink';
      default: return 'Custom Accent';
    }
  }

  Widget _buildColorDot(WidgetRef ref, Color color, Color selectedColor) {
    final isSelected = color.toARGB32() == selectedColor.toARGB32();
    final String name = _getColorName(color);
    final bool isWhiteDot = color.toARGB32() == 0xFFFFFFFF;

    return Tooltip(
      message: name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => ref.read(themeProvider.notifier).setPrimaryColor(color),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? (isWhiteDot ? const Color(0xFF18181B) : Colors.amberAccent) 
                      : (isWhiteDot ? const Color(0xFF94A3B8) : Colors.grey.withValues(alpha: 0.4)), 
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: isSelected ? [BoxShadow(color: (isWhiteDot ? Colors.black26 : color.withValues(alpha: 0.6)), blurRadius: 10, spreadRadius: 2)] : null,
              ),
              child: isSelected ? Icon(Icons.check_rounded, color: isWhiteDot ? const Color(0xFF18181B) : Colors.white, size: 22) : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? (color.computeLuminance() > 0.4 ? Colors.black87 : color) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    ChangePasswordDialog.show(context);
  }

  void _showPinSetupDialog(BuildContext context, WidgetRef ref, UserAccount user) {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: Row(
            children: [
              const Icon(Icons.pin_rounded, color: AppColors.primaryMaroon),
              const SizedBox(width: 10),
              Text(
                user.passcode != null && user.passcode!.isNotEmpty ? 'Change Security PIN' : 'Create Security PIN',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a 4-digit security PIN to quickly lock and unlock your account on this device.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pinController,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: 'New 4-Digit PIN',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter a 4-digit PIN';
                    if (v.length != 4) return 'PIN must be exactly 4 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: confirmPinController,
                  obscureText: obscure,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Confirm 4-Digit PIN',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v != pinController.text) return 'PINs do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSaving = true);
                        try {
                          await ref.read(userProvider.notifier).updatePasscode(
                            user.id,
                            pinController.text.trim(),
                            lockAfterUpdate: false,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('4-Digit Security PIN configured and enabled!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving PIN: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryMaroon,
                foregroundColor: Colors.white,
              ),
              child: Text(isSaving ? 'SAVING...' : 'SAVE PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
