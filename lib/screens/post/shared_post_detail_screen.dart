import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/screens/product/product_detail_screen.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/post_service.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/utils/post_location_label.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';
import 'package:sincerelysea/widgets/product_card.dart';
import 'package:sincerelysea/widgets/customer_state_view.dart';

class SharedPostDetailScreen extends StatefulWidget {
  const SharedPostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<SharedPostDetailScreen> createState() => _SharedPostDetailScreenState();
}

class _SharedPostDetailScreenState extends State<SharedPostDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final PostService postService = context.read<PostService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Shared Post')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: postService.getPost(widget.postId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return CustomerStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Post unavailable',
                  message:
                      'This post may be private, deleted, or temporarily unavailable.',
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }
              final Map<String, dynamic>? data = snapshot.data?.data();
              if (data == null) {
                return const CustomerStateView(
                  icon: Icons.article_outlined,
                  title: 'Post not found',
                  message:
                      'This post may have been deleted or is no longer accessible.',
                );
              }

              final String username =
                  data['username']?.toString() ?? 'Anonymous';
              final String content = data['content']?.toString() ?? '';
              final String imageUrl = data['imageUrl']?.toString() ?? '';
              final String location = data['location']?.toString() ?? '-';
              final List<dynamic> hashtags =
                  data['hashtags'] as List<dynamic>? ?? <dynamic>[];
              final int likeCount =
                  (data['likes'] as List<dynamic>? ?? <dynamic>[]).length;
              final int commentCount = data['commentCount'] as int? ?? 0;
              final int shareCount = data['shareCount'] as int? ?? 0;
              final String postType = data['type']?.toString() ?? 'post';
              final String productId = data['productId']?.toString() ?? '';
              final bool isProductPost =
                  postType == 'product' && productId.isNotEmpty;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppCheckCachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: AppColors.gray200,
                          height: 260,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: Container(
                          color: AppColors.gray200,
                          height: 260,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    content.isEmpty ? 'No caption' : content,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<String>(
                    future: resolvePostLocationLabel(data),
                    builder:
                        (BuildContext context, AsyncSnapshot<String> snapshot) {
                          final String resolved =
                              snapshot.data?.trim().isNotEmpty == true
                              ? snapshot.data!.trim()
                              : location;
                          return Text(
                            'Location: $resolved',
                            style: TextStyle(color: AppColors.gray700),
                          );
                        },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: hashtags
                        .map(
                          (dynamic tag) => Text(
                            tag.toString(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  if (isProductPost)
                    FutureBuilder<Product?>(
                      future: context.read<ProductService>().getProductOnce(
                        productId,
                      ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<Product?> productSnapshot,
                          ) {
                            if (productSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final Product? product = productSnapshot.data;
                            if (productSnapshot.hasError || product == null) {
                              return const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(14),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(Icons.inventory_2_outlined),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'The linked product is no longer available.',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return StreamBuilder<bool>(
                              stream: context
                                  .read<WishlistService>()
                                  .isProductWishlistedStream(product.id),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<bool> wishlistSnapshot,
                                  ) {
                                    final bool isWishlisted =
                                        wishlistSnapshot.data ?? false;
                                    return Column(
                                      children: <Widget>[
                                        ProductCard(
                                          product: product,
                                          compact: true,
                                          isWishlisted: isWishlisted,
                                          onWishlistTap: () => _toggleWishlist(
                                            context,
                                            product,
                                            isWishlisted,
                                          ),
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    ProductDetailScreen(
                                                      productId: product.id,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      ProductDetailScreen(
                                                        productId: product.id,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: const Text('View Product'),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                            );
                          },
                    ),
                  if (isProductPost) const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      _MetricChip(label: 'Likes', value: likeCount),
                      const SizedBox(width: 8),
                      _MetricChip(label: 'Comments', value: commentCount),
                      const SizedBox(width: 8),
                      _MetricChip(label: 'Shares', value: shareCount),
                    ],
                  ),
                ],
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

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.gray700),
            ),
          ],
        ),
      ),
    );
  }
}
