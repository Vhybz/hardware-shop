import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../services/user_provider.dart';
import '../widgets/main_app_bar.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_sidebar.dart';
import '../services/menu_service.dart';
import '../widgets/role_pop_scope.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());

    final isDesktop = ResponsiveLayout.isDesktop(context);
    const currentRoute = '/about';
    final menuItems = ref.watch(menuItemsProvider);
    final theme = Theme.of(context);

    return RolePopScope(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const MainAppBar(title: 'About System'),
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
            Expanded(
              child: SafeArea(
                top: false, // AppBar handles the top
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.l,
                  ),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAppSection(context),
                          const SizedBox(height: AppSpacing.xl),
                          _buildDeveloperSection(context, user),
                          const SizedBox(height: AppSpacing.xl),
                          _buildFooter(context),
                          // Extra space at the very bottom to ensure navigation bar 
                          // doesn't feel cramped even with SafeArea
                          const SizedBox(height: AppSpacing.l),
                        ],
                      ),
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

  Widget _buildAppSection(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: AppColors.primaryMaroon.withValues(alpha: 0.1), width: 2),
                    image: const DecorationImage(
                      image: AssetImage('assets/logo/logo.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Adom Mmoroso ENT.',
                        style: TextStyle(
                          fontSize: 28, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: -0.5,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Hardware (Wholesale & Retail)',
                        style: TextStyle(
                          fontSize: 14, 
                          color: AppColors.textLight, 
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'A Professional Management Ecosystem',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Adom Mmoroso ENT. POS is a full-stack digital solution meticulously crafted to solve the unique challenges of building materials, hardware retail, and inventory management. We bridge the gap between inventory tracking and simple, high-speed retail execution.',
              style: TextStyle(
                fontSize: 16, 
                height: 1.6, 
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildAppFeatureColumn([
                        'Verified Inventory Protection',
                        'Real-time Stock & Batch Tracking',
                        'Automated GRA Tax Engine',
                      ])),
                      const SizedBox(width: 24),
                      Expanded(child: _buildAppFeatureColumn([
                        'Multi-branch Global Sync',
                        'Comprehensive Debt Management',
                        'Digital Receipting & SMS Alerts',
                      ])),
                    ],
                  );
                }
                return _buildAppFeatureColumn([
                  'Verified Inventory Protection',
                  'Real-time Stock & Batch Tracking',
                  'Automated GRA Tax Engine',
                  'Multi-branch Global Sync',
                  'Comprehensive Debt Management',
                  'Digital Receipting & SMS Alerts',
                ]);
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Location: Zongo One Way, Sunyani, Ghana',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 10),
                      const Text(
                        'Tel: 0542 181 580 / 0246 046 310',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppFeatureColumn(List<String> features) {
    return Column(
      children: features.map((f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.accentGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                f, 
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildDeveloperSection(BuildContext context, user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          
          final developerInfo = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THE ARCHITECT',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 3),
              ),
              const SizedBox(height: 12),
              Text(
                'Clifford Kyeremeh',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1),
              ),
              const Text(
                'Lead Software Engineer & System Architect',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Personal Mission:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '"My objective with Adom Mmoroso ENT. POS was to create a system that doesn\'t just record data, but actively protects and grows the business. I believe that engineering excellence should be invisible—allowing the business to operate with absolute precision while the staff focuses on quality service."',
                style: TextStyle(color: Colors.white70, height: 1.6, fontSize: 15, fontStyle: FontStyle.italic),
              ),
            ],
          );

          final developerImage = Center(
            child: Container(
              width: isMobile ? 180 : 240,
              height: isMobile ? 220 : 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(color: Colors.white12, width: 4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.m - 4),
                child: Image.asset(
                  'assets/images/CLI.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.person_rounded, color: Colors.white24, size: 80),
                    );
                  },
                ),
              ),
            ),
          );

          if (isMobile) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  developerImage,
                  const SizedBox(height: 32),
                  developerInfo,
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl * 1.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: developerInfo),
                const SizedBox(width: 48),
                Expanded(flex: 2, child: developerImage),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: () => _showTermsDialog(context),
            icon: const Icon(Icons.gavel_rounded, size: 16),
            label: const Text('Terms of Use & User Agreement'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'ADOM MMOROSO ENT. POS v2.1.0-STABLE',
            style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          const Text(
            'Engineered with excellence for modern commerce.',
            style: TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
          const SizedBox(height: 4),
          const Text(
            '© 2024. All Rights Reserved.',
            style: TextStyle(fontSize: 10, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: AppColors.primaryMaroon),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Terms of Use & User Agreement',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '1. Acceptance of Terms',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'By accessing, logging into, or using the Adom Mmoroso ENT. Point of Sale (POS) System ("System"), you agree to be bound by these Terms of Use, User Agreement, and Data Confidentiality policies. If you do not agree, you must not use the System.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: Colors.black87),
                ),
                SizedBox(height: 12),
                Text(
                  '2. Authorized Access & Account Security',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'The System is strictly intended for authorized employees, cashiers, and administrators of Adom Mmoroso ENT. You are fully responsible for maintaining the confidentiality of your account credentials, passcode, and PIN. Sharing login credentials or PINs is strictly prohibited and constitutes a security violation.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: Colors.black87),
                ),
                SizedBox(height: 12),
                Text(
                  '3. Inventory & Financial Accountability',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'Cashiers and staff members are accountable for accurate cash drawer reconciliation, sales transactions, shift check-ins, and stock verifications recorded under their user session. Tampering with stock records, debt logs, or financial figures is a violation of employment and system terms.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: Colors.black87),
                ),
                SizedBox(height: 12),
                Text(
                  '4. Data Privacy & Confidentiality',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'Customer contact data and sales records are processed securely and must be treated with absolute confidentiality in accordance with business compliance standards and privacy protection laws.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: Colors.black87),
                ),
                SizedBox(height: 12),
                Text(
                  '5. Intellectual Property',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'All source code, database architecture, UI/UX design, and branding associated with the System are the intellectual property of techRaven (Clifford Kyeremeh) and Adom Mmoroso ENT. Unauthorized copying, reverse engineering, or redistribution is strictly prohibited.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: Colors.black87),
                ),
                SizedBox(height: 12),
                Text(
                  '6. Limitation of Liability',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'The developer, system architects, and management assume no liability for financial discrepancies, data loss, or unauthorized access resulting from compromised user PINs, shared credentials, or offline synchronization conflicts.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}
