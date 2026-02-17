import 'dart:math';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SupportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _ticketRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('support_tickets');
  }

  CollectionReference<Map<String, dynamic>> _messageRef({
    required String uid,
    required String ticketId,
  }) {
    return _ticketRef(uid).doc(ticketId).collection('messages');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myTicketsStream() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _ticketRef(
      user.uid,
    ).orderBy('updatedAt', descending: true).limit(200).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> ticketStream(String ticketId) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
    return _ticketRef(user.uid).doc(ticketId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> ticketMessagesStream(
    String ticketId,
  ) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _messageRef(
      uid: user.uid,
      ticketId: ticketId,
    ).orderBy('createdAt', descending: false).limit(300).snapshots();
  }

  Future<({String ticketId, String ticketNumber})> createTicket({
    required String category,
    required String subject,
    required String description,
    required String contactEmail,
    required Map<String, dynamic> deviceInfo,
    String? attachmentPath,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in first.');
    }

    final String safeCategory = category.trim().toLowerCase();
    final String safeSubject = subject.trim();
    final String safeDescription = description.trim();
    final String safeEmail = contactEmail.trim();
    final String ticketNumber = _generateTicketNumber();
    final DateTime now = DateTime.now();
    final ({String name, String url})? uploadedAttachment =
        await _uploadAttachmentIfAny(
          uid: user.uid,
          attachmentPath: attachmentPath,
        );

    final DocumentReference<Map<String, dynamic>> doc = _ticketRef(
      user.uid,
    ).doc();
    final DocumentReference<Map<String, dynamic>> firstMessage = _messageRef(
      uid: user.uid,
      ticketId: doc.id,
    ).doc();

    final WriteBatch batch = _firestore.batch();
    batch.set(doc, <String, dynamic>{
      'uid': user.uid,
      'ticketNumber': ticketNumber,
      'category': safeCategory,
      'subject': safeSubject,
      'description': safeDescription,
      'contactEmail': safeEmail,
      'status': 'open',
      'priority': 'normal',
      'attachmentName': uploadedAttachment?.name ?? '',
      'attachmentUrl': uploadedAttachment?.url ?? '',
      'deviceInfo': deviceInfo,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': safeDescription,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'etaHours': 24,
      'searchTokens': _buildSearchTokens(
        '$safeSubject $safeDescription $safeCategory',
      ),
      'createdDayKey':
          '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}',
    });
    batch.set(firstMessage, <String, dynamic>{
      'uid': user.uid,
      'senderType': 'user',
      'message': safeDescription,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return (ticketId: doc.id, ticketNumber: ticketNumber);
  }

  Future<({String name, String url})?> _uploadAttachmentIfAny({
    required String uid,
    required String? attachmentPath,
  }) async {
    final String path = (attachmentPath ?? '').trim();
    if (path.isEmpty) {
      return null;
    }
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }

    final String extension = _safeFileExtension(path);
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999).toString().padLeft(4, '0')}$extension';

    final Reference ref = _storage.ref().child(
      'support_attachments/$uid/$fileName',
    );
    final SettableMetadata metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: <String, String>{'uid': uid},
    );
    final UploadTask task = ref.putFile(file, metadata);
    await task;
    final String url = await ref.getDownloadURL();
    return (name: file.path.split('/').last, url: url);
  }

  String _safeFileExtension(String filePath) {
    final String lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) {
      return '.png';
    }
    if (lower.endsWith('.webp')) {
      return '.webp';
    }
    return '.jpg';
  }

  Future<void> addReply({
    required String ticketId,
    required String message,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in first.');
    }
    final String safeMessage = message.trim();
    if (safeMessage.isEmpty) {
      throw Exception('Message cannot be empty.');
    }

    final DocumentReference<Map<String, dynamic>> ticketDoc = _ticketRef(
      user.uid,
    ).doc(ticketId);
    final DocumentReference<Map<String, dynamic>> messageDoc = _messageRef(
      uid: user.uid,
      ticketId: ticketId,
    ).doc();

    final WriteBatch batch = _firestore.batch();
    batch.set(messageDoc, <String, dynamic>{
      'uid': user.uid,
      'senderType': 'user',
      'message': safeMessage,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(ticketDoc, <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': safeMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  String _generateTicketNumber() {
    final DateTime now = DateTime.now();
    final int rnd = 1000 + Random().nextInt(9000);
    final String dayKey =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'SUP-$dayKey-$rnd';
  }

  List<String> _buildSearchTokens(String text) {
    final String normalized = text.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9 ]'),
      ' ',
    );
    final Set<String> tokens = normalized
        .split(RegExp(r'\s+'))
        .where((String e) => e.trim().isNotEmpty)
        .map((String e) => e.trim())
        .toSet();
    return tokens.take(40).toList(growable: false);
  }
}
