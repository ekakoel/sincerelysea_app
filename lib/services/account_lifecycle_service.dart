import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AccountLifecycleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Object? toJsonSafeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is GeoPoint) {
      return <String, double>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is Map) {
      return value.map<String, Object?>((dynamic key, dynamic item) {
        return MapEntry<String, Object?>(key.toString(), toJsonSafeValue(item));
      });
    }
    if (value is Iterable) {
      return value.map<Object?>(toJsonSafeValue).toList(growable: false);
    }
    return value.toString();
  }

  static String encodeExportPayload(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(toJsonSafeValue(payload));
  }

  List<Map<String, dynamic>> _rows(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList(growable: false);
  }

  Future<String> exportMyDataAsJson() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final DocumentSnapshot<Map<String, dynamic>> publicUserDoc =
        await _firestore.collection('users_public').doc(user.uid).get();
    final DocumentSnapshot<Map<String, dynamic>> privateUserDoc =
        await _firestore.collection('users_private').doc(user.uid).get();
    final QuerySnapshot<Map<String, dynamic>> myPosts = await _firestore
        .collection('posts')
        .where('uid', isEqualTo: user.uid)
        .get();
    final QuerySnapshot<Map<String, dynamic>> following = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .get();
    final QuerySnapshot<Map<String, dynamic>> followers = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('followers')
        .get();
    final DocumentReference<Map<String, dynamic>> userRoot = _firestore
        .collection('users')
        .doc(user.uid);
    final QuerySnapshot<Map<String, dynamic>> cart = await userRoot
        .collection('cart')
        .get();
    final QuerySnapshot<Map<String, dynamic>> savedPosts = await userRoot
        .collection('saved_posts')
        .get();
    final QuerySnapshot<Map<String, dynamic>> collections = await userRoot
        .collection('collections')
        .get();
    final QuerySnapshot<Map<String, dynamic>> wishlists = await userRoot
        .collection('wishlists')
        .get();
    final QuerySnapshot<Map<String, dynamic>> blocks = await userRoot
        .collection('blocks')
        .get();
    final QuerySnapshot<Map<String, dynamic>> hiddenPosts = await userRoot
        .collection('hidden_posts')
        .get();
    final QuerySnapshot<Map<String, dynamic>> notifications = await userRoot
        .collection('notifications')
        .get();
    final QuerySnapshot<Map<String, dynamic>> followRequests = await userRoot
        .collection('follow_requests')
        .get();
    final QuerySnapshot<Map<String, dynamic>> supportTickets = await userRoot
        .collection('support_tickets')
        .get();
    final List<Map<String, dynamic>> support = <Map<String, dynamic>>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> ticket
        in supportTickets.docs) {
      final QuerySnapshot<Map<String, dynamic>> messages = await ticket
          .reference
          .collection('messages')
          .get();
      support.add(<String, dynamic>{
        'id': ticket.id,
        ...ticket.data(),
        'messages': _rows(messages),
      });
    }
    final QuerySnapshot<Map<String, dynamic>> reviews = await _firestore
        .collectionGroup('reviews')
        .where('userId', isEqualTo: user.uid)
        .get();
    final QuerySnapshot<Map<String, dynamic>> orders = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .get();
    final QuerySnapshot<Map<String, dynamic>> reports = await _firestore
        .collection('reports')
        .where('reporterUid', isEqualTo: user.uid)
        .get();

    final Map<String, dynamic> payload = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'uid': user.uid,
      'email': user.email,
      'publicProfile': publicUserDoc.data() ?? <String, dynamic>{},
      'privateAccount': privateUserDoc.data() ?? <String, dynamic>{},
      'posts': _rows(myPosts),
      'following': _rows(following),
      'followers': _rows(followers),
      'followRequests': _rows(followRequests),
      'savedPosts': _rows(savedPosts),
      'collections': _rows(collections),
      'wishlists': _rows(wishlists),
      'cart': _rows(cart),
      'blocks': _rows(blocks),
      'hiddenPosts': _rows(hiddenPosts),
      'notifications': _rows(notifications),
      'supportTickets': support,
      'reviews': _rows(reviews),
      'orders': _rows(orders),
      'reports': _rows(reports),
    };

    return encodeExportPayload(payload);
  }

  Future<void> hardDeleteMyAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final HttpsCallable callable = _functions.httpsCallable(
      'hardDeleteAccount',
    );
    await callable.call();
  }
}
