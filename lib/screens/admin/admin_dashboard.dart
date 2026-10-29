import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/main_app_bar.dart';
import 'package:intl/intl.dart';
import '../../services/sale_provider.dart';
import '../../services/expense_provider.dart';
import '../../models/sale_model.dart';
import '../../services/notification_service.dart';
import '../../services/product_service.dart';
import '../../models/product.dart';
import '../../services/warehouse_service.dart';
import '../../models/system_models.dart';
import '../../services/customer_provider.dart';
import '../../services/menu_service.dart';
import '../../services/user_provider.dart';
import '../../services/pwa_install_service.dart';
import '../../models/user_model.dart';
import '../../models/branch_model.dart';
import '../../services/branch_provider.dart';
import '../../widgets/role_pop_scope.dart';
import '../../services/report_service.dart';
import '../../services/birthday_service.dart';
import '../../widgets/passcode_guard.dart';
import '../../services/till_provider.dart';
import '../../core/uuid_utils.dart';
import '../../models/expense_model.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/offline_sync_service.dart';
import '../../services/daily_reminder_service.dart';

class _HardwareTip {
  final String badge;
  final String title;
  final String detail;

  const _HardwareTip({
    required this.badge,
    required this.title,
    required this.detail,
  });
}

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  Timer? _timer;
  int _cardIndex0 = 0;
  int _cardIndex1 = 1;
  int _cardIndex2 = 2;
  int _cardIndex3 = 3;
  bool _hasCheckedDialogs = false;

  final List<String> _bannerImages = [
    'assets/images/bgi/aa.jpg',
    'assets/images/bgi/ca.jpg',
    'assets/images/bgi/cc.jpg',
    'assets/images/bgi/ww.jpg',
  ];

  _HardwareTip _getTipForProductImage(String imagePath) {
    final path = imagePath.toLowerCase();

    if (path.contains('/power_tools/') || path.contains('cos1.') || path.contains('cos2.') || path.contains('cos3.') || path.contains('cos4.')) {
      return const _HardwareTip(
        badge: 'POWER TOOLS TIP',
        title: 'Inspect Blades & Safety Guards',
        detail: 'Always inspect power tool blades, cords, and safety guards before starting high-torque cutting.',
      );
    } else if (path.contains('/building_materials/') || path.contains('cos5.') || path.contains('cos8.') || path.contains('cos9.')) {
      return const _HardwareTip(
        badge: 'CEMENT & BLOCKS TIP',
        title: 'Store Cement Above Ground',
        detail: 'Keep cement bags stacked on wooden pallets off concrete floors to prevent moisture hardening.',
      );
    } else if (path.contains('/paints/')) {
      return const _HardwareTip(
        badge: 'PAINTS & FINISHES TIP',
        title: 'Apply Primer Before Top Coat',
        detail: 'Always apply undercoat primer on fresh plaster or masonry walls before applying emulsion paint.',
      );
    } else if (path.contains('/hand_tools/')) {
      return const _HardwareTip(
        badge: 'HAND TOOLS TIP',
        title: 'Use Correct Tool Dimensions',
        detail: 'Match spanner and socket sizes precisely to bolt heads to prevent stripping fasteners.',
      );
    } else if (path.contains('/plumbing/')) {
      return const _HardwareTip(
        badge: 'PLUMBING TIP',
        title: 'Clean PVC Joints Before Cementing',
        detail: 'Wipe dust off PVC pipes and use quality solvent cement for leak-free high pressure joints.',
      );
    } else if (path.contains('/electrical/')) {
      return const _HardwareTip(
        badge: 'ELECTRICAL SAFETY TIP',
        title: 'Use Certified Cable Gauges',
        detail: 'Ensure 2.5mm cables for socket outlets and 1.5mm for lighting circuits to prevent overheating.',
      );
    } else if (path.contains('/roofing/')) {
      return const _HardwareTip(
        badge: 'ROOFING TIP',
        title: 'Fasten Screws On High Ribs',
        detail: 'Secure self-tapping roofing screws with rubber washers on the high ribs of aluzinc sheets.',
      );
    }

    return const _HardwareTip(
      badge: 'HARDWARE CARE TIP',
      title: 'Maintain Tool & Stock Quality',
      detail: 'Keep steel rods and metal hardware in dry covered storage to prevent corrosion and rust.',
    );
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    
    // Check for Daily End-of-Day SMS Reminder
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(dailyReminderServiceProvider).checkAndSendDailySummary();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _cardIndex0 = (_cardIndex0 + 1) % _bannerImages.length;
          _cardIndex1 = (_cardIndex1 + 2) % _bannerImages.length;
          _cardIndex2 = (_cardIndex2 + 3) % _bannerImages.length;
          _cardIndex3 = (_cardIndex3 + 4) % _bannerImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider) ?? ref.watch(sessionUserProfileProvider);
    
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFFF59E0B)),
              const SizedBox(height: 16),
              const Text('Loading Admin Command Center...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Back to Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    // Check for Birthday & PWA Install (run ONLY ONCE on initial mount)
    if (!_hasCheckedDialogs) {
      _hasCheckedDialogs = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          BirthdayService.checkAndShowBirthdayWish(context, user);
          PwaInstallService.checkAndShowPrompt(context);
        }
      });
    }

    // Instant Permission Guard: Redirect if admin access is revoked
    final roles = user.activeRoles;
    final hasAccess = roles.contains(UserRole.admin) || roles.contains(UserRole.superAdmin) || user.enabledPermissions.contains('/admin');
    
    if (!hasAccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDesktop = ResponsiveLayout.isDesktop(context);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);
    const currentRoute = '/admin';
    final menuItems = ref.watch(menuItemsProvider);
    final currentBranch = ref.watch(currentBranchProvider);

    return RolePopScope(
      currentRoute: currentRoute,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          // Since Admin pages are separate routes, standard back button 
          // already goes back to this dashboard. 
          // If we are already here, we stay here.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Use the menu to logout or switch accounts'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: PasscodeGuard(
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: const MainAppBar(title: 'Admin Command Center'),
            drawer: isDesktop
                ? null
                : Drawer(
                    child: AppSidebar(
                      userId: user.id,
                      userName: user.name,
                      userRole: user.activePrimaryRole.toString().split('.').last.toUpperCase(),
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
                    userRole: user.activePrimaryRole.toString().split('.').last.toUpperCase(),
                    currentRoute: currentRoute,
                    items: menuItems,
                    onTap: (route) => MenuService.navigate(context, ref, route, currentRoute),
                  ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context, dateStr, user, currentBranch),
                          const SizedBox(height: AppSpacing.m),
                          _buildBanner(context),
                          const SizedBox(height: AppSpacing.xl),
                          _buildKPIGrid(context, ref),
                          const SizedBox(height: AppSpacing.xl),
                          _buildPendingActions(context, ref),
                          const SizedBox(height: AppSpacing.xl),
                          _buildResponsiveMainContent(context, ref),
                          const SizedBox(height: AppSpacing.xl),
                          _buildInventoryMonitor(context, ref),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingActions(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(saleHistoryProvider);
    final saleRequests = sales.where((s) => s.status == SaleStatus.pendingCorrection).toList();
    final customers = ref.watch(customerProvider);

    final pendingCustomers = customers.where((c) => c.isPendingApproval).toList();

    if (saleRequests.isEmpty && pendingCustomers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pendingCustomers.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.m),
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.l),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.how_to_reg_rounded, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pendingCustomers.length} Customer Application${pendingCustomers.length == 1 ? "" : "s"} Awaiting Activation!',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const Text(
                        'New customer sign-ups requesting account approval',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/admin/customers'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('REVIEW SIGNUPS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (saleRequests.isNotEmpty) ...[
          _buildActionSection(
            context,
            ref,
            title: 'Sale Correction Requests',
            icon: Icons.receipt_long,
            color: Colors.orange,
            items: saleRequests,
            onAction: (sale) => _showRectifySaleDialog(context, ref, sale),
          ),
        ],
      ],
    );
  }

  Widget _buildActionSection(
    BuildContext context, 
    WidgetRef ref, 
    {required String title, required IconData icon, required Color color, required List items, required Function(dynamic) onAction}
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                '$title (${items.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              String displayTitle = '';
              String displaySubtitle = '';
              
              if (item is SaleRecord) {
                displayTitle = 'Mistake in Sale ${item.id}';
                displaySubtitle = 'Reported by ${item.cashierName}: ${item.correctionReason}';
              } else if (item is SystemNotification) {
                displayTitle = item.title;
                displaySubtitle = item.message;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: theme.cardTheme.color,
                child: ListTile(
                  title: Text(displayTitle, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  subtitle: Text(displaySubtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDeleteAction(context, ref, item),
                        tooltip: 'Delete/Dismiss',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => onAction(item),
                        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                        child: const Text('Rectify'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAction(BuildContext context, WidgetRef ref, dynamic item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: const Text('Confirm Deletion'),
        content: Text(item is SaleRecord 
          ? 'Are you sure you want to CANCEL this sale completely? This action is irreversible.'
          : 'Are you sure you want to DISMISS this notification report?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () {
              if (item is SaleRecord) {
                ref.read(saleHistoryProvider.notifier).updateSale(item.copyWith(status: SaleStatus.cancelled));
              } else if (item is SystemNotification) {
                ref.read(notificationProvider.notifier).deleteNotification(item.id);
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action deleted/cancelled.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }

  void _showRectifySaleDialog(BuildContext context, WidgetRef ref, SaleRecord sale) {
    final List<SaleItem> editedItems = List.from(sale.items);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          double calculateNewTotal() => editedItems.fold(0, (sum, item) => sum + item.total);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
            title: Text('Rectify Sale ${sale.id}'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Cashier Report: ${sale.correctionReason}', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Edit Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    ...editedItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.product.name, style: const TextStyle(fontSize: 12))),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: item.quantity.toString(),
                                decoration: InputDecoration(suffixText: item.selectedUnit ?? item.product.unit, isDense: true),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                onChanged: (value) {
                                  final newQty = double.tryParse(value) ?? item.quantity;
                                  setState(() {
                                    editedItems[index] = SaleItem(
                                      product: item.product,
                                      quantity: newQty,
                                      priceAtSale: item.priceAtSale,
                                      originalPrice: item.originalPrice,
                                      selectedUnit: item.selectedUnit,
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Original Total:', style: TextStyle(fontSize: 12)),
                        Text('₵${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Corrected Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('₵${calculateNewTotal().toStringAsFixed(2)}', 
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final newTotal = calculateNewTotal();
                  final rectifiedSale = sale.copyWith(
                    items: editedItems,
                    totalAmount: newTotal,
                    status: SaleStatus.rectified,
                  );
                  
                  // Update State (Future Supabase Update)
                  ref.read(saleHistoryProvider.notifier).updateSale(rectifiedSale);
                  
                  // Notify Cashier
                  ref.read(notificationProvider.notifier).addNotification(
                    'SALE RECTIFIED',
                    'Sale ${sale.id} has been rectified by Admin. Please reprint receipt for customer.',
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sale ${sale.id} rectified. Cashier notified.'),
                      backgroundColor: AppColors.accentGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentGreen, foregroundColor: Colors.white),
                child: const Text('Save & Notify Cashier'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final indices = isMobile
        ? [_cardIndex0, _cardIndex1]
        : [_cardIndex0, _cardIndex1, _cardIndex2, _cardIndex3];

    return SizedBox(
      height: isMobile ? 155 : 185,
      child: Row(
        children: List.generate(indices.length, (i) {
          final imgIndex = indices[i];
          final imgPath = _bannerImages[imgIndex % _bannerImages.length];
          final tip = _getTipForProductImage(imgPath);
          return Expanded(
            child: _buildBannerCard(context, i, indices.length, imgIndex, tip, isDark, isMobile, theme),
          );
        }),
      ),
    );
  }

  Widget _buildBannerCard(
    BuildContext context, 
    int i, 
    int totalCards, 
    int imgIndex, 
    _HardwareTip tip, 
    bool isDark, 
    bool isMobile, 
    ThemeData theme,
  ) {
    return Container(
      margin: EdgeInsets.only(
        left: i == 0 ? 0 : AppSpacing.s,
        right: i == totalCards - 1 ? 0 : AppSpacing.s,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.l),
        child: Container(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                child: Image.asset(
                  _bannerImages[imgIndex],
                  key: ValueKey<String>('bg_${_bannerImages[imgIndex]}'),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withValues(alpha: isDark ? 0.75 : 0.5),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.85),
                          AppColors.secondaryMaroon,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: Center(
                    key: ValueKey<String>('fg_${_bannerImages[imgIndex]}'),
                    child: Image.asset(
                      _bannerImages[imgIndex],
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Column(
                    key: ValueKey<String>('tip_col_${tip.title}_$imgIndex'),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: tip.badge.contains('HYGIENE')
                                  ? [Colors.teal.shade600, Colors.green.shade700]
                                  : tip.badge.contains('GLOW') || tip.badge.contains('BEAUTY')
                                      ? [Colors.pink.shade500, Colors.purple.shade600]
                                      : [theme.colorScheme.primary, Colors.indigo.shade600],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tip.badge.contains('ELECTRICAL')
                                    ? Icons.bolt_rounded
                                    : (tip.badge.contains('PAINT')
                                        ? Icons.palette_rounded
                                        : (tip.badge.contains('PLUMBING')
                                            ? Icons.water_drop_rounded
                                            : Icons.construction_rounded)),
                                color: Colors.white,
                                size: isMobile ? 10 : 12,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  tip.badge,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 8 : 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tip.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: FontWeight.bold,
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tip.detail,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: isMobile ? 9 : 10,
                              height: 1.2,
                              shadows: const [
                                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String dateStr, UserAccount user, Branch? branch) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final theme = Theme.of(context);
    
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${user.firstName}',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _buildBranchSelector(context, ref, user, branch),
          const SizedBox(height: 4),
          Text(dateStr, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: AppSpacing.m),
          _buildActionButtons(context, ref, isMobile),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, ${user.firstName}',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              _buildBranchSelector(context, ref, user, branch),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(dateStr, 
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildActionButtons(context, ref, false),
      ],
    );
  }

  Widget _buildBranchSelector(BuildContext context, WidgetRef ref, UserAccount user, Branch? branch) {
    final theme = Theme.of(context);
    final isAllowedToSwitch = user.activePrimaryRole == UserRole.superAdmin ||
                              user.role == UserRole.superAdmin ||
                              user.activeRoles.contains(UserRole.superAdmin);

    String branchLabel = branch != null 
        ? '${branch.name} (${branch.location})' 
        : (user.branchCode ?? 'Select Branch');

    final upperLabel = branchLabel.toUpperCase();
    if (upperLabel.contains('CITY') || upperLabel.contains('COSMETIC') || upperLabel.contains('SUNYANI_587')) {
      branchLabel = 'Adom Mmoroso ENT. Main Branch (Sunyani)';
    }

    return InkWell(
      onTap: isAllowedToSwitch ? () => _showBranchSwitchDialog(context, ref, user) : null,
      borderRadius: BorderRadius.circular(AppRadius.s),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.s),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_rounded, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                branchLabel,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAllowedToSwitch) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Switch', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.swap_horiz_rounded, size: 12, color: Colors.white),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBranchSwitchDialog(BuildContext context, WidgetRef ref, UserAccount user) {
    final theme = Theme.of(context);
    final branchesAsync = ref.read(branchesProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.storefront_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Switch Active Branch',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: branchesAsync.when(
            data: (branches) {
              if (branches.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No branches available.'),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: branches.length,
                separatorBuilder: (context, index) {
                  return const Divider(height: 1);
                },
                itemBuilder: (context, index) {
                  final b = branches[index];
                  final isCurrent = b.code == user.branchCode;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: isCurrent ? theme.colorScheme.primary : Colors.grey.shade200,
                      child: Icon(
                        Icons.business_rounded, 
                        color: isCurrent ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    title: Text(
                      b.name, 
                      style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${b.location} • Code: ${b.code}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrent 
                        ? const Icon(Icons.check_circle_rounded, color: Colors.green) 
                        : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      if (!isCurrent) {
                        final updatedUser = user.copyWith(branchCode: b.code);
                        ref.read(sessionUserProfileProvider.notifier).state = updatedUser;
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Switched view to ${b.name} (${b.location})'),
                            backgroundColor: theme.colorScheme.primary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Text('Error loading branches: $err'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, bool isMobile) {
    final theme = Theme.of(context);
    final tillState = ref.watch(tillProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Calculate Pending Amount for the Current View
    // If today has pending sales, show today. Otherwise show any pending amount.
    final double todayPending = tillState.pendingByDay[today] ?? 0.0;
    final double totalPending = tillState.pendingByDay.values.fold(0.0, (sum, val) => sum + val);
    
    final bool hasPending = totalPending > 0.01;
    final bool hasPastUnclosed = tillState.pendingByDay.keys.any((d) => d.isBefore(today));

    final String label = todayPending > 0.01 
        ? 'Close Daily Sales (₵${todayPending.toStringAsFixed(0)})'
        : (hasPending ? 'Clear Pending Cash (₵${totalPending.toStringAsFixed(0)})' : 'Close Daily Sales');

    Color buttonColor = Colors.orange.shade800;
    if (hasPastUnclosed) {
      buttonColor = Colors.red.shade700;
    }

    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showExportReportDialog(context),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Export PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.cardTheme.color,
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20, 
              vertical: isMobile ? 10 : 15
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: !hasPending ? null : () => _handleCloseDailySales(context, ref, amount: todayPending > 0 ? todayPending : totalPending),
          icon: Icon(hasPending ? (hasPastUnclosed ? Icons.warning_amber_rounded : Icons.lock_clock) : Icons.check_circle_outline, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasPending ? buttonColor : Colors.grey,
            foregroundColor: Colors.white,
            elevation: hasPending ? 2 : 0,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20, 
              vertical: isMobile ? 10 : 15
            ),
          ),
        ),
      ],
    );
  }

  void _handleCloseDailySales(BuildContext context, WidgetRef ref, {double? amount, DateTime? targetDate, String? initialNote}) {
    final tillState = ref.read(tillProvider);
    final closureDate = targetDate ?? DateTime.now();
    final salesHistory = ref.read(saleHistoryProvider);
    final breakdown = TillNotifier.getPaymentBreakdownForDate(closureDate, salesHistory);

    final expectedPhysicalCash = breakdown.totalPhysicalCash;
    final closingAmount = amount ?? expectedPhysicalCash;
    final amountController = TextEditingController(text: closingAmount.toStringAsFixed(2));
    final noteController = TextEditingController(text: initialNote);

    final debtCollectionsCash = TillNotifier.getDebtCollectionsForDate(closureDate, salesHistory, cashOnly: true);
    final debtCollectionsAll = TillNotifier.getDebtCollectionsForDate(closureDate, salesHistory, cashOnly: false);
    final double debtCollectionsCashTotal = debtCollectionsCash.fold(0.0, (sum, c) => sum + c.amountPaid);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final countedCash = double.tryParse(amountController.text) ?? 0.0;
          final variance = countedCash - expectedPhysicalCash;

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            title: Row(
              children: [
                const Icon(Icons.lock_clock, color: Colors.orange),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Daily Sales Closure & Reconciliation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confirming till cash taking for ${DateFormat('EEEE, MMM dd, yyyy').format(closureDate)}.', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  _buildPaymentBreakdownCard(breakdown, closingAmount, context),

                  _buildDebtCollectionsView(debtCollectionsAll, context),

                  if (debtCollectionsCashTotal > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Note: Physical Cash in shop (₵${breakdown.totalPhysicalCash.toStringAsFixed(2)}) includes ₵${debtCollectionsCashTotal.toStringAsFixed(2)} in cash debt repayments.',
                              style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setModalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Counted Physical Cash in Drawer (GHS)',
                      prefixText: '₵ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Live Cash Variance Badge
                  if (variance.abs() < 0.01)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade300)),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green.shade800, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'PERFECT MATCH: Cash count matches expected till cash',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (variance < -0.01)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade300)),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CASH SHORTAGE: -₵${(-variance).toStringAsFixed(2)} below expected till cash',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade300)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CASH OVERAGE: +₵${variance.toStringAsFixed(2)} above expected till cash',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Closure Note (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () async {
                  final finalAmount = double.tryParse(amountController.text);
                  if (finalAmount == null || finalAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  String closureTitle = noteController.text.trim();
                  if (closureTitle.isEmpty) {
                    final double debtTotal = debtCollectionsCash.fold(0.0, (sum, c) => sum + c.amountPaid);
                    final String debtNotePart = debtTotal > 0 
                        ? ' (Includes Debt Collections: ₵${debtTotal.toStringAsFixed(2)})'
                        : '';
                    closureTitle = 'Daily Sales Closure for ${DateFormat('yyyy-MM-dd').format(closureDate)}$debtNotePart';
                  }

                  final expense = ExpenseRecord(
                    id: UuidUtils.generate(),
                    title: closureTitle,
                    category: 'Daily Sales Closure',
                    amount: finalAmount,
                    date: closureDate,
                  );
                  
                  final totalPending = tillState.pendingByDay.values.fold(0.0, (sum, val) => sum + val);

                  await ref.read(expenseProvider.notifier).recordCEOWithdrawal(
                    expense: expense,
                    currentTillBalance: expectedPhysicalCash,
                    totalRemainingAfter: totalPending - finalAmount,
                  );

                  // Print / Export Till Closure PDF Receipt
                  await ReportService.generateDailyTillClosureReceipt(
                    closureDate: closureDate,
                    physicalCashSales: breakdown.physicalCashSales,
                    physicalCashDebt: breakdown.physicalCashDebt,
                    totalPhysicalCash: breakdown.totalPhysicalCash,
                    momoTotal: breakdown.totalMomo,
                    bankTotal: breakdown.totalBank,
                    grossRevenue: breakdown.totalRevenue,
                    closingAmount: finalAmount,
                    note: closureTitle,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Daily sales closed, Till Receipt Generated & Security SMS Sent')),
                    );
                  }
                },
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Confirm Closure & Print'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaymentBreakdownCard(PaymentMethodBreakdown breakdown, double closingAmount, BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.payments_rounded, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PHYSICAL CASH IN TILL:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '₵${breakdown.totalPhysicalCash.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade900),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 3, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Direct Cash: ₵${breakdown.physicalCashSales.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Cash Debt: ₵${breakdown.physicalCashDebt.toStringAsFixed(2)}',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'MOBILE MONEY (MOMO):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '₵${breakdown.totalMomo.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 3, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Direct MoMo: ₵${breakdown.momoSales.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'MoMo Debt: ₵${breakdown.momoDebt.toStringAsFixed(2)}',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (breakdown.totalBank > 0) ...[
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 16, color: Colors.purple),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'BANK DEPOSITS:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '₵${breakdown.totalBank.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 3, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Direct Bank: ₵${breakdown.bankSales.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Bank Debt: ₵${breakdown.bankDebt.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'TOTAL PERIOD REVENUE:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '₵${breakdown.totalRevenue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCollectionsView(List<DebtCollectionInfo> debtCollections, BuildContext context) {
    final double totalDebtPaid = debtCollections.fold(0.0, (sum, c) => sum + c.amountPaid);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.people_alt_rounded, size: 16, color: Colors.blue),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'DEBT PAYMENTS IN PERIOD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${debtCollections.length} paid • Total ₵${totalDebtPaid.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (debtCollections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No debt repayments recorded for this period.',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: debtCollections.map((dc) {
                final methodText = dc.paymentMethod == PaymentMethod.cash 
                    ? 'CASH' 
                    : (dc.paymentMethod == PaymentMethod.mobileMoney ? 'MOMO' : 'BANK');
                final methodColor = dc.paymentMethod == PaymentMethod.cash 
                    ? Colors.green.shade700 
                    : (dc.paymentMethod == PaymentMethod.mobileMoney ? Colors.orange.shade800 : Colors.purple.shade700);

                final invoiceShort = dc.invoiceId.length > 8 
                    ? dc.invoiceId.substring(dc.invoiceId.length - 8).toUpperCase() 
                    : dc.invoiceId.toUpperCase();

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    dc.customerName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '₵${dc.amountPaid.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Phone: ${dc.customerPhone} • Ref: #$invoiceShort • ${DateFormat('HH:mm').format(dc.paymentTime)}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: methodColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: methodColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              methodText,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: methodColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            dc.isFullSettlement ? Icons.check_circle : Icons.hourglass_top,
                            size: 12,
                            color: dc.isFullSettlement ? Colors.green.shade700 : Colors.orange.shade900,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dc.isFullSettlement
                                  ? 'Fully Cleared'
                                  : 'Partial Payment (Remaining Bal: ₵${dc.remainingBalance.toStringAsFixed(2)})',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: dc.isFullSettlement ? Colors.green.shade800 : Colors.orange.shade900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showExportReportDialog(BuildContext context) {
    final theme = Theme.of(context);
    final searchController = TextEditingController();
    
    final List<Map<String, dynamic>> reports = [
      {'title': 'CEO Product Activity Report', 'desc': 'Comprehensive product intake, sales & remaining stock audit', 'icon': Icons.assessment, 'cat': 'Executive'},
      {'title': 'Daily Sales Report', 'desc': 'Detailed list of all transactions today', 'icon': Icons.point_of_sale, 'cat': 'Financial'},
      {'title': 'Monthly Revenue Summary', 'desc': 'Financial overview for the current month', 'icon': Icons.account_balance, 'cat': 'Financial'},
      {'title': 'Inventory Audit', 'desc': 'Stock levels and low-stock warnings', 'icon': Icons.inventory_2, 'cat': 'Stock'},
      {'title': 'Warehouse Intake Log', 'desc': 'Supplier intake & stock receiving records', 'icon': Icons.move_to_inbox, 'cat': 'Logistics'},
      {'title': 'Staff Performance', 'desc': 'Individual sales and processing metrics', 'icon': Icons.badge, 'cat': 'Staff'},
      {'title': 'Customer Debt Statement', 'desc': 'Outstanding balances and payment history', 'icon': Icons.money_off, 'cat': 'Customers'},
      {'title': 'Business Expense Ledger', 'desc': 'Categorized operational costs', 'icon': Icons.receipt_long, 'cat': 'Financial'},
      {'title': 'Stock Breakdown Analysis', 'desc': 'Detailed batch and stock distribution', 'icon': Icons.grid_view_rounded, 'cat': 'Logistics'},
      {'title': 'Operational Reports', 'desc': 'Combined view of workstation logs', 'icon': Icons.assignment, 'cat': 'General'},
      {'title': 'System Audit Log', 'desc': 'Record of administrative changes', 'icon': Icons.history_edu, 'cat': 'Security'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final query = searchController.text.toLowerCase();
          final filteredReports = reports.where((r) => 
            r['title'].toLowerCase().contains(query) ||
            r['desc'].toLowerCase().contains(query) ||
            r['cat'].toLowerCase().contains(query)
          ).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.all(AppSpacing.l),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Generate Report PDF', style: TextStyle(color: Colors.white, fontSize: 18))),
                ],
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: (v) => setState(() {}),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by title, category or description...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                          searchController.clear();
                          setState(() {});
                        }) : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: Container(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(AppRadius.s),
                        ),
                        child: filteredReports.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No matching reports found.', style: TextStyle(color: Colors.grey)),
                              ],
                            )))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredReports.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor),
                              itemBuilder: (context, index) {
                                final r = filteredReports[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(r['icon'], color: theme.colorScheme.primary, size: 20),
                                  ),
                                  title: Text(r['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(r['desc'], style: const TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.download_for_offline, size: 18, color: Colors.green),
                                      const SizedBox(height: 2),
                                      Text(r['cat'].toUpperCase(), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Generating ${r['title']}... Please wait.'),
                                        backgroundColor: AppColors.accentGreen,
                                      ),
                                    );
                                    
                                    try {
                                      if (r['title'] == 'CEO Product Activity Report') {
                                        if (context.mounted) {
                                          Navigator.pushNamed(context, '/admin/product-report');
                                        }
                                      } else if (r['title'] == 'Daily Sales Report') {
                                        final sales = ref.read(saleHistoryProvider).where((s) => s.isActive).toList();
                                        await ReportService.generateDailySalesReport(sales, DateTime.now());
                                      } else if (r['title'] == 'Monthly Revenue Summary') {
                                        final sales = ref.read(saleHistoryProvider).where((s) => s.isActive).toList();
                                        await ReportService.generateMonthlyRevenueSummary(sales, DateTime.now());
                                      } else if (r['title'] == 'Inventory Audit') {
                                        final products = ref.read(productsFutureProvider).value ?? [];
                                        await ReportService.generateInventoryAudit(products);
                                      } else if (r['title'] == 'Warehouse Intake Log') {
                                        final intakes = ref.read(warehouseIntakeProvider).value ?? [];
                                        await ReportService.generateWarehouseIntakeReport(intakes);
                                      } else if (r['title'] == 'Business Expense Ledger') {
                                        final expenses = ref.read(expenseProvider).records;
                                        await ReportService.generateExpenseLedger(expenses);
                                      } else if (r['title'] == 'Customer Debt Statement') {
                                        final sales = ref.read(saleHistoryProvider).where((s) => s.isActive).toList();
                                        await ReportService.generateCustomerDebtStatement(sales);
                                      } else if (r['title'] == 'Stock Breakdown Analysis') {
                                        final products = ref.read(productsFutureProvider).value ?? [];
                                        await ReportService.generateWarehouseValuationReport(products);
                                      } else if (r['title'] == 'Staff Performance') {
                                        final sales = ref.read(saleHistoryProvider).where((s) => s.isActive).toList();
                                        final staff = ref.read(userProvider);
                                        await ReportService.generateStaffPerformanceReport(sales, staff);
                                      } else {
                                        // Default placeholder for other reports
                                        await Future.delayed(const Duration(seconds: 1));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('This report type is coming soon in the next update!')),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error generating report: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Close Window', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKPIGrid(BuildContext context, WidgetRef ref) {
    final bool isMobile = ResponsiveLayout.isMobile(context);
    final bool isTablet = ResponsiveLayout.isTablet(context);
    
    final now = DateTime.now();
    final allSales = ref.watch(saleHistoryProvider);
    
    // Monthly Reset Logic: Filter all core metrics by current month
    final sales = allSales.where((s) => 
      s.isActive && 
      s.timestamp.month == now.month && 
      s.timestamp.year == now.year
    ).toList();
    
    final totalRevenue = sales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final totalCost = sales.fold(0.0, (sum, sale) => sum + sale.totalCost);
    final grossProfit = totalRevenue - totalCost;

    // Top Category Calculation
    final Map<String, double> categoryRevenue = {};
    for (var sale in sales) {
      for (var item in sale.items) {
        final cat = item.product.category;
        categoryRevenue[cat] = (categoryRevenue[cat] ?? 0.0) + item.total;
      }
    }

    String topCategory = 'Building Materials';
    if (categoryRevenue.isNotEmpty) {
      var sorted = categoryRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      topCategory = sorted.first.key;
    }

    // Avg Basket Value & Today Checkouts Calculation
    final double avgBasket = sales.isNotEmpty ? (totalRevenue / sales.length) : 0.0;
    final todayCheckouts = sales.where((s) => 
      s.timestamp.day == now.day && 
      s.timestamp.month == now.month && 
      s.timestamp.year == now.year
    ).length;

    final productsAsync = ref.watch(productsFutureProvider);
    final lowStockCount = (productsAsync.value ?? []).where((p) => !p.isDeleted && p.needsDispatch).length;
    
    // Total Debt should reflect all-time outstanding balance, not just the current month
    final totalDebt = allSales.where((s) => s.isActive)
        .fold(0.0, (sum, sale) => sum + (sale.balance > 0 ? sale.balance : 0));

    final totalDiscounts = sales.fold(0.0, (sum, sale) => sum + sale.totalDiscount);
    final totalWeightSold = sales.fold(0.0, (sum, sale) => sum + sale.totalQty);
    
    final expensesState = ref.watch(expenseProvider);
    final totalExpenses = expensesState.records.where((e) => 
      e.isOperationalExpense && e.date.month == now.month && e.date.year == now.year
    ).fold(0.0, (sum, e) => sum + e.amount);

    final netProfit = grossProfit - totalExpenses;

    final tillState = ref.watch(tillProvider);
    final totalPending = tillState.pendingByDay.values.fold(0.0, (sum, val) => sum + val);

    final theme = Theme.of(context);

    int crossAxisCount = isMobile ? 2 : (isTablet ? 4 : 4);
    double aspectRatio = isMobile ? 1.6 : 2.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Financial Performance
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0, top: 4.0),
          child: Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text('FINANCIAL PERFORMANCE', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(DateFormat('MMMM yyyy').format(now).toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontSize: 8.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: aspectRatio,
          children: [
            _kpiWithTrend(context, "Gross Sales", '₵${totalRevenue.toStringAsFixed(0)}', Icons.payments_rounded, Colors.blue, 'MONTH'),
            _kpiWithTrend(
              context, 
              "Gross Profit", 
              '₵${grossProfit.toStringAsFixed(0)}', 
              Icons.show_chart_rounded, 
              grossProfit >= 0 ? Colors.teal : Colors.red, 
              grossProfit >= 0 ? 'MARGIN' : 'LOSS',
              onTap: () => _showProfitBreakdownDialog(context, totalRevenue, totalCost, grossProfit, totalExpenses, netProfit),
            ),
            _kpiWithTrend(context, "Expenses", '₵${totalExpenses.toStringAsFixed(0)}', Icons.trending_down_rounded, Colors.redAccent, 'MONTH'),
            _kpiWithTrend(
              context, 
              'Net Profit', 
              '₵${netProfit.toStringAsFixed(0)}', 
              Icons.account_balance_wallet_rounded, 
              netProfit >= 0 ? const Color(0xFF30D158) : Colors.red, 
              netProfit >= 0 ? 'MONTH' : 'LOSS',
              onTap: () => _showProfitBreakdownDialog(context, totalRevenue, totalCost, grossProfit, totalExpenses, netProfit),
            ),
          ],
        ),
        
        const SizedBox(height: AppSpacing.l),

        // Section 2: Treasury & Cash Flow
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Row(
            children: [
              Icon(Icons.account_balance_rounded, size: 16, color: Colors.orange.shade800),
              const SizedBox(width: 6),
              Flexible(
                child: Text('TREASURY & CASH FLOW', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: isMobile ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: aspectRatio,
          children: [
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/admin/sales'),
              borderRadius: BorderRadius.circular(16),
              child: _kpiWithTrend(context, 'Total Shop Funds', '₵${totalPending.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, Colors.orange.shade800, 'TILL'),
            ),
            _kpiWithTrend(context, 'Total Debt', '₵${totalDebt.toStringAsFixed(0)}', Icons.money_off_rounded, Colors.red, 'TOTAL'),
            _kpiWithTrend(context, 'Promo Impact', '₵${totalDiscounts.toStringAsFixed(0)}', Icons.auto_awesome_rounded, Colors.amber.shade800, 'SAVED'),
            _kpiWithTrend(context, 'Top Category', topCategory, Icons.category_rounded, Colors.purple, '#1 REV'),
          ],
        ),

        const SizedBox(height: AppSpacing.l),

        // Section 3: Operations & Inventory Analytics
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Row(
            children: [
              Icon(Icons.storefront_rounded, size: 16, color: Colors.indigo),
              const SizedBox(width: 6),
              Flexible(
                child: Text('OPERATIONS & INVENTORY', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: isMobile ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.m,
          mainAxisSpacing: AppSpacing.m,
          childAspectRatio: aspectRatio,
          children: [
            _kpiWithTrend(context, 'Avg Spend / Sale', '₵${avgBasket.toStringAsFixed(0)}', Icons.shopping_bag_rounded, Colors.indigo, 'BASKET'),
            _kpiWithTrend(context, 'Store Checkouts', '$todayCheckouts Sales', Icons.point_of_sale_rounded, Colors.blue.shade700, 'TODAY'),
            _kpiWithTrend(context, 'Stock Sold', totalWeightSold % 1 == 0 ? '${totalWeightSold.toInt()} Pcs' : '${totalWeightSold.toStringAsFixed(1)} Pcs', Icons.inventory_2_rounded, theme.colorScheme.primary, 'LIVE'),
            _kpiWithTrend(context, 'Low Stock Alerts', '$lowStockCount Items', Icons.warning_amber_rounded, lowStockCount > 0 ? Colors.red : Colors.green, 'REORDER'),
          ],
        ),
      ],
    );
  }

  Widget _kpiWithTrend(BuildContext context, String title, String value, IconData icon, Color color, String trend, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);
    final bool isPositive = trend.startsWith('+') || trend == 'SAVED' || trend == 'LIVE' || trend == 'MARGIN' || trend == 'MONTH' || (!value.startsWith('-') && !value.contains('-'));
    final Color badgeColor = (title.contains('Low Stock') && value != '0 Items') ? const Color(0xFFFF3B30) : (isPositive ? const Color(0xFF30D158) : const Color(0xFFFF3B30));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 14,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: isDark 
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.3 : 0.18),
              width: 1.2,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: color.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isMobile ? 36 : 42,
                height: isMobile ? 36 : 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: color, size: isMobile ? 18 : 22),
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: isMobile ? 9.5 : 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _AnimatedCountText(
                        text: value,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        trend,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: isMobile ? 7.5 : 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfitBreakdownDialog(BuildContext context, double sales, double cost, double gross, double expenses, double net) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        title: Row(
          children: [
            Icon(net >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: net >= 0 ? Colors.green : Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                net >= 0 ? 'Net Profit Breakdown' : 'Net Loss Breakdown',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 500 ? 460 : MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _breakdownRow('1. Total Sales Revenue', '₵${sales.toStringAsFixed(2)}', Colors.blue),
                const SizedBox(height: 8),
                _breakdownRow('2. Cost of Goods Sold (COGS)', '-₵${cost.toStringAsFixed(2)}', Colors.orange.shade800),
                const Divider(height: 16),
                _breakdownRow('Gross Profit (1 - 2)', '₵${gross.toStringAsFixed(2)}', gross >= 0 ? Colors.teal : Colors.red, isBold: true),
                const SizedBox(height: 8),
                _breakdownRow('3. Operational Expenses', '-₵${expenses.toStringAsFixed(2)}', Colors.red),
                const Divider(height: 20, thickness: 1.5),
                _breakdownRow('NET PROFIT', '₵${net.toStringAsFixed(2)}', net >= 0 ? Colors.green : Colors.red, isBold: true, fontSize: 15),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (net >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    net >= 0
                        ? 'Your business generated positive net profit after deducting costs and operational expenses.'
                        : 'Your recorded operational expenses (-₵${expenses.toStringAsFixed(2)}) or stock costs exceed your sales revenue for this period.',
                    style: TextStyle(fontSize: 11, color: net >= 0 ? Colors.green.shade900 : Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value, Color color, {bool isBold = false, double fontSize = 12}) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label, 
            style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value, 
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveMainContent(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final allSales = ref.watch(saleHistoryProvider);
    final sales = allSales.where((s) => s.isActive).toList();
    
    final promoSales = sales.where((s) => s.totalDiscount > 0).toList();
    final totalImpact = promoSales.fold(0.0, (sum, s) => sum + s.totalDiscount);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2, 
            child: Column(
              children: [
                _buildPerformanceChart(context, sales),
                const SizedBox(height: AppSpacing.l),
                _buildStockLevelComparisonChart(context, ref),
                const SizedBox(height: AppSpacing.l),
                _buildCategorySalesChart(context, sales),
              ],
            )
          ),
          const SizedBox(width: AppSpacing.l),
          Expanded(
            flex: 1, 
            child: Column(
              children: [
                _buildPromotionImpactCard(context, promoSales, totalImpact),
                const SizedBox(height: AppSpacing.l),
                _buildCriticalAlerts(context, ref),
              ],
            )
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildPerformanceChart(context, sales),
          const SizedBox(height: AppSpacing.l),
          _buildStockLevelComparisonChart(context, ref),
          const SizedBox(height: AppSpacing.l),
          _buildCategorySalesChart(context, sales),
          const SizedBox(height: AppSpacing.l),
          _buildPromotionImpactCard(context, promoSales, totalImpact),
          const SizedBox(height: AppSpacing.l),
          _buildCriticalAlerts(context, ref),
        ],
      );
    }
  }

  Widget _buildStockLevelComparisonChart(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productsAsync = ref.watch(productsFutureProvider);
    final products = (productsAsync.value ?? []).where((p) => !p.isDeleted).toList();

    final Map<String, double> warehouseStockMap = {};
    final Map<String, double> shopStockMap = {};

    for (final p in products) {
      final cat = p.category.trim().isEmpty ? 'General' : p.category;
      warehouseStockMap[cat] = (warehouseStockMap[cat] ?? 0.0) + p.warehouseQuantity;
      shopStockMap[cat] = (shopStockMap[cat] ?? 0.0) + p.stockQuantity;
    }

    final categories = warehouseStockMap.keys.toList()
      ..sort((a, b) {
        final totalA = (warehouseStockMap[a] ?? 0) + (shopStockMap[a] ?? 0);
        final totalB = (warehouseStockMap[b] ?? 0) + (shopStockMap[b] ?? 0);
        return totalB.compareTo(totalA);
      });

    final displayCategories = categories.take(6).toList();

    final totalWarehouse = products.fold(0.0, (sum, p) => sum + p.warehouseQuantity);
    final totalShop = products.fold(0.0, (sum, p) => sum + p.stockQuantity);

    final List<FlSpot> whsSpots = [];
    final List<FlSpot> shopSpots = [];
    double maxStock = 0;

    for (int i = 0; i < displayCategories.length; i++) {
      final cat = displayCategories[i];
      final whsVal = warehouseStockMap[cat] ?? 0.0;
      final shopVal = shopStockMap[cat] ?? 0.0;

      whsSpots.add(FlSpot(i.toDouble(), whsVal));
      shopSpots.add(FlSpot(i.toDouble(), shopVal));

      if (whsVal > maxStock) maxStock = whsVal;
      if (shopVal > maxStock) maxStock = shopVal;
    }

    final double chartMaxY = maxStock == 0 ? 100 : maxStock * 1.2;

    const whsColor = Color(0xFF2563EB);  // Vivid Sapphire Blue for Warehouse
    const shopColor = Color(0xFF10B981); // Vivid Emerald Green for Retail Shop

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(color: theme.dividerColor.withValues(alpha: isDark ? 0.3 : 0.6)),
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
                      'Stock Level Comparison',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Warehouse vs Shop inventory across categories',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey),
            ],
          ),
          const SizedBox(height: AppSpacing.m),

          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _legendDot(whsColor, 'Warehouse (${NumberFormat('#,###').format(totalWarehouse.toInt())} Pcs)', theme),
              _legendDot(shopColor, 'Shop (${NumberFormat('#,###').format(totalShop.toInt())} Pcs)', theme),
            ],
          ),

          const SizedBox(height: AppSpacing.l),

          if (displayCategories.isEmpty)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text('No inventory stock data available.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? Colors.white10 : Colors.black12,
                      strokeWidth: 1,
                      dashArray: [3, 3],
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => isDark ? const Color(0xFF1E293B) : Colors.white,
                      tooltipBorder: BorderSide(color: theme.dividerColor),
                      getTooltipItems: (touchedSpots) {
                        if (touchedSpots.isEmpty) return [];
                        final firstSpot = touchedSpots.first;
                        final idx = firstSpot.x.toInt();
                        final String categoryName = (idx >= 0 && idx < displayCategories.length)
                            ? _formatCategoryLabel(displayCategories[idx])
                            : '';

                        return touchedSpots.map((spot) {
                          final isWarehouse = spot.barIndex == 0;
                          final label = isWarehouse ? 'Warehouse' : 'Shop';
                          final color = isWarehouse ? whsColor : shopColor;
                          final isFirst = spot == firstSpot;

                          final String tooltipText = isFirst && categoryName.isNotEmpty
                              ? '$categoryName\n$label: ${NumberFormat('#,###').format(spot.y.toInt())} Pcs'
                              : '$label: ${NumberFormat('#,###').format(spot.y.toInt())} Pcs';

                          return LineTooltipItem(
                            tooltipText,
                            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 38,
                        getTitlesWidget: (val, meta) {
                          if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                          final formatted = val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : '${val.toInt()}';
                          return Text(
                            formatted,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A), 
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (val, meta) {
                          final index = val.toInt();
                          if (index >= 0 && index < displayCategories.length) {
                            final label = _formatCategoryLabel(displayCategories[index]);
                            final shortLabel = label.length > 7 ? '${label.substring(0, 6)}..' : label;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                shortLabel.toUpperCase(),
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: chartMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: whsSpots,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: whsColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 3.5,
                          color: whsColor,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                    LineChartBarData(
                      spots: shopSpots,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: shopColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 3.5,
                          color: shopColor,
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _formatCategoryLabel(String raw) {
    final clean = raw.trim();
    if (clean.length <= 10) return clean;
    final words = clean.split(' ');
    if (words.length > 1) {
      return words.first;
    }
    return '${clean.substring(0, 9)}…';
  }

  Widget _buildCategorySalesChart(BuildContext context, List<SaleRecord> sales) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Map<String, double> categoryMap = {};
    for (final sale in sales) {
      for (final item in sale.items) {
        final cat = item.product.category;
        categoryMap[cat] = (categoryMap[cat] ?? 0.0) + item.total;
      }
    }

    final sortedEntries = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxVal = sortedEntries.isEmpty ? 1000.0 : (sortedEntries.first.value > 0 ? sortedEntries.first.value : 1000.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: isDark ? Border.all(color: theme.dividerColor) : null,
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
                    Text('Hardware Category Sales Distribution', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Revenue distribution across hardware categories', 
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.category_rounded, color: theme.colorScheme.primary, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          if (sortedEntries.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('No category sales recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            )
          else
            Column(
              children: sortedEntries.take(5).map((entry) {
                final ratio = (entry.value / maxVal).clamp(0.05, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('₵${entry.value.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPromotionImpactCard(BuildContext context, List<SaleRecord> promoSales, double totalImpact) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: isDark ? Border.all(color: theme.dividerColor) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Promotion Analytics', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text('${promoSales.length} Active', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          Divider(height: 24, color: theme.dividerColor),
          Text('Total Revenue Impact (Money Saved for Customers)', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant), softWrap: true),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('₵ ${totalImpact.toStringAsFixed(2)}', 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
          const SizedBox(height: 16),
          Text('Recent Promo Transactions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          if (promoSales.isEmpty)
            Text('No promotions applied yet.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant))
          else
            ...promoSales.take(3).map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.appliedPromo ?? 'Discount', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface))),
                  Text('-₵${s.totalDiscount.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart(BuildContext context, List<SaleRecord> sales) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Generate data for the last 7 days
    final now = DateTime.now();
    final last7Days = List.generate(7, (index) {
      return now.subtract(Duration(days: 6 - index));
    });

    final activeSales = sales.where((s) => s.isActive).toList();

    final dailyRevenue = last7Days.map((date) {
      final total = activeSales
          .where((s) => s.timestamp.year == date.year &&
                        s.timestamp.month == date.month &&
                        s.timestamp.day == date.day)
          .fold(0.0, (sum, s) => sum + s.totalAmount);
      return total;
    }).toList();

    final maxRevenue = dailyRevenue.reduce((a, b) => a > b ? a : b);
    final double chartMax = maxRevenue == 0 ? 1000 : maxRevenue * 1.2;

    // Top Selling Category Logic
    final categoryStats = <String, double>{};
    for (var sale in activeSales) {
      for (var item in sale.items) {
        categoryStats[item.product.category] = (categoryStats[item.product.category] ?? 0) + item.total;
      }
    }
    final sortedCategories = categoryStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCategory = sortedCategories.isEmpty ? 'N/A' : sortedCategories.first.key;
    final isMobile = ResponsiveLayout.isMobile(context);
    final Color chartPrimaryColor = isDark 
        ? (theme.colorScheme.primary.computeLuminance() < 0.2 ? Colors.amber : theme.colorScheme.primary)
        : (theme.colorScheme.primary.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : theme.colorScheme.primary);

    return Container(
      height: isMobile ? 290 : 360,
      padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: isDark ? Border.all(color: theme.dividerColor) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Analytics', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18, color: theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Real-time revenue & category performance', 
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('TOP CATEGORY', 
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        topCategory.toUpperCase(), 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: chartPrimaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(dailyRevenue.length, (index) {
                final amount = dailyRevenue[index];
                final date = last7Days[index];
                final double maxVisualBar = isMobile ? 140 : 180;
                final double barHeight = amount == 0 ? 8 : (amount / chartMax) * maxVisualBar;
                final isToday = index == 6;

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amount > 0 ? '₵${amount.toStringAsFixed(0)}' : '',
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: isToday ? chartPrimaryColor : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Tooltip(
                        message: '₵${amount.toStringAsFixed(2)} on ${DateFormat('MMM dd').format(date)}',
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: barHeight,
                          decoration: BoxDecoration(
                            gradient: amount > 0
                                ? LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isToday
                                        ? [chartPrimaryColor, chartPrimaryColor.withValues(alpha: 0.75)]
                                        : [Colors.blue.shade600, Colors.blue.shade400],
                                  )
                                : null,
                            color: amount == 0 ? (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)) : null,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('E').format(date).substring(0, 1),
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? chartPrimaryColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalAlerts(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productsAsync = ref.watch(productsFutureProvider);
    final sales = ref.watch(saleHistoryProvider);
    
    // Calculate real alerts
    final lowStockItems = productsAsync.value?.where((p) => !p.isDeleted && p.stockQuantity < 10).toList() ?? [];
    final pendingCorrections = sales.where((s) => s.status == SaleStatus.pendingCorrection).toList();
    
    final now = DateTime.now();
    final users = ref.watch(userProvider);
    final pendingSalaries = users.where((u) {
      if (u.isDeleted || u.status != AccountStatus.approved) return false;
      if (u.salaryAmount == null || u.salaryDay == null) return false;
      if (now.day >= u.salaryDay!) {
        if (u.lastSalaryDate == null) return true;
        if (u.lastSalaryDate!.month != now.month || u.lastSalaryDate!.year != now.year) return true;
      }
      return false;
    }).toList();

    return Container(
      height: 400,
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: isDark ? Border.all(color: theme.dividerColor) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notification_important, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('System Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.onSurface), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              if (lowStockItems.length + pendingCorrections.length + pendingSalaries.length > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${lowStockItems.length + pendingCorrections.length + pendingSalaries.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Expanded(
            child: (lowStockItems.isEmpty && pendingCorrections.isEmpty && pendingSalaries.isEmpty)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: Colors.green.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text('System healthy. No urgent alerts.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      if (pendingSalaries.isNotEmpty)
                        _alertTile(
                          context,
                          'Payroll Due', 
                          '${pendingSalaries.length} staff members are due for salary payment.', 
                          Colors.purple, 
                          Icons.payments_rounded,
                          onTap: () => Navigator.pushNamed(context, '/admin/salaries'),
                        ),
                      ...pendingCorrections.map((s) => _alertTile(
                        context,
                        'Sale Correction Req', 
                        'Invoice ${s.id} reported by ${s.cashierName}', 
                        Colors.orange, 
                        Icons.receipt_long
                      )),
                      ...lowStockItems.map((p) => _alertTile(
                        context,
                        'Low Stock Alert', 
                        '${p.name} is critically low (${p.stockQuantity}${p.unit} left).', 
                        Colors.red.shade700, 
                        Icons.inventory_2
                      )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _alertTile(BuildContext context, String title, String subtitle, Color color, IconData icon, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.m),
        padding: const EdgeInsets.all(AppSpacing.m),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryMonitor(BuildContext context, WidgetRef ref) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productsAsync = ref.watch(productsFutureProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.l),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: isDark ? Border.all(color: theme.dividerColor) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Critical Stock Monitoring', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/warehouse'),
                icon: const Icon(Icons.warehouse_rounded, size: 16),
                label: const Text('Warehouse Hub', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          productsAsync.when(
            data: (products) {
              final display = products.isNotEmpty ? products : _getHiveCachedProducts();
              return _buildStockIndicatorsWidget(display, isMobile, context, theme);
            },
            loading: () {
              final cached = _getHiveCachedProducts();
              if (cached.isNotEmpty) {
                return _buildStockIndicatorsWidget(cached, isMobile, context, theme);
              }
              return const Center(child: CircularProgressIndicator());
            },
            error: (_, error) {
              final cached = _getHiveCachedProducts();
              if (cached.isNotEmpty) {
                return _buildStockIndicatorsWidget(cached, isMobile, context, theme);
              }
              return const Text('Error loading stock levels.');
            },
          ),
        ],
      ),
    );
  }

  List<Product> _getHiveCachedProducts() {
    try {
      if (Hive.isBoxOpen(OfflineSyncService.productsBoxName)) {
        final box = Hive.box(OfflineSyncService.productsBoxName);
        if (box.isNotEmpty) {
          return box.values
              .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
              .where((p) => !p.isDeleted)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Widget _buildStockIndicatorsWidget(List<Product> products, bool isMobile, BuildContext context, ThemeData theme) {
    final criticalStock = products
        .where((p) => !p.isDeleted)
        .toList()
      ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
    
    final top3 = criticalStock.take(3).toList();
    
    if (top3.isEmpty) return Text('No stock data available.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant));

    return isMobile
        ? Column(
            children: top3.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: _stockIndicator(context, p.name, (p.stockQuantity / 100).clamp(0.0, 1.0), p.stockQuantity < 10 ? Colors.red : Colors.orange),
            )).toList(),
          )
        : Row(
            children: top3.map((p) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.l),
                child: _stockIndicator(context, p.name, (p.stockQuantity / 100).clamp(0.0, 1.0), p.stockQuantity < 10 ? Colors.red : Colors.orange),
              ),
            )).toList(),
          );
  }

  Widget _stockIndicator(BuildContext context, String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text('${(value * 100).toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _AnimatedCountText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _AnimatedCountText({
    required this.text,
    required this.style,
  });

  static final NumberFormat _formatter = NumberFormat('#,##0');
  static final NumberFormat _decimalFormatter = NumberFormat('#,##0.0');

  String _formatValue(double val, bool isInteger) {
    if (isInteger) {
      return _formatter.format(val.round());
    } else {
      return _decimalFormatter.format(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RegExp numRegExp = RegExp(r'[-+]?\d*\.?\d+');
    final match = numRegExp.firstMatch(text);

    if (match == null) {
      return Text(text, style: style);
    }

    final String numStr = match.group(0)!;
    final double targetValue = double.tryParse(numStr) ?? 0.0;
    final String prefix = text.substring(0, match.start);
    final String suffix = text.substring(match.end);
    final bool isInteger = !numStr.contains('.');

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetValue),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        final String formattedNum = _formatValue(val, isInteger);
        return Text(
          '$prefix$formattedNum$suffix',
          style: style,
        );
      },
    );
  }
}
