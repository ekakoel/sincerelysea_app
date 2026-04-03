import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/order.dart' as app_order;
import 'package:sincerelysea/screens/orders/order_detail_screen.dart';
import 'package:sincerelysea/services/order_service.dart';
import 'package:sincerelysea/widgets/order_card.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: context.read<OrderService>().myOrdersStream(),
        builder: (
          BuildContext context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load orders: ${snapshot.error}'),
            );
          }

          final List<app_order.Order> orders = (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
              .map(app_order.Order.fromFirestore)
              .toList(growable: false);
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: orders.length,
            separatorBuilder:
                (BuildContext context, int index) =>
                    const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final app_order.Order order = orders[index];
              return OrderCard(
                order: order,
                isSellerView: false,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OrderDetailScreen(
                        order: order,
                        isSellerView: false,
                      ),
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
