import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AccountLifecycleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<String> exportMyDataAsJson() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
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

    final Map<String, dynamic> payload = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'uid': user.uid,
      'email': user.email,
      'profile': userDoc.data() ?? <String, dynamic>{},
      'posts': myPosts.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList(),
      'following': following.docs.map((d) => d.data()).toList(),
      'followers': followers.docs.map((d) => d.data()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> deleteMyAccountDataOnly() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final WriteBatch batch = _firestore.batch();

    final QuerySnapshot<Map<String, dynamic>> myPosts = await _firestore
        .collection('posts')
        .where('uid', isEqualTo: user.uid)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> post
        in myPosts.docs) {
      batch.delete(post.reference);
    }

    final QuerySnapshot<Map<String, dynamic>> following = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in following.docs) {
      batch.delete(doc.reference);
    }

    final QuerySnapshot<Map<String, dynamic>> followers = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('followers')
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in followers.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_firestore.collection('users').doc(user.uid));
    await batch.commit();
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
