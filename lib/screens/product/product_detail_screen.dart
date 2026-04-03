import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/screens/cart/cart_screen.dart';
import 'package:sincerelysea/screens/checkout/checkout_screen.dart';
import 'package:sincerelysea/screens/product/seller_storefront_screen.dart';
import 'package:sincerelysea/services/cart_service.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentImageIndex = 0;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final ProductService productService = context.read<ProductService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: <Widget>[
          StreamBuilder<bool>(
            stream: context.read<WishlistService>().isProductWishlistedStream(
              widget.productId,
            ),
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              final bool isWishlisted = snapshot.data ?? false;
              return IconButton(
                tooltip: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
                onPressed: () => _toggleWishlist(isWishlisted),
                icon: Icon(
                  isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: isWishlisted ? Colors.red : null,
                ),
              );
            },
          ),
          StreamBuilder<int>(
            stream: context.read<CartService>().cartItemCountStream(),
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              final int totalItems = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Cart',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CartScreen(),
                    ),
                  );
                },
                icon: Badge(
                  isLabelVisible: totalItems > 0,
                  label: Text(totalItems > 99 ? '99+' : '$totalItems'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: productService.getProduct(widget.productId),
        builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load product: ${snapshot.error}'),
            );
          }
          if (!(snapshot.data?.exists ?? false)) {
            return const Center(child: Text('Product not found.'));
          }

          final Product product = Product.fromFirestore(snapshot.data!);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              _buildCarousel(product),
              const SizedBox(height: 16),
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (product.category.trim().isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      product.category,
                      style: TextStyle(
                        color: AppColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (product.category.trim().isNotEmpty) const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                product.description.isEmpty
                    ? 'No product description.'
                    : product.description,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 16),
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(product.userId)
                    .get(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> seller,
                ) {
                  final Map<String, dynamic> data =
                      seller.data?.data() ?? <String, dynamic>{};
                  final bool isAdmin =
                      product.managedByAdmins ||
                      data['role']?.toString().trim().toLowerCase() == 'admin';
                  final String sellerName = product.storeName;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.storefront_outlined),
                    ),
                    title: Row(
                      children: <Widget>[
                        const Text('Store'),
                        if (isAdmin) ...<Widget>[
                          const SizedBox(width: 8),
                          const _RoleBadge(label: 'ADMIN'),
                        ],
                      ],
                    ),
                    subtitle: Text('$sellerName\nTap to view the official store'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: product.ownerId.trim().isEmpty
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SellerStorefrontScreen(
                                  sellerUserId: product.ownerId,
                                  sellerName: sellerName,
                                ),
                              ),
                            );
                          },
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                product.isPreorder
                    ? (product.preorderDays > 0
                          ? 'Estimated ship in ${product.preorderDays} day(s)'
                          : 'Available via preorder')
                    : (product.inStock
                          ? 'Stock available: ${product.stock}'
                          : 'Out of stock'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: product.canPurchase ? AppColors.gray700 : Colors.red,
                ),
              ),
              if (product.isPreorder && product.preorderNote.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  product.preorderNote,
                  style: TextStyle(color: AppColors.gray700, height: 1.4),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting || !product.canPurchase
                          ? null
                          : () => _addToCart(product),
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Add to Cart'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: !product.canPurchase
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CheckoutScreen.buyNow(
                                    buyNowProduct: product,
                                  ),
                                ),
                              );
                            },
                      child: const Text('Buy Now'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleWishlist(bool isWishlisted) async {
    final ProductService productService = context.read<ProductService>();
    final WishlistService wishlistService = context.read<WishlistService>();
    try {
      final Product? product = await productService.getProductOnce(widget.productId);
      if (product == null) {
        throw Exception('Product not found.');
      }
      await wishlistService.toggleProductWishlist(product);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isWishlisted ? 'Removed from wishlist' : 'Added to wishlist',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update wishlist: $e')),
      );
    }
  }

  Widget _buildCarousel(Product product) {
    if (product.images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.gray200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: Icon(Icons.inventory_2_outlined)),
        ),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 320,
          child: PageView.builder(
            itemCount: product.images.length,
            onPageChanged: (int value) {
              setState(() => _currentImageIndex = value);
            },
            itemBuilder: (BuildContext context, int index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppCheckCachedNetworkImage(
                  imageUrl: product.images[index],
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
              );
            },
          ),
        ),
        if (product.images.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(product.images.length, (int index) {
              final bool active = index == _currentImageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: active ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? AppColors.black : AppColors.gray400,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Future<void> _addToCart(Product product) async {
    setState(() => _submitting = true);
    try {
      await context.read<CartService>().addToCart(productId: product.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to cart: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
