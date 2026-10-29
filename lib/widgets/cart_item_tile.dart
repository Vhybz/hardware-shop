import 'package:flutter/material.dart';
import 'hold_to_repeat_button.dart';

class CartItemTile extends StatelessWidget {
  final String name;
  final String? category;
  final String qty;
  final String weight;
  final String amount;
  final VoidCallback onDelete;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onQuantityTap;

  const CartItemTile({
    super.key,
    required this.name,
    this.category,
    required this.qty,
    required this.weight,
    required this.amount,
    required this.onDelete,
    this.onIncrement,
    this.onDecrement,
    this.onQuantityTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.18)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Category Tag + Full Product Name + Delete Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category != null && category!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Text(
                            category!.toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.error.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Row 2: Quantity Stepper (- 1 +) | Weight/Unit | Item Total Price (GHS)
            Row(
              children: [
                // Stepper
                if (onDecrement != null && onIncrement != null)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HoldToRepeatButton(
                          onPressed: onDecrement,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                          child: Icon(Icons.remove_rounded, size: 16, color: theme.colorScheme.primary),
                        ),
                        InkWell(
                          onTap: onQuantityTap,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: Text(
                              qty,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        HoldToRepeatButton(
                          onPressed: onIncrement,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                          child: Icon(Icons.add_rounded, size: 16, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  weight,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  amount,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
