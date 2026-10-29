import 'package:flutter/material.dart';
import '../core/constants.dart';

class KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String? subValue;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    this.subValue,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryNarrow = constraints.maxWidth < 130;

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: isVeryNarrow 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcon(),
                  const SizedBox(height: AppSpacing.s),
                  Expanded(child: _buildTextContent(context, isDark)),
                ],
              )
            : Row(
                children: [
                  _buildIcon(),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(child: _buildTextContent(context, isDark)),
                ],
              ),
          );
        },
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: iconBgColor,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  Widget _buildTextContent(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white60 : AppColors.textLight,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (subValue != null) ...[
          const SizedBox(height: 2),
          Text(
            subValue!,
            style: TextStyle(
              color: isDark ? Colors.white38 : AppColors.textLight,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
