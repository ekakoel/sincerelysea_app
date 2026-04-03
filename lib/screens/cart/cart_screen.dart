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

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CartService cartService = context.read<CartService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: cartService.cartStream(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load cart: ${snapshot.error}'),
            );
          }

          final List<CartItem> items = (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              .map(CartItem.fromFirestore)
              .where((CartItem item) => item.productId.isNotEmpty)
              .toList(growable: false);

          if (items.isEmpty) {
            return const Center(child: Text('Your cart is empty.'));
          }

          return FutureBuilder<List<_CartEntry>>(
            future: _loadEntries(context, items),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<_CartEntry>> entriesSnapshot,
            ) {
              if (entriesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (entriesSnapshot.hasError) {
                return Center(
                  child: Text('Failed to load cart products: ${entriesSnapshot.error}'),
                );
              }
              final List<_CartEntry> entries = entriesSnapshot.data ?? <_CartEntry>[];
              final double total = entries.fold<double>(
                0,
                (double sum, _CartEntry entry) =>
                    sum + (entry.product.price * entry.cartItem.quantity),
              );

              return Column(
                children: <Widget>[
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length,
                      separatorBuilder:
                          (BuildContext context, int index) =>
                              const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        final _CartEntry entry = entries[index];
                        return _CartItemTile(entry: entry);
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.gray300)),
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
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: entries.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const CheckoutScreen.cart(),
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

  Future<List<_CartEntry>> _loadEntries(
    BuildContext context,
    List<CartItem> items,
  ) async {
    final ProductService productService = context.read<ProductService>();
    final List<_CartEntry> entries = <_CartEntry>[];
    for (final CartItem item in items) {
      final Product? product = await productService.getProductOnce(item.productId);
      if (product == null) {
        continue;
      }
      entries.add(_CartEntry(cartItem: item, product: product));
    }
    return entries;
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.entry});

  final _CartEntry entry;

  @override
  Widget build(BuildContext context) {
    final String imageUrl =
        entry.product.images.isNotEmpty ? entry.product.images.first : '';
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
                      onPressed: () {
                        context.read<CartService>().updateQuantity(
                          cartId: entry.cartItem.id,
                          quantity: entry.cartItem.quantity - 1,
                        );
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      entry.cartItem.quantity.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: entry.cartItem.quantity >= entry.product.stock
                          ? null
                          : () {
                              context.read<CartService>().updateQuantity(
                                cartId: entry.cartItem.id,
                                quantity: entry.cartItem.quantity + 1,
                              );
                            },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        context.read<CartService>().removeItem(entry.cartItem.id);
                      },
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
}

class _CartEntry {
  const _CartEntry({
    required this.cartItem,
    required this.product,
  });

  final CartItem cartItem;
  final Product product;
}
