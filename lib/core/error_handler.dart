import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  /// Displays a friendly, non-intrusive SnackBar notification with an optional RETRY action.
  static void handleError(
    BuildContext context,
    Object error, {
    VoidCallback? onRetry,
    String? customMessage,
  }) {
    if (!context.mounted) return;

    debugPrint('Global Error Handler caught: $error');

    String displayMessage = customMessage ?? _parseErrorMessage(error);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayMessage,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'RETRY',
                textColor: Colors.amberAccent,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Parses technical exceptions into friendly human-readable messages.
  static String _parseErrorMessage(Object error) {
    if (error is PostgrestException) {
      if (error.code == 'PGRST200') {
        return 'Connecting to database... Please check your internet connection.';
      }
      if (error.code == '42501') {
        return 'Access denied. You do not have required permissions.';
      }
      return 'Database connection issue: ${error.message}';
    }
    
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('connection failed')) {
      return 'Network connection weak. Please check your mobile data or Wi-Fi.';
    }
    if (errStr.contains('timeout')) {
      return 'Request timed out. Please tap RETRY.';
    }

    return 'An unexpected issue occurred. Please try again.';
  }
}
