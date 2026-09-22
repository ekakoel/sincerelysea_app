import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/order.dart' as app_order;
import 'package:sincerelysea/screens/orders/order_detail_screen.dart';
import 'package:sincerelysea/services/order_service.dart';
import 'package:sincerelysea/widgets/order_card.dart';
import 'package:sincerelysea/widgets/customer_state_view.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<OrderService>().myOrdersStream(),
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
                  title: 'Orders unavailable',
                  message: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }

              final List<app_order.Order> orders =
                  (snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      .map(app_order.Order.fromFirestore)
                      .toList(growable: false);
              if (orders.isEmpty) {
                return const CustomerStateView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  message:
                      'Orders placed through SincerelySea Store will appear here.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: orders.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final app_order.Order order = orders[index];
                  return OrderCard(
                    order: order,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OrderDetailScreen(order: order),
                        ),
                      );
                    },
                  );
                },
              );
            },
      ),
    );
  }
}
