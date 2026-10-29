import 'package:flutter/material.dart';
import '../core/constants.dart';

class SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const SummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor ?? (isDark ? Colors.white60 : AppColors.textLight)),
          const SizedBox(width: 8),
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              color: isDark ? Colors.white60 : AppColors.textLight
            ),
          ),
          const Spacer(),
          Text(
            value, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
