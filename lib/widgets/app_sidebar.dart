import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../services/user_provider.dart';
import '../services/theme_provider.dart';
import '../services/customer_provider.dart';
import '../services/sale_provider.dart';
import '../services/product_service.dart';
import '../services/expense_provider.dart';
import '../services/branch_provider.dart';
import '../services/transfer_provider.dart';
import '../services/auth_provider.dart';
import '../services/sync_provider.dart';
import '../services/offline_sync_service.dart';
import 'account_switch_dialog.dart';
import 'app_avatar_image.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final String route;
  final bool isCatchy;
  final int? badgeCount;
  final String category;
  final Color? iconColor;

  SidebarItem({
    required this.icon, 
    required this.label, 
    required this.route,
    this.isCatchy = false,
    this.badgeCount,
    this.category = 'General',
    this.iconColor,
  });
}

class AppSidebar extends ConsumerStatefulWidget {
  final List<SidebarItem> items;
  final String currentRoute;
  final String userName;
  final String userRole;
  final String userId;
  final Function(String route)? onTap;

  const AppSidebar({
    super.key,
    required this.items,
    required this.currentRoute,
    required this.userName,
    required this.userRole,
    required this.userId,
    this.onTap,
  });

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _collapsedCategories = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_collapsedCategories.contains(category)) {
        _collapsedCategories.remove(category);
      } else {
        _collapsedCategories.add(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final bool isDark = themeState.mode == ThemeMode.dark;
    final user = ref.watch(currentUserProvider);
    
    final Color roleColor = isDark 
        ? (theme.appBarTheme.backgroundColor ?? const Color(0xFF1E1E1E))
        : theme.colorScheme.primary;

    final bool isWhitePrimary = roleColor.toARGB32() == 0xFFFFFFFF;

    final List<Color> bgColors = isDark 
        ? [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)]
        : (isWhitePrimary 
            ? [Colors.white, const Color(0xFFF1F5F9)]
            : [roleColor, roleColor.withValues(alpha: 0.85)]);

    final bool isLightBg = !isDark && (roleColor.computeLuminance() > 0.28 || isWhitePrimary || roleColor.toARGB32() == 0xFFF59E0B || roleColor.toARGB32() == 0xFFEAB308);
    final Color textColor = isLightBg ? const Color(0xFF18181B) : Colors.white;
    final Color subtextColor = isLightBg ? const Color(0xFF18181B) : Colors.white.withValues(alpha: 0.95);
    final Color mutedTextColor = isLightBg ? const Color(0xFF27272A) : Colors.white.withValues(alpha: 0.75);
    final Color dividerColor = isLightBg ? Colors.black.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.15);
    final Color inputFillColor = isLightBg ? Colors.black.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.25);
    final Color cardBgColor = isLightBg ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.08);

    final filteredItems = widget.items
        .where((item) => item.label.toLowerCase().contains(_searchQuery.toLowerCase()) || item.category.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    final Map<String, List<SidebarItem>> groupedItems = {};
    for (var item in filteredItems) {
      groupedItems.putIfAbsent(item.category, () => []).add(item);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.light,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Container(
        width: 260,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bgColors,
          ),
          border: isDark ? const Border(right: BorderSide(color: Color(0xFF2C2C2C))) : null,
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(4, 0),
              ),
          ],
        ),
        child: Column(
          children: [
            // Ensure logo doesn't collide with status bar on mobile
            SafeArea(
              bottom: false,
              child: _buildLogo(textColor, subtextColor, dividerColor),
            ),
            _buildSearchBar(textColor, mutedTextColor, inputFillColor, dividerColor),
            Divider(height: 1, color: dividerColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchQuery.isNotEmpty) ...[
                      // Search Mode: Flat List
                      ...filteredItems.map((item) {
                        final isSelected = widget.currentRoute == item.route;
                        return _buildMenuItem(context, ref, item, isSelected, textColor, subtextColor, isLightBg);
                      }),
                      if (filteredItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.l),
                          child: Center(
                            child: Text(
                              'No menu items found',
                              style: TextStyle(color: mutedTextColor, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                    ] else ...[
                      // Categorized Mode: Collapsible Section Headers
                      ...groupedItems.entries.map((entry) {
                        final category = entry.key;
                        final items = entry.value;
                        final isCollapsed = _collapsedCategories.contains(category);
                        final hasActiveRoute = items.any((i) => i.route == widget.currentRoute);

                        // Don't collapse section if current active route is inside it
                        final effectiveCollapsed = isCollapsed && !hasActiveRoute;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (category.isNotEmpty && category != 'General')
                              _buildSectionHeader(category, items.length, effectiveCollapsed, hasActiveRoute, isLightBg, mutedTextColor, subtextColor),
                            if (!effectiveCollapsed)
                              ...items.map((item) {
                                final isSelected = widget.currentRoute == item.route;
                                return _buildMenuItem(context, ref, item, isSelected, textColor, subtextColor, isLightBg);
                              }),
                            const SizedBox(height: 6),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            _buildUserSection(context, ref, isDark, cardBgColor, textColor, subtextColor, mutedTextColor),
            _buildBottomActions(context, ref, isDark, cardBgColor, subtextColor, isLightBg),
            // Ensure content doesn't get hidden under system navigation bar
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isCollapsed, bool hasActiveRoute, bool isLightBg, Color mutedTextColor, Color subtextColor) {
    final Color highlightColor = hasActiveRoute 
        ? (isLightBg ? const Color(0xFF18181B) : const Color(0xFFFDE047)) 
        : (isLightBg ? const Color(0xFF27272A) : Colors.white.withValues(alpha: 0.80));

    return InkWell(
      onTap: () => _toggleCategory(title),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: highlightColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isLightBg ? Colors.black : Colors.white).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: hasActiveRoute ? highlightColor : (isLightBg ? Colors.black87 : Colors.white), 
                  fontSize: 9.5, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
              color: highlightColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(Color textColor, Color subtextColor, Color dividerColor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.s),
              border: Border.all(color: dividerColor),
              image: const DecorationImage(
                image: AssetImage('assets/logo/logo.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADOM MMOROSO ENT.',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Hardware & Materials POS System',
                  style: TextStyle(color: subtextColor, fontSize: 10, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color textColor, Color mutedTextColor, Color inputFillColor, Color dividerColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          style: TextStyle(color: textColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search menu...',
            hintStyle: TextStyle(color: mutedTextColor, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: mutedTextColor, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: mutedTextColor, size: 16),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: inputFillColor,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.s),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.s),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.s),
              borderSide: BorderSide(color: dividerColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, WidgetRef ref, SidebarItem item, bool isSelected, Color textColor, Color subtextColor, bool isLightBg) {
    final bool showCatchy = item.isCatchy && !isSelected;
    final Color activeAccent = isLightBg ? const Color(0xFF18181B) : Colors.amberAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
          
          if (item.isCatchy) {
            ref.read(userProvider.notifier).markPermissionAsSeen(widget.userId, item.route);
          }
          
          if (widget.onTap != null) {
            widget.onTap!(item.route);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 8),
          decoration: BoxDecoration(
            border: isSelected 
              ? Border(left: BorderSide(color: activeAccent, width: 4.5)) 
              : null,
            color: isSelected 
              ? (isLightBg ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.16))
              : (showCatchy ? Colors.orangeAccent.withValues(alpha: 0.15) : Colors.transparent),
            borderRadius: isSelected ? const BorderRadius.horizontal(right: Radius.circular(10)) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? activeAccent.withValues(alpha: isLightBg ? 0.35 : 0.25)
                      : (isLightBg ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.10)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    item.icon, 
                    color: isSelected 
                      ? activeAccent 
                      : (isLightBg ? const Color(0xFF374151) : Colors.white.withValues(alpha: 0.90)), 
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected 
                      ? (isLightBg ? textColor : Colors.white) 
                      : (showCatchy ? (isLightBg ? Colors.deepOrange : Colors.orangeAccent) : subtextColor),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13.5,
                    letterSpacing: -0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showCatchy || (item.badgeCount != null && item.badgeCount! > 0))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.badgeCount != null ? Colors.red : Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.badgeCount != null ? '${item.badgeCount}' : 'NEW',
                    style: TextStyle(
                      color: item.badgeCount != null ? Colors.white : Colors.black, 
                      fontSize: 8.5, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context, WidgetRef ref, bool isDark, Color cardBgColor, Color textColor, Color subtextColor, Color mutedTextColor) {
    final user = ref.watch(currentUserProvider);
    final displayPhoto = user?.photoUrl;

    return InkWell(
      onTap: () => _showStaffSwitchMenu(context, ref),
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.m),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white12 : Colors.white24,
              ),
              child: ClipOval(
                child: AppAvatarImage(
                  photoUrl: displayPhoto,
                  size: 36,
                  nameHint: user?.firstName ?? widget.userName,
                  iconColor: textColor,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? widget.userName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(user?.activePrimaryRole.toString().split('.').last.toUpperCase() ?? widget.userRole, style: TextStyle(color: subtextColor, fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.unfold_more_rounded, color: mutedTextColor, size: 18),
          ],
        ),
      ),
    );
  }

  void _showStaffSwitchMenu(BuildContext context, WidgetRef ref) {
    final allUsers = ref.read(userProvider);
    final currentUser = ref.read(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.switch_account_rounded, color: AppColors.primaryMaroon),
                  const SizedBox(width: 12),
                  const Text('Switch Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allUsers.length,
                padding: const EdgeInsets.only(bottom: 24),
                itemBuilder: (context, index) {
                  final staff = allUsers[index];
                  final isCurrent = staff.id == currentUser?.id;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 4),
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? AppColors.primaryMaroon : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: AppAvatarImage(
                          photoUrl: staff.photoUrl,
                          size: 36,
                          nameHint: staff.firstName,
                        ),
                      ),
                    ),
                    title: Text(staff.name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(staff.role.toString().split('.').last.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 0.5)),
                    trailing: isCurrent 
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: isCurrent ? null : () async {
                      final navigator = Navigator.of(context);
                      navigator.pop(); // Close bottom sheet
                      final success = await AccountSwitchDialog.show(context, staff);
                      if (success == true && context.mounted) {
                        // Invalidate current route and force rebuild of the shell
                        navigator.pushReplacementNamed('/'); 
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, WidgetRef ref, bool isDark, Color cardBgColor, Color subtextColor, bool isLightBg) {
    final isForcedOffline = ref.watch(forcedOfflineProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              final newMode = !isForcedOffline;
              ref.read(forcedOfflineProvider.notifier).state = newMode;
              OfflineSyncService.isForcedOffline = newMode;

              if (newMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔌 Switched to Manual Offline Mode. All sales will save locally.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                ref.read(syncProvider.notifier).syncAll();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🌐 Reconnected to Cloud Backend. Synchronizing data...'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: Icon(
              isForcedOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              color: isForcedOffline 
                  ? (isLightBg ? const Color(0xFFC2410C) : Colors.orangeAccent) 
                  : (isLightBg ? const Color(0xFF15803D) : Colors.lightGreenAccent),
              size: 20,
            ),
            tooltip: isForcedOffline ? 'Manual Offline Active • Tap to Reconnect' : 'Online Mode Active • Tap to Force Offline',
            style: IconButton.styleFrom(
              backgroundColor: cardBgColor,
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _handleRefresh(context, ref),
            icon: Icon(Icons.refresh, color: subtextColor, size: 20),
            tooltip: 'Refresh System Data',
            style: IconButton.styleFrom(
              backgroundColor: cardBgColor,
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextButton.icon(
              onPressed: () async {
                await GlobalLogout.perform(ref);
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              icon: Icon(Icons.logout, color: subtextColor, size: 18),
              label: Text(
                'Log Out', 
                style: TextStyle(color: subtextColor, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft, 
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                backgroundColor: cardBgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRefresh(BuildContext context, WidgetRef ref) async {
    try {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 16),
              Text('Refreshing system data...'),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: theme.colorScheme.primary,
        ),
      );

      ref.invalidate(currentUserProvider);
      ref.invalidate(customerProvider);
      ref.invalidate(saleHistoryProvider);
      ref.invalidate(productsFutureProvider);
      ref.invalidate(expenseProvider);
      ref.invalidate(branchesProvider);
      ref.invalidate(transferProvider);
      
      debugPrint('System Refresh triggered');
    } catch (e) {
      debugPrint('Refresh Error: $e');
    }
  }
}
