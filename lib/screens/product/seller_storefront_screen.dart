import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/screens/product/product_detail_screen.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/widgets/product_card.dart';

class SellerStorefrontScreen extends StatelessWidget {
  const SellerStorefrontScreen({
    super.key,
    required this.sellerUserId,
    required this.sellerName,
  });

  final String sellerUserId;
  final String sellerName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(sellerName)),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(sellerUserId)
            .get(),
        builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> sellerSnapshot,
        ) {
          if (sellerSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (sellerSnapshot.hasError) {
            return Center(
              child: Text('Failed to load seller profile: ${sellerSnapshot.error}'),
            );
          }

          final Map<String, dynamic> sellerData =
              sellerSnapshot.data?.data() ?? <String, dynamic>{};
          final bool isAdmin =
              sellerData['role']?.toString().trim().toLowerCase() == 'admin';

          return FutureBuilder<List<Product>>(
            future: context.read<ProductService>().getSellerProducts(sellerUserId),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<Product>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load seller products: ${snapshot.error}'),
                );
              }

              final List<Product> products = snapshot.data ?? <Product>[];
              return StreamBuilder<Set<String>>(
                stream: context.read<WishlistService>().productWishlistIdsStream(),
                builder:
                    (BuildContext context, AsyncSnapshot<Set<String>> wishlist) {
                      final Set<String> wishlistIds = wishlist.data ?? <String>{};
                      if (products.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          children: <Widget>[
                            _SellerHeader(
                              sellerName: sellerName,
                              username: sellerData['username']?.toString() ?? '',
                              isAdmin: isAdmin,
                              productCount: products.length,
                            ),
                            const SizedBox(height: 24),
                            const Center(
                              child: Text('This seller has no products yet.'),
                            ),
                          ],
                        );
                      }
                      return CustomScrollView(
                        slivers: <Widget>[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              child: _SellerHeader(
                                sellerName: sellerName,
                                username:
                                    sellerData['username']?.toString() ?? '',
                                isAdmin: isAdmin,
                                productCount: products.length,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate((
                                BuildContext context,
                                int index,
                              ) {
                                final Product product = products[index];
                                final bool isWishlisted = wishlistIds.contains(
                                  product.id,
                                );
                                return ProductCard(
                                  product: product,
                                  isWishlisted: isWishlisted,
                                  onWishlistTap: () => _toggleWishlist(
                                    context,
                                    product,
                                    isWishlisted,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ProductDetailScreen(
                                          productId: product.id,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }, childCount: products.length),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.72,
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleWishlist(
    BuildContext context,
    Product product,
    bool isWishlisted,
  ) async {
    try {
      await context.read<WishlistService>().toggleProductWishlist(product);
      if (!context.mounted) {
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
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update wishlist: $e')),
      );
    }
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({
    required this.sellerName,
    required this.username,
    required this.isAdmin,
    required this.productCount,
  });

  final String sellerName;
  final String username;
  final bool isAdmin;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  sellerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isAdmin) const _StoreRoleBadge(label: 'ADMIN'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            username.trim().isEmpty ? 'Seller storefront' : '@$username',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 10),
          Text(
            '$productCount product${productCount == 1 ? '' : 's'} available',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StoreRoleBadge extends StatelessWidget {
  const _StoreRoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
