import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'app_cached_image.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final String category;
  final String price;
  final String? originalPrice;
  final double? stockQuantity;
  final bool isUnlimited;
  final double? lowStockThreshold;
  final String? unit;
  final String? size;
  final String imageUrl;
  final String? promoLabel;
  final bool isInTransit;
  final double? dispatchedQuantity;
  final bool isDispatchedFromWarehouse;
  final double? cartQuantity;
  final double? refundedQuantity;
  final double? swappedQuantity;
  final bool allowRetail;
  final bool allowWholesale;
  final bool isDisabledMode;
  final String? modeDisabledLabel;
  final VoidCallback onTap;
  final VoidCallback? onQuickAdd;

  const ProductCard({
    super.key,
    required this.name,
    required this.category,
    required this.price,
    this.originalPrice,
    this.stockQuantity,
    this.isUnlimited = false,
    this.lowStockThreshold,
    this.unit,
    this.size,
    this.promoLabel,
    this.isInTransit = false,
    this.dispatchedQuantity,
    this.isDispatchedFromWarehouse = false,
    this.cartQuantity,
    this.refundedQuantity,
    this.swappedQuantity,
    this.allowRetail = true,
    this.allowWholesale = true,
    this.isDisabledMode = false,
    this.modeDisabledLabel,
    required this.imageUrl,
    required this.onTap,
    this.onQuickAdd,
  });

  Widget _buildProductImageWidget(BuildContext context) {
    String path = imageUrl.trim();

    if (path.isEmpty || 
        path.toLowerCase().contains('cos') || 
        (path.startsWith('assets/images/') && !path.substring(14).contains('/'))) {
      return _buildTextureFallbackImage();
    }

    return Container(
      color: Colors.white,
      child: AppCachedImage(
        imageUrl: path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context) => _buildTextureFallbackImage(),
      ),
    );
  }

  Widget _buildTextureFallbackImage() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Low opacity textured background
          Opacity(
            opacity: 0.22,
            child: Image.asset(
              'assets/images/bgi/sttt.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFF1F5F9),
              ),
            ),
          ),
          // Central Hardware Emblem Badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.construction_rounded,
              size: 26,
              color: Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  static String _getFallbackCategoryAsset(String catName, String prodName) {
    return 'assets/logo/logo.jpg';
  }

  Widget _buildErrorIcon(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.image, color: Theme.of(context).dividerColor),
    );
  }

  Widget _buildFormattedName(String name, TextStyle baseStyle) {
    if (!name.contains('(')) {
      return Text(name, style: baseStyle, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    final int splitIndex = name.lastIndexOf('(');
    final String mainName = name.substring(0, splitIndex).trim();
    final String range = name.substring(splitIndex).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(mainName, style: baseStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(range, 
          style: baseStyle.copyWith(
            fontSize: baseStyle.fontSize! - 2, 
            color: Colors.orange.shade800,
            fontWeight: FontWeight.bold,
          ), 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
      ],
    );
  }

  Color _getBackgroundColorForSize(String? size, bool isDark) {
    if (size == null || size.isEmpty) return isDark ? Colors.grey.shade900 : Colors.white;
    final s = size.toLowerCase();
    
    // Group sizes and assign soft background colors
    if (s.contains('small') || s.contains('sm') || s.contains('mini') || s.contains('50ml')) {
      return isDark ? Colors.green.shade900.withValues(alpha: 0.15) : Colors.green.shade50;
    } else if (s.contains('medium') || s.contains('md') || s.contains('100ml') || s.contains('200ml')) {
      return isDark ? Colors.blue.shade900.withValues(alpha: 0.15) : Colors.blue.shade50;
    } else if (s.contains('large') || s.contains('lg') || s.contains('big') || s.contains('400ml') || s.contains('500ml')) {
      return isDark ? Colors.purple.shade900.withValues(alpha: 0.15) : Colors.purple.shade50;
    } else if (s.contains('xl') || s.contains('jumbo') || s.contains('1000ml') || s.contains('1l')) {
      return isDark ? Colors.orange.shade900.withValues(alpha: 0.15) : Colors.orange.shade50;
    }
    
    // Default variation based on string hash for other sizes
    final colors = isDark 
      ? [
          Colors.red.shade900.withValues(alpha: 0.15), 
          Colors.teal.shade900.withValues(alpha: 0.15), 
          Colors.brown.shade900.withValues(alpha: 0.15), 
          Colors.indigo.shade900.withValues(alpha: 0.15)
        ]
      : [
          Colors.red.shade50, 
          Colors.teal.shade50, 
          Colors.brown.shade50, 
          Colors.indigo.shade50
        ];
        
    return colors[s.hashCode.abs() % colors.length];
  }

  Color _getBadgeColorForSize(String? size) {
    if (size == null || size.isEmpty) return Colors.blue.shade700;
    final s = size.toLowerCase();
    
    if (s.contains('small') || s.contains('sm') || s.contains('mini') || s.contains('50ml')) {
      return Colors.green.shade700;
    } else if (s.contains('medium') || s.contains('md') || s.contains('100ml') || s.contains('200ml')) {
      return Colors.blue.shade700;
    } else if (s.contains('large') || s.contains('lg') || s.contains('big') || s.contains('400ml') || s.contains('500ml')) {
      return Colors.purple.shade700;
    } else if (s.contains('xl') || s.contains('jumbo') || s.contains('1000ml') || s.contains('1l')) {
      return Colors.orange.shade800;
    }
    
    final colors = [
      Colors.red.shade700, 
      Colors.teal.shade700, 
      Colors.brown.shade700, 
      Colors.indigo.shade700
    ];
    return colors[s.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isOutOfStock = !isUnlimited && stockQuantity != null && stockQuantity! <= 0;
    final bool isInCart = cartQuantity != null && cartQuantity! > 0;

    BorderSide borderSide = isDark ? BorderSide(color: theme.dividerColor) : BorderSide.none;
    
    if (isInCart) {
      borderSide = const BorderSide(color: Colors.green, width: 2.5);
    } else if (isDispatchedFromWarehouse || (dispatchedQuantity != null && dispatchedQuantity! > 0)) {
      borderSide = const BorderSide(color: Colors.blue, width: 2.5);
    } else if (!isUnlimited && stockQuantity != null) {
      if (stockQuantity! <= 0) {
        borderSide = const BorderSide(color: Colors.red, width: 2);
      } else if (stockQuantity! <= (lowStockThreshold ?? 5.0)) {
        borderSide = const BorderSide(color: Colors.orange, width: 2);
      }
    }

    Widget cardWidget = Card(
      clipBehavior: Clip.antiAlias,
      elevation: isInCart ? 4 : (isDark ? 3 : 1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        side: borderSide,
      ),
      child: InkWell(
        onTap: isDisabledMode ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildProductImageWidget(context),
                  // Disabled Mode Overlay (e.g. Retail Only in Wholesale mode or vice-versa)
                  if (isDisabledMode)
                    Container(
                      color: Colors.black.withValues(alpha: 0.65),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber, width: 1),
                          ),
                          child: Text(
                            modeDisabledLabel ?? (!allowRetail ? 'WHOLESALE ONLY' : 'RETAIL ONLY'),
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Out of Stock Dark Overlay
                  if (isOutOfStock && !isDisabledMode)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                            ],
                          ),
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Promo Label
                  if (promoLabel != null && !isOutOfStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          promoLabel!,
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  // In Cart Badge (Top-Left if no Promo or stacked below)
                  if (isInCart)
                    Positioned(
                      top: promoLabel != null ? 28 : 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart, color: Colors.white, size: 11),
                            const SizedBox(width: 4),
                            Text(
                              '${cartQuantity! % 1 == 0 ? cartQuantity!.toInt() : cartQuantity!.toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Stock Status Badge (Top-Right)
                  if (stockQuantity != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isUnlimited
                                  ? Colors.blue
                                  : (stockQuantity! > 0
                                      ? (stockQuantity! <= (lowStockThreshold ?? 5.0) ? Colors.orange : Colors.green)
                                      : Colors.red))
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isUnlimited ? 'UNLIMITED' : '${stockQuantity!.toInt()}${unit ?? "pcs"}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  // Sales Mode Restriction Tag (Retail Only / Wholesale Only)
                  if (!isDisabledMode && (!allowRetail || !allowWholesale))
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: !allowRetail ? Colors.amber.shade900 : Colors.teal.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          !allowRetail ? 'Wholesale Only' : 'Retail Only',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  // Refunded / Returned to Stock Badge
                  if (refundedQuantity != null && refundedQuantity! > 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade800,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.assignment_return_rounded, color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              '+${refundedQuantity! % 1 == 0 ? refundedQuantity!.toInt() : refundedQuantity!.toStringAsFixed(1)} Refunded',
                              style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Swapped Out Badge
                  if (swappedQuantity != null && swappedQuantity! > 0)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade800,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              'Swapped (-${swappedQuantity! % 1 == 0 ? swappedQuantity!.toInt() : swappedQuantity!.toStringAsFixed(1)})',
                              style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // In Transit Overlay
                  if (isInTransit)
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_shipping, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'IN TRANSIT',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: _getBackgroundColorForSize(size, isDark),
              padding: const EdgeInsets.all(6.0), // reduced padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10, // reduced
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (size != null && size!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: _getBadgeColorForSize(size),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            size!.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  _buildFormattedName(name, TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 11, // reduced
                    color: theme.colorScheme.onSurface,
                  )),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Text(
                                price,
                                style: TextStyle(
                                  color: promoLabel != null 
                                    ? Colors.orange.shade800 
                                    : theme.colorScheme.onSurface,
                                  fontSize: 11, // reduced
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (originalPrice != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  originalPrice!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 9,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (onQuickAdd != null && !isOutOfStock)
                        InkWell(
                          onTap: onQuickAdd,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                  if (dispatchedQuantity != null && dispatchedQuantity! > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 10, color: Colors.blue.shade700),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '+${dispatchedQuantity! % 1 == 0 ? dispatchedQuantity!.toInt() : dispatchedQuantity!.toStringAsFixed(1)} ${unit ?? "pcs"} added',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isDisabledMode) {
      return Opacity(
        opacity: 0.45,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
