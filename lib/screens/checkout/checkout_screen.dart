import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/cart_item.dart';
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/services/cart_service.dart';
import 'package:sincerelysea/services/order_service.dart';
import 'package:sincerelysea/services/product_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen.cart({super.key})
      : buyNowProduct = null,
        buyNowQuantity = 1;

  const CheckoutScreen.buyNow({
    super.key,
    required this.buyNowProduct,
    this.buyNowQuantity = 1,
  });

  final Product? buyNowProduct;
  final int buyNowQuantity;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _placingOrder = false;

  @override
  void initState() {
    super.initState();
    final User? user = FirebaseAuth.instance.currentUser;
    _loadUserInfo(user);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: FutureBuilder<_CheckoutData>(
        future: _loadCheckoutData(context),
        builder: (
          BuildContext context,
          AsyncSnapshot<_CheckoutData> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load checkout data: ${snapshot.error}'),
            );
          }
          final _CheckoutData data = snapshot.data ?? const _CheckoutData.empty();
          if (data.items.isEmpty) {
            return const Center(child: Text('Nothing to checkout.'));
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                if (data.items.any(
                  (_CheckoutItem item) => item.product.isPreorder,
                )) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.schedule_outlined, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Some items are preorder. Delivery timing may be longer than ready stock products.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                const Text(
                  'Shipping Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Phone is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                  minLines: 3,
                  maxLines: 4,
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Order Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...data.items.map(
                  (_CheckoutItem item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD9D9D9)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  _InventoryPill(
                                    label: item.product.inventoryLabel,
                                    isPreorder: item.product.isPreorder,
                                  ),
                                  if (item.product.isPreorder &&
                                      item.product.preorderDays > 0)
                                    _NeutralPill(
                                      label:
                                          'Est. ${item.product.preorderDays} day(s)',
                                    ),
                                  _NeutralPill(label: 'Qty ${item.quantity}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '\$${(item.product.price * item.quantity).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '\$${data.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _placingOrder
                      ? null
                      : () => _placeOrder(context, data),
                  child: _placingOrder
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Place Order'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadUserInfo(User? user) async {
    if (user == null) {
      return;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    if (!mounted) {
      return;
    }
    _nameController.text =
        data['displayName']?.toString() ?? user.displayName ?? '';
    _phoneController.text = data['phone']?.toString() ?? '';
    _addressController.text = data['address']?.toString() ?? '';
  }

  Future<_CheckoutData> _loadCheckoutData(BuildContext context) async {
    if (widget.buyNowProduct != null) {
      return _CheckoutData(
        cartItems: <CartItem>[
          CartItem(
            id: widget.buyNowProduct!.id,
            productId: widget.buyNowProduct!.id,
            quantity: widget.buyNowQuantity,
          ),
        ],
        items: <_CheckoutItem>[
          _CheckoutItem(
            product: widget.buyNowProduct!,
            quantity: widget.buyNowQuantity,
          ),
        ],
      );
    }

    final CartService cartService = context.read<CartService>();
    final ProductService productService = context.read<ProductService>();
    final List<CartItem> cartItems = await cartService.getCartItems();
    final List<_CheckoutItem> items = <_CheckoutItem>[];
    for (final CartItem cartItem in cartItems) {
      final Product? product = await productService.getProductOnce(
        cartItem.productId,
      );
      if (product == null) {
        continue;
      }
      items.add(_CheckoutItem(product: product, quantity: cartItem.quantity));
    }
    return _CheckoutData(cartItems: cartItems, items: items);
  }

  Future<void> _placeOrder(BuildContext context, _CheckoutData data) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final CartService cartService = context.read<CartService>();
    final OrderService orderService = context.read<OrderService>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _placingOrder = true);
    try {
      final Map<String, Product> productsById = <String, Product>{
        for (final _CheckoutItem item in data.items) item.product.id: item.product,
      };
      final String orderId = await orderService.placeOrder(
            cartItems: data.cartItems,
            productsById: productsById,
            checkoutInfo: CheckoutInfo(
              customerName: _nameController.text,
              phone: _phoneController.text,
              address: _addressController.text,
            ),
          );

      if (widget.buyNowProduct == null) {
        await cartService.clearCart();
      }

      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Order placed: $orderId')),
      );
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to place order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _placingOrder = false);
      }
    }
  }
}

class _CheckoutData {
  const _CheckoutData({
    required this.cartItems,
    required this.items,
  });

  const _CheckoutData.empty()
      : cartItems = const <CartItem>[],
        items = const <_CheckoutItem>[];

  final List<CartItem> cartItems;
  final List<_CheckoutItem> items;

  double get totalPrice => items.fold<double>(
        0,
        (double sum, _CheckoutItem item) =>
            sum + (item.product.price * item.quantity),
      );
}

class _CheckoutItem {
  const _CheckoutItem({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;
}

class _InventoryPill extends StatelessWidget {
  const _InventoryPill({
    required this.label,
    required this.isPreorder,
  });

  final String label;
  final bool isPreorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPreorder
            ? Colors.orange.withValues(alpha: 0.12)
            : Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPreorder ? Colors.orange.shade800 : Colors.green.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NeutralPill extends StatelessWidget {
  const _NeutralPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
