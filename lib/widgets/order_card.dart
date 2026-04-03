import 'package:flutter/material.dart';
import 'package:sincerelysea/models/order.dart' as app_order;
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/app_check_network_image.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.isSellerView,
    this.onStatusChanged,
    this.onTap,
  });

  final app_order.Order order;
  final bool isSellerView;
  final ValueChanged<String>? onStatusChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Order #${order.id.substring(0, 6).toUpperCase()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.createdAt == null
                              ? 'Just now'
                              : _formatDate(order.createdAt!.toDate()),
                          style: TextStyle(color: AppColors.gray700),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(status: order.status),
                ],
              ),
              const SizedBox(height: 12),
              ...order.items.map(
                (app_order.OrderItem item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 56,
                          height: 56,
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.productName.isEmpty ? 'Product' : item.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qty ${item.quantity} • \$${item.price.toStringAsFixed(2)}',
                              style: TextStyle(color: AppColors.gray700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.inventoryType == 'preorder'
                                  ? (item.preorderDays > 0
                                        ? 'Preorder • ${item.preorderDays} day(s)'
                                        : 'Preorder')
                                  : 'Ready Stock',
                              style: TextStyle(
                                color: AppColors.gray700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                'Ship to: ${order.customerName}\n${order.phone}\n${order.address}',
                style: TextStyle(color: AppColors.gray700, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Total \$${order.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (isSellerView && onStatusChanged != null)
                    DropdownButton<String>(
                      value: order.status,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(
                          value: 'processing',
                          child: Text('Processing'),
                        ),
                        DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        onStatusChanged!(value);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'cancelled' => Colors.red,
      'paid' => Colors.blue,
      'processing' => Colors.deepPurple,
      'shipped' => Colors.orange,
      'completed' => Colors.green,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
