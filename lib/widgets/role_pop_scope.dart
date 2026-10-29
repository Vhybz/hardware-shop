import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_provider.dart';
import '../models/user_model.dart';

class RolePopScope extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const RolePopScope({
    super.key, 
    required this.child, 
    required this.currentRoute
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final String homeRoute = _getHomeRoute(user);
        
        // If we are already at the home route, we might want to confirm exit
        // or just let it close if that's the desired behavior.
        // But per user request "dont close app", we stay on home or confirm.
        if (currentRoute == homeRoute) {
          final bool? exit = await _showExitConfirmation(context);
          if (exit ?? false) {
            // If user confirms exit, we can allow the pop or just minimize app
            // In Flutter, to actually close the app on Android:
            // Navigator.of(context).pop(result); // This doesn't work if canPop is false
            // Usually we use SystemNavigator.pop()
          }
        } else {
          // Go back to the specific homepage for this user role
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, homeRoute);
          }
        }
      },
      child: child,
    );
  }

  String _getHomeRoute(UserAccount? user) {
    if (user == null) return '/login';
    
    switch (user.activePrimaryRole) {
      case UserRole.admin:
      case UserRole.superAdmin:
        return '/admin';
      case UserRole.cashier:
        return '/cashier';
    }
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Adom Mmoroso ENT. POS?'),
        content: const Text('Are you sure you want to close the application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('EXIT'),
          ),
        ],
      ),
    );
  }
}
