import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/models/product_review.dart';
import 'package:sincerelysea/screens/cart/cart_screen.dart';
import 'package:sincerelysea/screens/checkout/checkout_screen.dart';
import 'package:sincerelysea/screens/product/official_store_screen.dart';
import 'package:sincerelysea/screens/reviews/review_editor_screen.dart';
import 'package:sincerelysea/services/cart_service.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/services/review_service.dart';
import 'package:sincerelysea/services/wishlist_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';
import 'package:sincerelysea/widgets/customer_state_view.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

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
                tooltip: isWishlisted
                    ? 'Remove from wishlist'
                    : 'Add to wishlist',
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
                    MaterialPageRoute<void>(builder: (_) => const CartScreen()),
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
                  title: 'Product is unavailable',
                  message: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }
              if (!(snapshot.data?.exists ?? false)) {
                return const CustomerStateView(
                  icon: Icons.inventory_2_outlined,
                  title: 'Product not found',
                  message: 'This product may no longer be available.',
                );
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
                  if (product.category.trim().isNotEmpty)
                    const SizedBox(height: 12),
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.storefront_outlined),
                    ),
                    title: const Row(
                      children: <Widget>[
                        Text('SincerelySea Store'),
                        SizedBox(width: 8),
                        _RoleBadge(label: 'OFFICIAL'),
                      ],
                    ),
                    subtitle: Text(
                      '${product.storeName}\nTap to view the official store',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: product.ownerId.trim().isEmpty
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const OfficialStoreScreen(),
                              ),
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
                      color: product.canPurchase
                          ? AppColors.gray700
                          : Colors.red,
                    ),
                  ),
                  if (product.isPreorder &&
                      product.preorderNote.trim().isNotEmpty) ...<Widget>[
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                  const SizedBox(height: 28),
                  _ProductReviewsSection(productId: product.id),
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
      final Product? product = await productService.getProductOnce(
        widget.productId,
      );
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your wishlist. Please try again.'),
        ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to cart')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add this product to your cart. Try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _ProductReviewsSection extends StatefulWidget {
  const _ProductReviewsSection({required this.productId});

  final String productId;

  @override
  State<_ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<_ProductReviewsSection> {
  final ReviewService _reviewService = ReviewService();
  late Stream<List<ProductReview>> _reviewsStream;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _reviewsStream = _reviewService.watchReviews(widget.productId);
  }

  @override
  void didUpdateWidget(covariant _ProductReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _reviewsStream = _reviewService.watchReviews(widget.productId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductReview>>(
      stream: _reviewsStream,
      builder:
          (BuildContext context, AsyncSnapshot<List<ProductReview>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Reviews',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 14),
                  LinearProgressIndicator(),
                ],
              );
            }
            if (snapshot.hasError) {
              return _ReviewErrorCard(onRetry: _restart);
            }

            final List<ProductReview> reviews =
                snapshot.data ?? const <ProductReview>[];
            final String? currentUserId = _reviewService.currentUserId;
            ProductReview? ownReview;
            if (currentUserId != null) {
              for (final ProductReview review in reviews) {
                if (review.userId == currentUserId) {
                  ownReview = review;
                  break;
                }
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Reviews',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      reviews.length.toString() +
                          (reviews.length == 1 ? ' review' : ' reviews'),
                      style: TextStyle(color: AppColors.gray700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (currentUserId != null)
                  if (ownReview == null)
                    FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Write a Review'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => _openEditor(review: ownReview),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Review'),
                        ),
                        TextButton.icon(
                          onPressed: _deleting
                              ? null
                              : () => _confirmDelete(ownReview!),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(
                            _deleting ? 'Deleting...' : 'Delete Review',
                          ),
                        ),
                      ],
                    ),
                const SizedBox(height: 14),
                if (reviews.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Column(
                      children: <Widget>[
                        Icon(Icons.reviews_outlined, size: 34),
                        SizedBox(height: 8),
                        Text(
                          'No reviews yet',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Be the first customer to share a product experience.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...reviews.map(
                    (ProductReview review) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ProductReviewCard(
                        review: review,
                        reviewService: _reviewService,
                      ),
                    ),
                  ),
              ],
            );
          },
    );
  }

  void _restart() {
    setState(() {
      _reviewsStream = _reviewService.watchReviews(widget.productId);
    });
  }

  Future<void> _openEditor({ProductReview? review}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewEditorScreen(
          productId: widget.productId,
          existingReview: review,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ProductReview review) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete review?'),
            content: const Text('This review will be removed permanently.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep Review'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete Review'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await _reviewService.deleteReview(widget.productId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your review. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }
}

class _ReviewErrorCard extends StatelessWidget {
  const _ReviewErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            const Icon(Icons.cloud_off_outlined, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Reviews are unavailable',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text('Check your connection and try again.'),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ProductReviewCard extends StatefulWidget {
  const _ProductReviewCard({required this.review, required this.reviewService});

  final ProductReview review;
  final ReviewService reviewService;

  @override
  State<_ProductReviewCard> createState() => _ProductReviewCardState();
}

class _ProductReviewCardState extends State<_ProductReviewCard> {
  late Future<ProductReviewAuthor> _authorFuture;

  @override
  void initState() {
    super.initState();
    _authorFuture = widget.reviewService.getPublicAuthor(widget.review.userId);
  }

  @override
  void didUpdateWidget(covariant _ProductReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.userId != widget.review.userId) {
      _authorFuture = widget.reviewService.getPublicAuthor(
        widget.review.userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FutureBuilder<ProductReviewAuthor>(
              future: _authorFuture,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<ProductReviewAuthor> snapshot,
                  ) {
                    final ProductReviewAuthor author =
                        snapshot.data ?? ProductReviewAuthor.fallback;
                    return Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 18,
                          child: Text(
                            author.displayName.substring(0, 1).toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                author.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (author.username.isNotEmpty &&
                                  author.username.toLowerCase() !=
                                      author.displayName.toLowerCase())
                                Text(
                                  '@${author.username}',
                                  style: TextStyle(
                                    color: AppColors.gray700,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          _formatReviewDate(
                            widget.review.updatedAt ?? widget.review.createdAt,
                          ),
                          style: TextStyle(
                            color: AppColors.gray700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
            ),
            const SizedBox(height: 10),
            Row(
              children: List<Widget>.generate(
                5,
                (int index) => Icon(
                  index < widget.review.rating ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.review.reviewText),
          ],
        ),
      ),
    );
  }
}

String _formatReviewDate(Timestamp? timestamp) {
  if (timestamp == null) {
    return 'Recently';
  }
  final DateTime value = timestamp.toDate().toLocal();
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
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
