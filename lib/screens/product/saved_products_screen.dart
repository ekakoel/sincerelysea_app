import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/screens/product/product_detail_screen.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';
import 'package:sincerelysea/widgets/product_card.dart';

class SavedProductsScreen extends StatelessWidget {
  const SavedProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = context.read<WishlistService>().currentUserId;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view saved products.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Products')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<WishlistService>().getWishlistStream(uid),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load saved products: ${snapshot.error}'),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> productDocs =
              (snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  .where(
                    (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                        doc.data()['type']?.toString() == 'product' &&
                        doc.data()['productId']?.toString().trim().isNotEmpty ==
                            true,
                  )
                  .toList(growable: false);

          if (productDocs.isEmpty) {
            return const Center(child: Text('No saved products yet.'));
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${productDocs.length} saved product${productDocs.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: productDocs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> wishlistData =
                        productDocs[index].data();
                    final String productId =
                        wishlistData['productId']?.toString() ?? '';
                    return FutureBuilder<Product?>(
                      future: context.read<ProductService>().getProductOnce(productId),
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<Product?> productSnapshot,
                      ) {
                        final Product? product = productSnapshot.data;
                        if (product == null) {
                          return _UnavailableSavedProductCard(
                            title: wishlistData['title']?.toString() ?? 'Product',
                            imageUrl:
                                wishlistData['productImageUrl']?.toString() ?? '',
                            price: wishlistData['productPrice'] is num
                                ? (wishlistData['productPrice'] as num).toDouble()
                                : 0,
                            onRemove: () => _removeWishlist(context, productId),
                          );
                        }

                        return ProductCard(
                          product: product,
                          isWishlisted: true,
                          onWishlistTap: () => _removeWishlist(context, product.id),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ProductDetailScreen(productId: product.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeWishlist(BuildContext context, String productId) async {
    try {
      await context.read<WishlistService>().removeProductWishlist(productId);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from saved products')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update saved products: $e')),
      );
    }
  }
}

class _UnavailableSavedProductCard extends StatelessWidget {
  const _UnavailableSavedProductCard({
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.onRemove,
  });

  final String title;
  final String imageUrl;
  final double price;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: imageUrl.trim().isEmpty
                  ? Container(
                      color: AppColors.gray200,
                      child: const Center(
                        child: Icon(Icons.inventory_2_outlined),
                      ),
                    )
                  : AppCheckCachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: AppColors.gray200,
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Product unavailable',
                  style: TextStyle(
                    color: AppColors.gray700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onRemove,
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
