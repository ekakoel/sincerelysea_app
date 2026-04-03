import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/models/journal_entry.dart';
import 'package:sincerelysea/models/sales_report.dart';
import 'package:sincerelysea/services/admin_service.dart';
import 'package:sincerelysea/services/sales_reporting_service.dart';
import 'package:sincerelysea/theme/app_colors.dart';

class SalesReportsScreen extends StatelessWidget {
  const SalesReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = context.read<AdminService>();
    final SalesReportingService reportingService = context
        .read<SalesReportingService>();
    return FutureBuilder<bool>(
      future: adminService.hasCurrentUserScope('finance'),
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
                  'Only finance admins can view transaction reports.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Transaction Reports')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray300),
                ),
                child: const Text(
                  'SincerelySea Store transaction reports are generated from order events and mirrored into journal entries for accounting review.',
                  style: TextStyle(height: 1.45),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Daily Sales Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: reportingService.recentSalesReportsStream(),
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
                  final List<SalesReport> reports =
                      (snapshot.data?.docs ??
                              <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          .map(SalesReport.fromFirestore)
                          .toList(growable: false);
                  if (reports.isEmpty) {
                    return const Text('No sales report snapshots yet.');
                  }
                  return Column(
                    children: reports
                        .map(
                          (SalesReport report) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    report.reportDateKey,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 10,
                                    children: <Widget>[
                                      _Metric(label: 'Orders', value: '${report.orderCount}'),
                                      _Metric(label: 'Paid', value: '${report.paidOrderCount}'),
                                      _Metric(
                                        label: 'Completed',
                                        value: '${report.completedOrderCount}',
                                      ),
                                      _Metric(
                                        label: 'Cancelled',
                                        value: '${report.cancelledOrderCount}',
                                      ),
                                      _Metric(
                                        label: 'Gross',
                                        value: '\$${report.grossSales.toStringAsFixed(2)}',
                                      ),
                                      _Metric(
                                        label: 'Net',
                                        value: '\$${report.netSales.toStringAsFixed(2)}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Recent Journal Entries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: reportingService.recentJournalEntriesStream(),
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
                  final List<JournalEntry> entries =
                      (snapshot.data?.docs ??
                              <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          .map(JournalEntry.fromFirestore)
                          .toList(growable: false);
                  if (entries.isEmpty) {
                    return const Text('No journal entries recorded yet.');
                  }
                  return Column(
                    children: entries
                        .map(
                          (JournalEntry entry) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    entry.entryType.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(entry.memo),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Order: ${entry.orderId}',
                                    style: const TextStyle(color: AppColors.black54),
                                  ),
                                  if (entry.createdAt != null) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(entry.createdAt!.toDate()),
                                      style: const TextStyle(
                                        color: AppColors.black54,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  ...entry.lines.map(
                                    (JournalLine line) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              '${line.accountCode} • ${line.accountName}',
                                            ),
                                          ),
                                          Text(
                                            'Dr ${line.debit.toStringAsFixed(2)} / Cr ${line.credit.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.black54)),
      ],
    );
  }
}
