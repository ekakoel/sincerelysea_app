import 'package:flutter/material.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.compact = false,
    this.isWishlisted = false,
    this.onWishlistTap,
  });

  final Product product;
  final VoidCallback onTap;
  final bool compact;
  final bool isWishlisted;
  final VoidCallback? onWishlistTap;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = product.images.isNotEmpty ? product.images.first : '';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray300),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                AspectRatio(
                  aspectRatio: compact ? 1.2 : 1.05,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: imageUrl.isEmpty
                        ? Container(
                            color: AppColors.gray200,
                            child: const Icon(Icons.inventory_2_outlined),
                          )
                        : AppCheckCachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: Container(
                              color: AppColors.gray200,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            error: Container(
                              color: AppColors.gray200,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                  ),
                ),
                if (onWishlistTap != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onWishlistTap,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isWishlisted ? Icons.favorite : Icons.favorite_border,
                            color: isWishlisted ? Colors.red : AppColors.gray700,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      if (product.category.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            product.category,
                            style: TextStyle(
                              color: AppColors.gray700,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: product.isPreorder
                              ? Colors.orange.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          product.inventoryLabel,
                          style: TextStyle(
                            color: product.isPreorder
                                ? Colors.orange.shade800
                                : Colors.green.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.name,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrency(product.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.isPreorder
                        ? (product.preorderDays > 0
                              ? 'Ships in about ${product.preorderDays} day(s)'
                              : 'Made to order')
                        : (product.inStock
                              ? 'Stock: ${product.stock}'
                              : 'Out of stock'),
                    style: TextStyle(
                      color: product.canPurchase ? AppColors.gray700 : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}
