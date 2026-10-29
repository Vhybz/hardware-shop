import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/user_provider.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/staff_switch_sheet.dart';
import '../services/menu_service.dart';
import '../services/auth_provider.dart';
import '../widgets/role_pop_scope.dart';
import '../services/branch_provider.dart';
import '../widgets/change_password_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/profile';
    final menuItems = ref.watch(menuItemsProvider);

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'My Profile'),
        drawer: isDesktop ? null : Drawer(
          child: AppSidebar(
            userId: user.id,
            userName: user.name,
            userRole: user.activePrimaryRole.name.toUpperCase(),
            currentRoute: currentRoute,
            items: menuItems,
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
                items: menuItems,
                onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
              ),
            const Expanded(
              child: ProfileView(),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  late TextEditingController _firstNameController;
  late TextEditingController _surnameController;
  late TextEditingController _phoneController;
  
  String? _selectedGender;
  DateTime? _selectedDob;
  bool _isEditing = false;
  bool _isUploading = false;
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _surnameController = TextEditingController(text: user?.surname ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _selectedGender = user?.gender;
    _selectedDob = user?.dob;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: Text('No user logged in.'));

    final theme = Theme.of(context);
    final currentBranch = ref.watch(currentBranchProvider);
    final branchDisplay = currentBranch != null ? '${currentBranch.name} (${currentBranch.location})' : (user.branchCode ?? 'Global Admin');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernHeader(theme, user),
              const SizedBox(height: AppSpacing.xl),
              _buildProfileContent(theme, user, branchDisplay),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme, UserAccount user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          _buildAvatarWithPicker(user),
          const SizedBox(height: 20),
          Text(
            user.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              user.role.name.toUpperCase(),
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithPicker(UserAccount user) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _isUploading ? null : _updatePhoto,
      borderRadius: BorderRadius.circular(60),
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: _isUploading ? Colors.orange : theme.colorScheme.primary, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipOval(
              child: _buildAvatarImage(user.photoUrl, theme),
            ),
          ),
          if (!_isUploading)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.cardTheme.color ?? Colors.transparent, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String? photoUrl, ThemeData theme) {
    if (_localImageBytes != null) {
      return Image.memory(_localImageBytes!, fit: BoxFit.cover);
    }
    if (_isUploading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        try {
          final bytes = base64Decode(photoUrl.split(',').last);
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      }
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) => Icon(Icons.person_rounded, size: 60, color: theme.colorScheme.primary),
      );
    }
    return Icon(Icons.person_rounded, size: 60, color: theme.colorScheme.primary);
  }

  Widget _buildProfileContent(ThemeData theme, UserAccount user, String branchDisplay) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Information', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    Text(
                      'System & Security Profile',
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          if (!_isEditing) ...[
            _modernInfoRow(Icons.phone_rounded, 'Phone Number', user.phone ?? 'Not provided'),
            _modernInfoRow(Icons.wc_rounded, 'Gender', user.gender ?? 'Not provided'),
            _modernInfoRow(Icons.cake_rounded, 'Date of Birth', user.dob != null ? DateFormat('MMMM d, yyyy').format(user.dob!) : 'Not provided'),
            _modernInfoRow(Icons.calendar_today_rounded, 'Joined System', DateFormat('MMMM d, yyyy').format(user.createdAt)),
            _modernInfoRow(Icons.location_city_rounded, 'Current Branch', branchDisplay),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.pin_rounded, color: theme.colorScheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Use 4-Digit Security PIN',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.isPasscodeEnabled
                                    ? 'PIN protection active • Screen lock and fast handover enabled'
                                    : 'PIN protection disabled',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: user.isPasscodeEnabled,
                          activeThumbColor: theme.colorScheme.primary,
                          onChanged: (bool enabled) async {
                            if (enabled) {
                              if (user.passcode == null || user.passcode!.isEmpty) {
                                _showPinSetupDialog(user);
                              } else {
                                await ref.read(userProvider.notifier).setPasscodeEnabled(user.id, true);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('4-Digit Security PIN enabled.'), backgroundColor: Colors.green),
                                );
                              }
                            } else {
                              await ref.read(userProvider.notifier).setPasscodeEnabled(user.id, false);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('4-Digit Security PIN disabled.'), backgroundColor: Colors.orange),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (user.isPasscodeEnabled) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Quick Switch & Lock PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  user.passcode != null && user.passcode!.isNotEmpty
                                      ? 'PIN is configured (• • • •)'
                                      : 'No PIN set (Required for lock and quick switch)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: user.passcode != null && user.passcode!.isNotEmpty ? Colors.green : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showPinSetupDialog(user),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: Text(user.passcode != null && user.passcode!.isNotEmpty ? 'Change PIN' : 'Set PIN'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_clock_outlined, color: Colors.orange),
                      title: const Text('Lock Account Now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Instantly lock your screen with your 4-digit PIN', style: TextStyle(fontSize: 11)),
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
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.key_rounded, color: theme.colorScheme.primary),
                      title: const Text('Change Account Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: const Text('Update your system login password', style: TextStyle(fontSize: 11)),
                      trailing: ElevatedButton.icon(
                        onPressed: () => ChangePasswordDialog.show(context, userEmail: user.email),
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        label: const Text('CHANGE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => StaffSwitchSheet.show(context),
                icon: const Icon(Icons.switch_account_rounded),
                label: const Text('Switch Account Without Logging Off', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMaroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  GlobalLogout.perform(ref).then((_) {
                    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                    messenger.showSnackBar(const SnackBar(content: Text('Signed out successfully.')));
                  });
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text('Sign Out Securely', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton.icon(
                onPressed: () => _showDeleteAccountDialog(user),
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                label: const Text('Delete Account Permanently', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ] else ...[
            _buildEditField(_firstNameController, 'First Name', Icons.person_outline),
            const SizedBox(height: 16),
            _buildEditField(_surnameController, 'Surname', Icons.person_outline),
            const SizedBox(height: 16),
            _buildEditField(_phoneController, 'Phone Number', Icons.phone_android_rounded),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), prefixIcon: Icon(Icons.wc_rounded)),
              items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDob ?? DateTime(2000),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDob = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDob == null ? 'Select Date of Birth' : DateFormat('MMMM d, yyyy').format(_selectedDob!),
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Update Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modernInfoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label, 
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _updatePhoto() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
              title: const Text('Take Photo with Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.purple),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        setState(() {
          _localImageBytes = bytes;
          _isUploading = true;
        });

        final url = await ref.read(userProvider.notifier).updatePhoto(user.id, bytes);

        if (!mounted) return;
        setState(() {
          _isUploading = false;
          if (url != null) _localImageBytes = null;
        });

        messenger.showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _saveProfile() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final messenger = ScaffoldMessenger.of(context);
      ref.read(userProvider.notifier).updateProfile(
        user.id,
        firstName: _firstNameController.text.trim(),
        surname: _surnameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _selectedGender,
        dob: _selectedDob,
      ).then((_) {
        if (!mounted) return;
        setState(() => _isEditing = false);
        messenger.showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
      });
    }
  }

  void _showPinSetupDialog(UserAccount user) {
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
              Text(user.passcode != null ? 'Change Switch PIN' : 'Create Switch PIN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a 4-digit security PIN to quickly switch into your account on this device without typing your full password every time.',
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
                                content: Text('Quick Switch PIN configured successfully!'),
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

  void _showDeleteAccountDialog(UserAccount user) {
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
}
