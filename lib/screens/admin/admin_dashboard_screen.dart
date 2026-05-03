import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/order.dart' as app_order;
import 'package:sincerelysea/models/product.dart';
import 'package:sincerelysea/services/admin_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _auditFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = context.read<AdminService>();
    return FutureBuilder<bool>(
      future: adminService.isCurrentUserAdmin(),
      builder: (BuildContext context, AsyncSnapshot<bool> roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (roleSnapshot.data != true) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Only admin accounts can view the admin dashboard.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Admin Dashboard')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              const Text(
                'Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      label: 'Users',
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Products',
                      stream: FirebaseFirestore.instance
                          .collection('products')
                          .snapshots(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      label: 'Orders',
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .snapshots(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Privileged',
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', whereIn: const <String>[
                            'admin',
                            'developer',
                          ])
                          .snapshots(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Product Analytics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> productsSnap,
                ) {
                  if (productsSnap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final List<Product> products =
                      (productsSnap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          .map(Product.fromFirestore)
                          .toList(growable: false);
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .snapshots(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> ordersSnap,
                    ) {
                      if (ordersSnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final List<app_order.Order> orders =
                          (ordersSnap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                              .map(app_order.Order.fromFirestore)
                              .toList(growable: false);
                      return _ProductAnalyticsSection(
                        products: products,
                        orders: orders,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Role Audit Log',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _AuditFilterChip(
                    label: 'All',
                    selected: _auditFilter == 'all',
                    onTap: () => setState(() => _auditFilter = 'all'),
                  ),
                  _AuditFilterChip(
                    label: 'Promoted',
                    selected: _auditFilter == 'promoted',
                    onTap: () => setState(() => _auditFilter = 'promoted'),
                  ),
                  _AuditFilterChip(
                    label: 'Demoted',
                    selected: _auditFilter == 'demoted',
                    onTap: () => setState(() => _auditFilter = 'demoted'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: adminService.roleAuditLogsStream(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                      (snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          .where(_matchesAuditFilter)
                          .toList(growable: false);
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gray300),
                      ),
                      child: const Text(
                        'No role changes match the current filter.',
                      ),
                    );
                  }

                  return Column(
                    children: docs
                        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                          final Map<String, dynamic> data = doc.data();
                          final Timestamp? createdAt =
                              data['createdAt'] as Timestamp?;
                          final DateTime? createdDate = createdAt?.toDate();
                          final String actor =
                              data['actorUsername']?.toString().trim().isNotEmpty ==
                                  true
                              ? '@${data['actorUsername']}'
                              : 'Unknown admin';
                          final String target =
                              data['targetUsername']?.toString().trim().isNotEmpty ==
                                  true
                              ? '@${data['targetUsername']}'
                              : 'Unknown user';
                          final String previousRole =
                              data['previousRole']?.toString() ?? 'user';
                          final String newRole =
                              data['newRole']?.toString() ?? 'user';
                          final bool promoted = newRole == 'admin';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: promoted
                                    ? Colors.green.withValues(alpha: 0.14)
                                    : Colors.orange.withValues(alpha: 0.14),
                                child: Icon(
                                  promoted
                                      ? Icons.arrow_circle_up_outlined
                                      : Icons.arrow_circle_down_outlined,
                                  color: promoted
                                      ? Colors.green.shade700
                                      : Colors.orange.shade800,
                                ),
                              ),
                              title: Text('$actor updated $target'),
                              subtitle: Text(
                                '${previousRole.toUpperCase()} -> ${newRole.toUpperCase()}'
                                '${createdDate == null ? '' : '\n${_formatDate(createdDate)}'}',
                              ),
                              isThreeLine: createdDate != null,
                            ),
                          );
                        })
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _matchesAuditFilter(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    if (_auditFilter == 'all') {
      return true;
    }
    final String newRole = doc.data()['newRole']?.toString() ?? 'user';
    if (_auditFilter == 'promoted') {
      return newRole == 'admin';
    }
    if (_auditFilter == 'demoted') {
      return newRole == 'user';
    }
    return true;
  }

  static String _formatDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.stream,
  });

  final String label;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final int count = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuditFilterChip extends StatelessWidget {
  const _AuditFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.gray100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.black : AppColors.gray300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.white : AppColors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProductAnalyticsSection extends StatelessWidget {
  const _ProductAnalyticsSection({
    required this.products,
    required this.orders,
  });

  final List<Product> products;
  final List<app_order.Order> orders;

  @override
  Widget build(BuildContext context) {
    final int preorderCount = products.where((Product p) => p.isPreorder).length;
    final int readyStockCount = products
        .where((Product p) => p.isReadyStock)
        .length;
    final int pausedCount = products
        .where((Product p) => !p.availableForPurchase)
        .length;
    final int lowStockCount = products
        .where(
          (Product p) =>
              p.isReadyStock && p.availableForPurchase && p.stock > 0 && p.stock <= 5,
        )
        .length;

    final Map<String, _ProductSalesStats> salesByProduct =
        <String, _ProductSalesStats>{};
    for (final app_order.Order order in orders) {
      if (order.status == 'cancelled') {
        continue;
      }
      for (final app_order.OrderItem item in order.items) {
        final _ProductSalesStats current =
            salesByProduct[item.productId] ?? const _ProductSalesStats();
        salesByProduct[item.productId] = _ProductSalesStats(
          unitsSold: current.unitsSold + item.quantity,
          revenue: current.revenue + (item.price * item.quantity),
        );
      }
    }

    final List<_RankedProduct> rankedProducts = products
        .map((Product product) {
          final _ProductSalesStats stats =
              salesByProduct[product.id] ?? const _ProductSalesStats();
          return _RankedProduct(product: product, stats: stats);
        })
        .toList(growable: false)
      ..sort((_RankedProduct a, _RankedProduct b) {
        final int unitCompare = b.stats.unitsSold.compareTo(a.stats.unitsSold);
        if (unitCompare != 0) {
          return unitCompare;
        }
        return b.stats.revenue.compareTo(a.stats.revenue);
      });

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatusCard(label: 'Ready Stock', value: readyStockCount),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusCard(label: 'Preorder', value: preorderCount),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatusCard(label: 'Paused', value: pausedCount),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusCard(label: 'Low Stock', value: lowStockCount),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Top Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (rankedProducts.isEmpty)
                const Text('No products found yet.')
              else ...rankedProducts.take(5).map(
                (_RankedProduct ranked) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              ranked.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ranked.product.category.trim().isEmpty
                                  ? ranked.product.inventoryLabel
                                  : '${ranked.product.category} • ${ranked.product.inventoryLabel}',
                              style: const TextStyle(
                                color: AppColors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            '${ranked.stats.unitsSold} sold',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${ranked.stats.revenue.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSalesStats {
  const _ProductSalesStats({
    this.unitsSold = 0,
    this.revenue = 0,
  });

  final int unitsSold;
  final double revenue;
}

class _RankedProduct {
  const _RankedProduct({
    required this.product,
    required this.stats,
  });

  final Product product;
  final _ProductSalesStats stats;
}
