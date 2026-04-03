import 'package:cloud_firestore/cloud_firestore.dart';

class JournalLine {
  const JournalLine({
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
  });

  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;

  factory JournalLine.fromMap(Map<String, dynamic> data) {
    return JournalLine(
      accountCode: data['accountCode']?.toString() ?? '',
      accountName: data['accountName']?.toString() ?? '',
      debit: _toDouble(data['debit']),
      credit: _toDouble(data['credit']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'accountCode': accountCode,
      'accountName': accountName,
      'debit': debit,
      'credit': credit,
    };
  }
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.orderId,
    required this.entryType,
    required this.memo,
    required this.lines,
    required this.createdAt,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String orderId;
  final String entryType;
  final String memo;
  final List<JournalLine> lines;
  final Timestamp? createdAt;

  factory JournalEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return JournalEntry(
      id: doc.id,
      storeId: data['storeId']?.toString() ?? 'sincerelysea',
      storeName: data['storeName']?.toString() ?? 'SincerelySea Store',
      orderId: data['orderId']?.toString() ?? '',
      entryType: data['entryType']?.toString() ?? '',
      memo: data['memo']?.toString() ?? '',
      lines: (data['lines'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(JournalLine.fromMap)
          .toList(growable: false),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
