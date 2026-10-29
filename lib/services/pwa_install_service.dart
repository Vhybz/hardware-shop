import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'offline_sync_service.dart';
import 'pwa_install/pwa_install_helper.dart';

class PwaInstallService {
  static void initialize() {
    if (!kIsWeb) return;

    try {
      initPwaInstallImpl();
      debugPrint('PWA Engine: Web App installation service initialized.');
    } catch (e) {
      debugPrint('PWA Init Warning: $e');
    }
  }

  static bool get canInstall {
    if (!kIsWeb) return false;
    return canInstallImpl();
  }

  static Future<bool> promptInstall() async {
    if (!kIsWeb) return false;
    return promptInstallImpl();
  }

  static Future<void> checkAndShowPrompt(BuildContext context) async {
    if (!kIsWeb) return;

    // Check if dismissed today
    try {
      if (Hive.isBoxOpen(OfflineSyncService.settingsBoxName)) {
        final box = Hive.box(OfflineSyncService.settingsBoxName);
        final bool dismissed = box.get('pwa_prompt_dismissed', defaultValue: false);
        if (dismissed) return;
      }
    } catch (_) {}

    // Give browser a short moment to fire beforeinstallprompt event
    await Future.delayed(const Duration(seconds: 2));

    if (!context.mounted) return;

    if (canInstall) {
      showInstallDialog(context);
    }
  }

  static void showInstallDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: AssetImage('favicon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Install Adom Mmoroso ENT. POS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Install for 100% offline access, fast launch, and full-screen POS mode.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final installed = await promptInstall();
                      if (installed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 App installed successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Install', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      try {
                        if (Hive.isBoxOpen(OfflineSyncService.settingsBoxName)) {
                          Hive.box(OfflineSyncService.settingsBoxName).put('pwa_prompt_dismissed', true);
                        }
                      } catch (_) {}
                    },
                    child: Text(
                      'Not Now',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
