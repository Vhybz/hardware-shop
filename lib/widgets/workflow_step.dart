import 'package:flutter/material.dart';
import '../core/constants.dart';

class WorkflowStep extends StatelessWidget {
  final String label;
  final String count;
  final IconData icon;
  final bool isActive;

  const WorkflowStep({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive 
                ? AppColors.primaryMaroon 
                : (isDark ? Colors.white10 : AppColors.surfaceWhite),
            shape: BoxShape.circle,
            border: Border.all(color: isDark ? Colors.white12 : AppColors.borderGray),
          ),
          child: Icon(
            icon,
            color: isActive 
                ? Colors.white 
                : (isDark ? Colors.white60 : AppColors.textLight),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : AppColors.textDark,
          ),
        ),
        Text(
          count,
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
