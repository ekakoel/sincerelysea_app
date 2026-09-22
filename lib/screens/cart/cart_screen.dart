import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/cart_item.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/screens/checkout/checkout_screen.dart';
import 'package:sincerelysea/services/cart_service.dart';
import 'package:sincerelysea/services/product_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';
import 'package:sincerelysea/widgets/customer_state_view.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final CartService cartService = context.read<CartService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartService.cartStream(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return CustomerStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Cart unavailable',
                  message: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }

              final List<CartItem> items =
                  (snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      .map(CartItem.fromFirestore)
                      .where((CartItem item) => item.productId.isNotEmpty)
                      .toList(growable: false);

              if (items.isEmpty) {
                return const CustomerStateView(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  message:
                      'Products you add from SincerelySea Store will appear here.',
                );
              }

              return FutureBuilder<_CartLoadResult>(
                future: _loadEntries(context, items),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<_CartLoadResult> entriesSnapshot,
                    ) {
                      if (entriesSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (entriesSnapshot.hasError) {
                        return CustomerStateView(
                          icon: Icons.cloud_off_outlined,
                          title: 'Cart products unavailable',
                          message: 'Check your connection and try again.',
                          actionLabel: 'Retry',
                          onAction: () => setState(() {}),
                        );
                      }
                      final _CartLoadResult result =
                          entriesSnapshot.data ?? const _CartLoadResult.empty();
                      final List<_CartEntry> entries = result.entries;
                      final List<CartItem> unavailable =
                          result.unavailableItems;
                      final bool hasInvalidQuantity = entries.any(
                        (_CartEntry entry) =>
                            entry.cartItem.quantity <= 0 ||
                            (!entry.product.isPreorder &&
                                entry.cartItem.quantity > entry.product.stock),
                      );
                      final bool checkoutEnabled =
                          entries.isNotEmpty &&
                          unavailable.isEmpty &&
                          !hasInvalidQuantity &&
                          entries.every(
                            (_CartEntry entry) => entry.product.canPurchase,
                          );
                      final double total = entries.fold<double>(
                        0,
                        (double sum, _CartEntry entry) =>
                            sum +
                            (entry.product.price * entry.cartItem.quantity),
                      );

                      return Column(
                        children: <Widget>[
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: entries.length + unavailable.length,
                              separatorBuilder:
                                  (BuildContext context, int index) =>
                                      const SizedBox(height: 12),
                              itemBuilder: (BuildContext context, int index) {
                                if (index < entries.length) {
                                  return _CartItemTile(entry: entries[index]);
                                }
                                final CartItem item =
                                    unavailable[index - entries.length];
                                return _UnavailableCartItemTile(item: item);
                              },
                            ),
                          ),
                          SafeArea(
                            top: false,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                16,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: AppColors.gray300),
                                ),
                              ),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      const Expanded(
                                        child: Text(
                                          'Total',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '\$${total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (!checkoutEnabled) ...<Widget>[
                                    const Text(
                                      'Remove unavailable items or adjust quantities before checkout.',
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: !checkoutEnabled
                                          ? null
                                          : () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      const CheckoutScreen.cart(),
                                                ),
                                              );
                                            },
                                      child: const Text('Checkout'),
                                    ),
                                  ),
                                ],
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

  Future<_CartLoadResult> _loadEntries(
    BuildContext context,
    List<CartItem> items,
  ) async {
    final ProductService productService = context.read<ProductService>();
    final List<_CartEntry> entries = <_CartEntry>[];
    final List<CartItem> unavailableItems = <CartItem>[];
    for (final CartItem item in items) {
      final Product? product = await productService.getProductOnce(
        item.productId,
      );
      if (product == null || !product.canPurchase) {
        unavailableItems.add(item);
        continue;
      }
      entries.add(_CartEntry(cartItem: item, product: product));
    }
    return _CartLoadResult(
      entries: entries,
      unavailableItems: unavailableItems,
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.entry});

  final _CartEntry entry;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = entry.product.images.isNotEmpty
        ? entry.product.images.first
        : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 90,
              height: 90,
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
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${entry.product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          _updateQuantity(context, entry.cartItem.quantity - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      entry.cartItem.quantity.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          !entry.product.isPreorder &&
                              entry.cartItem.quantity >= entry.product.stock
                          ? null
                          : () => _updateQuantity(
                              context,
                              entry.cartItem.quantity + 1,
                            ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _remove(context),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateQuantity(BuildContext context, int quantity) async {
    try {
      await context.read<CartService>().updateQuantity(
        cartId: entry.cartItem.id,
        quantity: quantity,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update the cart. Please try again.'),
        ),
      );
    }
  }

  Future<void> _remove(BuildContext context) async {
    try {
      await context.read<CartService>().removeItem(entry.cartItem.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove this item. Please try again.'),
        ),
      );
    }
  }
}

class _UnavailableCartItemTile extends StatelessWidget {
  const _UnavailableCartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.inventory_2_outlined),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Product unavailable',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text('This saved cart item can no longer be purchased.'),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await context.read<CartService>().removeItem(item.id);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not remove this item. Please try again.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _CartEntry {
  const _CartEntry({required this.cartItem, required this.product});

  final CartItem cartItem;
  final Product product;
}

class _CartLoadResult {
  const _CartLoadResult({
    required this.entries,
    required this.unavailableItems,
  });

  const _CartLoadResult.empty()
    : entries = const <_CartEntry>[],
      unavailableItems = const <CartItem>[];

  final List<_CartEntry> entries;
  final List<CartItem> unavailableItems;
}
