import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/config/official_store.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/screens/product/product_detail_screen.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/widgets/product_card.dart';
import 'package:sincerelysea/widgets/customer_state_view.dart';

class OfficialStoreScreen extends StatefulWidget {
  const OfficialStoreScreen({super.key});

  @override
  State<OfficialStoreScreen> createState() => _OfficialStoreScreenState();
}

class _OfficialStoreScreenState extends State<OfficialStoreScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(OfficialStore.name)),
      body: FutureBuilder<List<Product>>(
        future: context.read<ProductService>().getOfficialStoreProducts(),
        builder: (BuildContext context, AsyncSnapshot<List<Product>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return CustomerStateView(
              icon: Icons.cloud_off_outlined,
              title: 'Store unavailable',
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => setState(() {}),
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
                        _OfficialStoreHeader(productCount: products.length),
                        const SizedBox(height: 24),
                        const Center(
                          child: Text(
                            'No products are available in this store yet.',
                          ),
                        ),
                      ],
                    );
                  }
                  return CustomScrollView(
                    slivers: <Widget>[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: _OfficialStoreHeader(
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
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update saved products. Please try again.'),
        ),
      );
    }
  }
}

class _OfficialStoreHeader extends StatelessWidget {
  const _OfficialStoreHeader({required this.productCount});

  final int productCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  OfficialStore.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const _StoreRoleBadge(label: 'OFFICIAL'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Official SincerelySea Store',
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
