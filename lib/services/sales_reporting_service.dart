import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincerelysea/config/official_store.dart';
import 'package:sincerelysea/models/journal_entry.dart';

class SalesReportingService {
  SalesReportingService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _journalEntriesRef =>
      _firestore.collection('journal_entries');
  CollectionReference<Map<String, dynamic>> get _salesReportsRef =>
      _firestore.collection('sales_reports');

  DocumentReference<Map<String, dynamic>> createJournalEntryRef() {
    return _journalEntriesRef.doc();
  }

  DocumentReference<Map<String, dynamic>> salesReportRefForDate(DateTime date) {
    return _salesReportsRef.doc(reportKeyForDate(date));
  }

  String reportKeyForDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void recordOrderPlaced({
    required Transaction tx,
    required String orderId,
    required double totalPrice,
    required DateTime occurredAt,
  }) {
    final DocumentReference<Map<String, dynamic>> journalRef =
        createJournalEntryRef();
    final DocumentReference<Map<String, dynamic>> reportRef =
        salesReportRefForDate(occurredAt);

    tx.set(journalRef, <String, dynamic>{
      'storeId': OfficialStore.id,
      'storeName': OfficialStore.name,
      'orderId': orderId,
      'entryType': 'order_created',
      'memo': 'Customer order created for SincerelySea Store.',
      'lines': <Map<String, dynamic>>[
        _line(
          accountCode: '1100',
          accountName: 'Accounts Receivable',
          debit: totalPrice,
          credit: 0,
        ),
        _line(
          accountCode: '4100',
          accountName: 'Sales Revenue',
          debit: 0,
          credit: totalPrice,
        ),
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });

    tx.set(reportRef, <String, dynamic>{
      'storeId': OfficialStore.id,
      'storeName': OfficialStore.name,
      'reportDateKey': reportKeyForDate(occurredAt),
      'orderCount': FieldValue.increment(1),
      'paidOrderCount': FieldValue.increment(0),
      'completedOrderCount': FieldValue.increment(0),
      'cancelledOrderCount': FieldValue.increment(0),
      'grossSales': FieldValue.increment(totalPrice),
      'cancelledSales': FieldValue.increment(0),
      'netSales': FieldValue.increment(totalPrice),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void recordOrderCancelled({
    required Transaction tx,
    required String orderId,
    required double totalPrice,
    required DateTime occurredAt,
  }) {
    final DocumentReference<Map<String, dynamic>> journalRef =
        createJournalEntryRef();
    final DocumentReference<Map<String, dynamic>> reportRef =
        salesReportRefForDate(occurredAt);

    tx.set(journalRef, <String, dynamic>{
      'storeId': OfficialStore.id,
      'storeName': OfficialStore.name,
      'orderId': orderId,
      'entryType': 'order_cancelled',
      'memo': 'Order cancelled and reversed for SincerelySea Store.',
      'lines': <Map<String, dynamic>>[
        _line(
          accountCode: '4190',
          accountName: 'Sales Returns',
          debit: totalPrice,
          credit: 0,
        ),
        _line(
          accountCode: '1100',
          accountName: 'Accounts Receivable',
          debit: 0,
          credit: totalPrice,
        ),
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });

    tx.set(reportRef, <String, dynamic>{
      'storeId': OfficialStore.id,
      'storeName': OfficialStore.name,
      'reportDateKey': reportKeyForDate(occurredAt),
      'cancelledOrderCount': FieldValue.increment(1),
      'cancelledSales': FieldValue.increment(totalPrice),
      'netSales': FieldValue.increment(-totalPrice),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Map<String, dynamic> _line({
    required String accountCode,
    required String accountName,
    required double debit,
    required double credit,
  }) {
    return JournalLine(
      accountCode: accountCode,
      accountName: accountName,
      debit: debit,
      credit: credit,
    ).toMap();
  }
}
