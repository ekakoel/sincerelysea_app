import 'package:cloud_firestore/cloud_firestore.dart';

class SalesReport {
  const SalesReport({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.reportDateKey,
    required this.orderCount,
    required this.paidOrderCount,
    required this.completedOrderCount,
    required this.cancelledOrderCount,
    required this.grossSales,
    required this.cancelledSales,
    required this.netSales,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String reportDateKey;
  final int orderCount;
  final int paidOrderCount;
  final int completedOrderCount;
  final int cancelledOrderCount;
  final double grossSales;
  final double cancelledSales;
  final double netSales;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  factory SalesReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return SalesReport(
      id: doc.id,
      storeId: data['storeId']?.toString() ?? 'sincerelysea',
      storeName: data['storeName']?.toString() ?? 'SincerelySea Store',
      reportDateKey: data['reportDateKey']?.toString() ?? doc.id,
      orderCount: _toInt(data['orderCount']),
      paidOrderCount: _toInt(data['paidOrderCount']),
      completedOrderCount: _toInt(data['completedOrderCount']),
      cancelledOrderCount: _toInt(data['cancelledOrderCount']),
      grossSales: _toDouble(data['grossSales']),
      cancelledSales: _toDouble(data['cancelledSales']),
      netSales: _toDouble(data['netSales']),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
