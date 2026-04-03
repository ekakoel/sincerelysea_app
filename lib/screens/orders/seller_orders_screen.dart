import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/order.dart' as app_order;
import 'package:sincerelysea/screens/orders/order_detail_screen.dart';
import 'package:sincerelysea/services/order_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';
import 'package:sincerelysea/widgets/order_card.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<OrderService>().sellerOrdersStream(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load seller orders: ${snapshot.error}'),
            );
          }

          final List<app_order.Order> orders = (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              .map(app_order.Order.fromFirestore)
              .toList(growable: false);
          final List<app_order.Order> filteredOrders = _selectedStatus == 'all'
              ? orders
              : orders
                    .where((app_order.Order order) => order.status == _selectedStatus)
                    .toList(growable: false);
          if (orders.isEmpty) {
            return const Center(child: Text('No incoming orders yet.'));
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SellerSummaryCard(orders: orders),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  scrollDirection: Axis.horizontal,
                  children: <String>[
                    'all',
                    'cancelled',
                    'pending',
                    'paid',
                    'processing',
                    'shipped',
                    'completed',
                  ].map(_buildStatusChip).toList(growable: false),
                ),
              ),
              Expanded(
                child: filteredOrders.isEmpty
                    ? const Center(child: Text('No orders in this status.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: filteredOrders.length,
                        separatorBuilder:
                            (BuildContext context, int index) =>
                                const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) {
                          final app_order.Order order = filteredOrders[index];
                          return OrderCard(
                            order: order,
                            isSellerView: true,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => OrderDetailScreen(
                                    order: order,
                                    isSellerView: true,
                                  ),
                                ),
                              );
                            },
                            onStatusChanged: (String nextStatus) async {
                              try {
                                await context.read<OrderService>().updateOrderStatus(
                                  orderId: order.id,
                                  status: nextStatus,
                                );
                              } catch (e) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update order status: $e'),
                                  ),
                                );
                              }
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

  Widget _buildStatusChip(String value) {
    final bool selected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(value == 'all' ? 'All' : _toTitleCase(value)),
        labelStyle: TextStyle(
          color: selected ? AppColors.white : AppColors.gray700,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: AppColors.black,
        backgroundColor: AppColors.gray100,
        onSelected: (bool isSelected) {
          if (!isSelected) {
            return;
          }
          setState(() {
            _selectedStatus = value;
          });
        },
      ),
    );
  }

  String _toTitleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _SellerSummaryCard extends StatelessWidget {
  const _SellerSummaryCard({required this.orders});

  final List<app_order.Order> orders;

  @override
  Widget build(BuildContext context) {
    final int totalOrders = orders.length;
    final int pendingOrders = orders
        .where((app_order.Order order) => order.status == 'pending')
        .length;
    final int completedOrders = orders
        .where((app_order.Order order) => order.status == 'completed')
        .length;
    final double revenue = orders
        .where((app_order.Order order) => order.status != 'cancelled')
        .fold<double>(
          0,
          (double sum, app_order.Order order) => sum + order.totalPrice,
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _MetricTile(
              label: 'Orders',
              value: '$totalOrders',
            ),
          ),
          Expanded(
            child: _MetricTile(
              label: 'Pending',
              value: '$pendingOrders',
            ),
          ),
          Expanded(
            child: _MetricTile(
              label: 'Completed',
              value: '$completedOrders',
            ),
          ),
          Expanded(
            child: _MetricTile(
              label: 'Revenue',
              value: '\$${revenue.toStringAsFixed(0)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.gray700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
