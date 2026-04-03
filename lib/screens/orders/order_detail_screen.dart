import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/order.dart' as app_order;
import 'package:sincerelysea/screens/product/product_detail_screen.dart';
import 'package:sincerelysea/services/cart_service.dart';
import 'package:sincerelysea/services/order_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.isSellerView,
  });

  final app_order.Order order;
  final bool isSellerView;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _updatingStatus = false;
  bool _submittingBuyerAction = false;

  @override
  Widget build(BuildContext context) {
    final app_order.Order order = widget.order;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          _Section(
            title: 'Order Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _MetaRow(label: 'Order ID', value: order.id),
                _MetaRow(label: 'Status', value: _toTitleCase(order.status)),
                _MetaRow(
                  label: 'Created',
                  value: order.createdAt == null
                      ? 'Just now'
                      : _formatDate(order.createdAt!.toDate()),
                ),
                _MetaRow(
                  label: 'Total',
                  value: '\$${order.totalPrice.toStringAsFixed(2)}',
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Shipping Info',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.customerName.isEmpty ? '-' : order.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(order.phone.isEmpty ? '-' : order.phone),
                const SizedBox(height: 4),
                Text(order.address.isEmpty ? '-' : order.address),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Items',
            child: Column(
              children: order.items
                  .map(
                    (app_order.OrderItem item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderItemTile(item: item),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          if (widget.isSellerView) ...<Widget>[
            const SizedBox(height: 14),
            _Section(
              title: 'Store Actions',
              child: DropdownButtonFormField<String>(
                initialValue: order.status,
                decoration: const InputDecoration(labelText: 'Update Status'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(
                    value: 'processing',
                    child: Text('Processing'),
                  ),
                  DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                ],
                onChanged: _updatingStatus
                    ? null
                    : (String? value) {
                        if (value == null || value == order.status) {
                          return;
                        }
                        _updateStatus(context, value);
                      },
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 14),
            _Section(
              title: 'Buyer Actions',
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submittingBuyerAction
                          ? null
                          : () => _buyAgain(context, order),
                      child: const Text('Buy Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submittingBuyerAction || order.status != 'pending'
                          ? null
                          : () => _cancelOrder(context, order),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel Order'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _buyAgain(BuildContext context, app_order.Order order) async {
    setState(() {
      _submittingBuyerAction = true;
    });
    try {
      await context.read<CartService>().addOrderItemsToCart(order.items);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Items added back to cart.')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add items to cart: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingBuyerAction = false;
        });
      }
    }
  }

  Future<void> _cancelOrder(BuildContext context, app_order.Order order) async {
    final OrderService orderService = context.read<OrderService>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel order?'),
          content: const Text(
            'This will cancel the order and restore product stock if it is still pending.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Order'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel Order'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _submittingBuyerAction = true;
    });
    try {
      await orderService.cancelOrder(order.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order cancelled successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingBuyerAction = false;
        });
      }
    }
  }

  Future<void> _updateStatus(BuildContext context, String value) async {
    setState(() {
      _updatingStatus = true;
    });
    try {
      await context.read<OrderService>().updateOrderStatus(
        orderId: widget.order.id,
        status: value,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order status updated to ${_toTitleCase(value)}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingStatus = false;
        });
      }
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  static String _toTitleCase(String value) {
    if (value.trim().isEmpty) {
      return 'Unknown';
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: AppColors.gray700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({required this.item});

  final app_order.OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.productId.trim().isEmpty
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductDetailScreen(productId: item.productId),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: item.productImageUrl.isEmpty
                      ? Container(
                          color: AppColors.gray200,
                          child: const Icon(Icons.inventory_2_outlined),
                        )
                      : AppCheckCachedNetworkImage(
                          imageUrl: item.productImageUrl,
                          fit: BoxFit.cover,
                          placeholder: Container(color: AppColors.gray200),
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
                      item.productName.isEmpty ? 'Product' : item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Qty ${item.quantity} • \$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(color: AppColors.gray700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: item.productId.trim().isEmpty
                    ? AppColors.gray300
                    : AppColors.gray700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
