import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/auth/password_recovery_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/sales_reports_screen.dart';
import 'screens/admin/debt_management_screen.dart';
import 'screens/admin/inventory_control_screen.dart';
import 'screens/admin/expense_management_screen.dart';
import 'screens/admin/customer_management_screen.dart';
import 'screens/admin/returns_screen.dart';
import 'screens/admin/staff_management_screen.dart';
import 'screens/admin/system_settings_screen.dart';
import 'screens/admin/recents_screen.dart';
import 'screens/admin/system_maintenance_screen.dart';
import 'screens/admin/tax_compliance_screen.dart';
import 'screens/admin/salary_management_screen.dart';
import 'screens/admin/audit_trail_screen.dart';
import 'screens/admin/product_activity_report_screen.dart';
import 'screens/admin/documents_screen.dart';
import 'screens/cashier/cashier_pos.dart';
import 'screens/cashier/stock_verification_screen.dart';
import 'screens/warehouse/warehouse_shell.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/about_screen.dart';
import 'services/theme_provider.dart';
import 'services/push_notification_service.dart';
import 'services/offline_sync_service.dart';
import 'services/pwa_install_service.dart';
import 'screens/admin/super_admin_screen.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    PwaInstallService.initialize();

    // 1. Load Environment Variables
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      try {
        await dotenv.load(fileName: "assets/.env");
      } catch (e) {
        debugPrint(
            'CRITICAL: .env could not be loaded. API features may fail: $e');
      }
    }

    if (kIsWeb) {
      usePathUrlStrategy();
    }

    // 2. Initialize Offline Engine (Hive) & Local Database
    await OfflineSyncService.initialize();

    // 3. Initialize Push Notifications (Graceful failure)
    try {
      await PushNotificationService.initialize();
    } catch (e) {
      debugPrint('Push Notification initialization failed: $e');
    }

    // Enable edge-to-edge support
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    runApp(
      const ProviderScope(
        child: AdomMmorosoApp(),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('BOOT CRITICAL EXCEPTION: $e\n$stackTrace');
    runApp(
      MaterialApp(
        home: BootErrorScreen(
          errorMessage: e.toString(),
          stackTrace: stackTrace.toString(),
        ),
      ),
    );
  }
}

class AdomMmorosoApp extends ConsumerWidget {
  const AdomMmorosoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Adom Mmoroso ENT. POS',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      theme: AppTheme.getLightTheme(themeState.primaryColor),
      darkTheme: AppTheme.getDarkTheme(themeState.primaryColor),
      themeMode: themeState.mode,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot-password': (context) => const PasswordRecoveryScreen(),
        '/admin': (context) => const AdminDashboard(),
        '/admin/dashboard': (context) => const AdminDashboard(),
        '/admin/reports': (context) => const SalesReportsScreen(),
        '/admin/sales': (context) => const SalesReportsScreen(),
        '/admin/debts': (context) => const DebtManagementScreen(),
        '/admin/inventory': (context) => const InventoryControlScreen(),
        '/admin/stock': (context) => const InventoryControlScreen(),
        '/admin/expenses': (context) => const ExpenseManagementScreen(),
        '/admin/customers': (context) => const CustomerManagementScreen(),
        '/admin/returns': (context) => const ReturnsScreen(),
        '/admin/staff': (context) => const StaffManagementScreen(),
        '/admin/system': (context) => const SystemSettingsScreen(),
        '/admin/settings': (context) => const SystemSettingsScreen(),
        '/admin/recents': (context) => const RecentsScreen(),
        '/admin/maintenance': (context) => const SystemMaintenanceScreen(),
        '/admin/tax': (context) => const TaxComplianceScreen(),
        '/admin/salaries': (context) => const SalaryManagementScreen(),
        '/admin/audit': (context) => const AuditTrailScreen(),
        '/admin/product-activity': (context) =>
            const ProductActivityReportScreen(),
        '/admin/product-report': (context) =>
            const ProductActivityReportScreen(),
        '/admin/documents': (context) => const DocumentsScreen(),
        '/cashier': (context) => const CashierPOS(),
        '/cashier/pos': (context) => const CashierPOS(),
        '/cashier/verify': (context) => const StockVerificationScreen(),
        '/warehouse': (context) => const WarehouseShell(),
        '/warehouse/goods': (context) => const WarehouseShell(),
        '/super_admin': (context) => const SuperAdminScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/about': (context) => const AboutScreen(),
      },
    );
  }
}

class BootErrorScreen extends StatelessWidget {
  final String? errorMessage;
  final String? stackTrace;

  const BootErrorScreen({super.key, this.errorMessage, this.stackTrace});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6B1111),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'SYSTEM INITIALIZATION FAILED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Technical Error: $errorMessage',
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (kIsWeb) {
                    // Refresh web page
                  }
                },
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
