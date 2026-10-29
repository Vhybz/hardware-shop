import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants.dart';
import '../../widgets/main_app_bar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/app_sidebar.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../models/user_model.dart';
import '../../models/branch_model.dart';
import '../../services/theme_provider.dart';
import '../../services/branch_provider.dart';
import '../../services/product_seeder.dart';
import '../../services/app_settings_provider.dart';
import '../../widgets/role_pop_scope.dart';

class SystemSettingsScreen extends ConsumerStatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  ConsumerState<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  bool _isSeeding = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/admin/settings';
    final currentBranch = ref.watch(currentBranchProvider);

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'System Settings', showMenuButton: true),
        drawer: isDesktop
            ? null
            : Drawer(
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
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroHeader(theme),
                        const SizedBox(height: AppSpacing.xl),
                        _buildSection(
                          context,
                          'Branding & Theme',
                          Icons.palette_rounded,
                          [
                            _buildThemeColorSelector(context),
                            _buildThemeModeToggle(context),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildSection(
                          context,
                          'Personal Profile',
                          Icons.person_outline_rounded,
                          [
                            _buildProfileSection(context, user, theme),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildSection(
                          context,
                          'Shop Identification',
                          Icons.business_rounded,
                          [
                            _settingTile(context, Icons.store_rounded, 'Branch Name', currentBranch?.name ?? 'ADOM MMOROSO ENT.'),
                            _settingTile(context, Icons.location_on_rounded, 'Branch Location', currentBranch?.location ?? 'Zongo One Way, Sunyani, Ghana'),
                            _buildGpsCoordinatesTile(context),
                            _settingTile(context, Icons.phone_android_rounded, 'Store Contact', '0542 181 580 / 0246 046 310'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildBranchNetworkSection(context, ref),
                        const SizedBox(height: AppSpacing.xl),
                        _buildSection(
                          context,
                          'Configuration & Defaults',
                          Icons.settings_suggest_rounded,
                          [
                            _settingTile(context, Icons.currency_exchange_rounded, 'System Currency', 'Ghana Cedi (GHS)'),
                            _settingTile(context, Icons.percent_rounded, 'VAT/Tax Rate', '15.0%'),
                            _settingTile(context, Icons.auto_awesome_rounded, 'Brand Slogan', 'Building Materials & Hardware Enterprise'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildSection(
                          context,
                          'Maintenance & Data',
                          Icons.storage_rounded,
                          [
                            _buildSeedingTile(context, theme),
                            _settingTile(context, Icons.cloud_done_rounded, 'Cloud Sync Status', 'Live & Secure', color: Colors.green),
                            _settingTile(context, Icons.history_edu_rounded, 'System Logs', 'View administrative audit trail'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildFooter(theme),
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

  Widget _buildHeroHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.settings_applications_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          const Text(
            'System Control Center',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            'Configure global parameters, branding, and theme for Adom Mmoroso ENT.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, List<Widget> children) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _settingTile(BuildContext context, IconData icon, String label, String value, {Color? color, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? theme.colorScheme.primary).withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? theme.colorScheme.primary, size: 22),
      ),
      title: Text(label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
      subtitle: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontSize: 14)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.dividerColor),
      onTap: onTap,
    );
  }

  Widget _buildSeedingTile(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.inventory_2_rounded, color: theme.colorScheme.secondary, size: 22),
      ),
      title: const Text('Initial Product Catalog', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: const Text('Populate database with default product categories', style: TextStyle(fontSize: 12)),
      trailing: _isSeeding 
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('RUN SEEDER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
      onTap: _isSeeding ? null : () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
            title: const Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: Colors.blue),
                SizedBox(width: 10),
                Text('Product Catalog & Stock Defaults'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how you want to load default categories or reset product quantities:',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 12),
                Text('• Seed Catalog: Populates default categories/products with 0.0 Pcs initial stock.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                SizedBox(height: 6),
                Text('• Reset All to 0 Pcs: Sets ALL existing products store & warehouse stock to 0.0 Pcs.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isSeeding = true);
                  try {
                    await ref.read(productSeederProvider).seedProducts();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Catalog seeded with 0.0 Pcs stock defaults!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSeeding = false);
                  }
                },
                child: const Text('SEED CATALOG (0 PCS)'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isSeeding = true);
                  try {
                    await ref.read(productSeederProvider).resetAllStockToZero();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ All product quantities reset to 0.0 Pcs successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error resetting stock: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSeeding = false);
                  }
                },
                child: const Text('RESET ALL TO 0 PCS'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isSeeding = true);
                  try {
                    await ref.read(productSeederProvider).purgeLegacyCosmeticsData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🧹 Legacy cosmetics cache and data purged completely!'), backgroundColor: Colors.orange),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Purge note: $e'), backgroundColor: Colors.orange),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSeeding = false);
                  }
                },
                label: const Text('PURGE LEGACY DATA & CACHE'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeColorSelector(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    
    final List<Color> themeColors = [
      AppColors.primaryMaroon, // Hardware Amber Yellow
      const Color(0xFFFFFFFF), // Monochrome Pure White & Black
      AppColors.hardwareBlack, // Onyx Black
      const Color(0xFFEAB308), // Construction Gold Yellow
      const Color(0xFFEA580C), // Industrial Tool Orange
      AppColors.primaryGreen,  // Safety Green
      const Color(0xFF0284C7), // Vibrant Sky Blue
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.color_lens_rounded, color: theme.colorScheme.primary, size: 22),
      ),
      title: const Text('Primary Theme Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: themeColors.map((color) {
            final isSelected = themeState.primaryColor == color;
            return InkWell(
              onTap: () => ref.read(themeProvider.notifier).setPrimaryColor(color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected 
                    ? Border.all(color: theme.colorScheme.onSurface, width: 2)
                    : Border.all(color: Colors.white24, width: 1),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)
                  ],
                ),
                child: isSelected 
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildThemeModeToggle(BuildContext context) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          themeState.mode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, 
          color: theme.colorScheme.primary, 
          size: 22
        ),
      ),
      title: const Text('Display Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
            ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
            ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_suggest_outlined), label: Text('Auto')),
          ],
          selected: {themeState.mode},
          onSelectionChanged: (newSelection) {
            ref.read(themeProvider.notifier).setThemeMode(newSelection.first);
          },
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, UserAccount user, ThemeData theme) {
    return ListTile(
      contentPadding: const EdgeInsets.all(AppSpacing.l),
      leading: CircleAvatar(
        radius: 30,
        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null ? const Icon(Icons.person, size: 30) : null,
      ),
      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(user.role.name.toUpperCase(), 
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          ),
        ],
      ),
      trailing: OutlinedButton(
        onPressed: () => Navigator.pushNamed(context, '/profile'),
        child: const Text('EDIT'),
      ),
    );
  }

  Widget _buildGpsCoordinatesTile(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return _settingTile(
      context,
      Icons.my_location_rounded,
      'Store GPS Coordinates & Radius',
      '${settings.storeLat.toStringAsFixed(5)}, ${settings.storeLon.toStringAsFixed(5)} (${settings.storeRadiusMeters.toInt()}m radius)',
      color: Colors.blue,
      onTap: () => _showGpsCoordinatesDialog(context, settings),
    );
  }

  void _showGpsCoordinatesDialog(BuildContext context, AppSettings settings) {
    final latController = TextEditingController(text: settings.storeLat.toString());
    final lonController = TextEditingController(text: settings.storeLon.toString());
    final radiusController = TextEditingController(text: settings.storeRadiusMeters.toInt().toString());
    bool isFetchingGps = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
            title: const Row(
              children: [
                Icon(Icons.my_location_rounded, color: Colors.blue),
                SizedBox(width: 10),
                Text('Set Store Location'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff check-in verification requires staff to be within radius of these coordinates.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'e.g. 7.35134',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lonController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'e.g. -2.31961',
                      prefixIcon: Icon(Icons.explore_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Allowed Check-In Radius (meters)',
                      hintText: 'e.g. 50',
                      prefixIcon: Icon(Icons.radar_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isFetchingGps
                          ? null
                          : () async {
                              setDialogState(() => isFetchingGps = true);
                              try {
                                bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                if (!serviceEnabled) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please turn on GPS on your device.')),
                                    );
                                  }
                                  return;
                                }
                                LocationPermission permission = await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission = await Geolocator.requestPermission();
                                }
                                final pos = await Geolocator.getCurrentPosition(
                                  locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                                );
                                latController.text = pos.latitude.toStringAsFixed(5);
                                lonController.text = pos.longitude.toStringAsFixed(5);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('GPS Error: $e')),
                                  );
                                }
                              } finally {
                                setDialogState(() => isFetchingGps = false);
                              }
                            },
                      icon: isFetchingGps
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.gps_fixed_rounded),
                      label: Text(isFetchingGps ? 'GETTING CURRENT LOCATION...' : 'USE MY CURRENT LOCATION'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  final lat = double.tryParse(latController.text.trim());
                  final lon = double.tryParse(lonController.text.trim());
                  final radius = double.tryParse(radiusController.text.trim());

                  if (lat == null || lon == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter valid latitude and longitude.')),
                    );
                    return;
                  }

                  ref.read(appSettingsProvider.notifier).updateStoreCoordinates(
                        lat: lat,
                        lon: lon,
                        radius: radius ?? 50.0,
                      );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Store GPS coordinates updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('SAVE LOCATION'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBranchNetworkSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final branchesAsync = ref.watch(branchesProvider);
    final user = ref.watch(currentUserProvider);

    return _buildSection(
      context,
      'Enterprise Branch Network',
      Icons.account_tree_rounded,
      [
        branchesAsync.when(
          data: (branches) {
            return Column(
              children: [
                ...branches.map((b) {
                  final isCurrent = b.code == user?.branchCode;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isCurrent ? Colors.green : theme.colorScheme.primary).withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCurrent ? Icons.store_rounded : Icons.storefront_rounded,
                        color: isCurrent ? Colors.green : theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          b.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCurrent ? Colors.green.withValues(alpha: 0.15) : theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isCurrent ? Colors.green : theme.colorScheme.primary, width: 0.8),
                          ),
                          child: Text(
                            b.code,
                            style: TextStyle(
                              color: isCurrent ? Colors.green : theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      b.location,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    trailing: isCurrent
                        ? const Tooltip(
                            message: 'Current Active Branch',
                            child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                          )
                        : null,
                  );
                }),
                const Divider(),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_location_alt_rounded, color: theme.colorScheme.primary, size: 22),
                  ),
                  title: const Text(
                    'Create New Enterprise Branch',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Add another store location or outlet to the network',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _showCreateBranchDialog(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('ADD BRANCH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ListTile(
            title: const Text('Error loading branches'),
            subtitle: Text('$e'),
          ),
        ),
      ],
    );
  }

  void _showCreateBranchDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final latController = TextEditingController(text: '7.3349');
    final lngController = TextEditingController(text: '-2.3123');
    final radiusController = TextEditingController(text: '500');

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
          title: const Row(
            children: [
              Icon(Icons.storefront_rounded, color: Colors.blue),
              SizedBox(width: 10),
              Text('Create New Branch'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Register a new store branch or outlet to expand your business network:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Branch Code (e.g. ACCRA-01, KUMASI-01)',
                    hintText: 'ACCRA-01',
                    prefixIcon: Icon(Icons.qr_code_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Branch Name',
                    hintText: 'Adom Hardware - Kumasi Branch',
                    prefixIcon: Icon(Icons.store_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Location / Address',
                    hintText: 'Adum Market, Kumasi, Ghana',
                    prefixIcon: Icon(Icons.location_on_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: radiusController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Radius (m)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final code = codeController.text.trim().toUpperCase();
                      final name = nameController.text.trim();
                      final location = locationController.text.trim();

                      if (code.isEmpty || name.isEmpty || location.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill in Branch Code, Name, and Location.'), backgroundColor: Colors.orange),
                        );
                        return;
                      }

                      final existingBranches = ref.read(branchesProvider).value ?? [];
                      if (existingBranches.any((b) => b.code.toUpperCase() == code)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Branch Code "$code" already exists! Choose a unique code.'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        final double lat = double.tryParse(latController.text.trim()) ?? 7.3349;
                        final double lng = double.tryParse(lngController.text.trim()) ?? -2.3123;
                        final double radius = double.tryParse(radiusController.text.trim()) ?? 500.0;

                        final newBranch = Branch(
                          code: code,
                          name: name,
                          location: location,
                          latitude: lat,
                          longitude: lng,
                          radiusMeters: radius,
                        );

                        await ref.read(branchesProvider.notifier).addBranch(newBranch);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ New branch "$name" ($code) created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error creating branch: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        setDialogState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('CREATE BRANCH'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded, color: theme.colorScheme.primary.withValues(alpha: 0.5), size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            'Adom Mmoroso ENT. POS Management',
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            'Version 1.0.0 (Build +1) • Enterprise Edition',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
