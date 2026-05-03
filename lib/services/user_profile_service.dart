import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> profileStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  String normalizeUsername(String raw) {
    return _normalizeUsername(raw);
  }

  bool isUsernameFormatValid(String username) {
    return _isValidUsername(username);
  }

  Future<bool> isUsernameAvailable(String raw, {String? excludeUid}) async {
    final String normalized = _normalizeUsername(raw);
    if (!_isValidUsername(normalized)) {
      return false;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection('usernames')
        .doc(normalized)
        .get();
    if (!doc.exists) {
      return true;
    }
    if (excludeUid != null && doc.data()?['uid']?.toString() == excludeUid) {
      return true;
    }
    return false;
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String location,
    bool? isPrivate,
    String? allowComments,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(user.uid);
    final Map<String, dynamic> payload = <String, dynamic>{
      'displayName': displayName.trim(),
      'bio': bio.trim(),
      'location': location.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (isPrivate != null) {
      payload['isPrivate'] = isPrivate;
    }
    if (allowComments != null && allowComments.isNotEmpty) {
      payload['allowComments'] = allowComments;
    }

    await userRef.set(payload, SetOptions(merge: true));
  }

  Future<void> updatePrivacySettings({
    required bool isPrivate,
    required String allowComments,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    await _firestore.collection('users').doc(user.uid).set({
      'isPrivate': isPrivate,
      'allowComments': allowComments.trim().isEmpty
          ? 'everyone'
          : allowComments.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> changeUsernameOnce(String username) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final String normalized = _normalizeUsername(username);
    if (!_isValidUsername(normalized)) {
      throw Exception(
        'Username must be 3-20 characters: lowercase, numbers, underscore.',
      );
    }

    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentReference<Map<String, dynamic>> newUsernameRef = _firestore
        .collection('usernames')
        .doc(normalized);

    try {
      await _firestore.runTransaction((Transaction tx) async {
        final DocumentSnapshot<Map<String, dynamic>> userSnap = await tx.get(
          userRef,
        );
        if (!userSnap.exists) {
          throw Exception('User profile not found');
        }
        final Map<String, dynamic> currentData =
            userSnap.data() ?? <String, dynamic>{};

        final bool changedOnce = currentData['usernameChangedOnce'] == true;
        if (changedOnce) {
          throw Exception('Username can only be changed once.');
        }

        final String oldLower = currentData['usernameLower']?.toString() ?? '';
        if (oldLower == normalized) {
          throw Exception(
            'New username must be different from current username.',
          );
        }

        final DocumentSnapshot<Map<String, dynamic>> newSnap = await tx.get(
          newUsernameRef,
        );
        if (newSnap.exists) {
          throw Exception('Username is already taken.');
        }

        tx.set(newUsernameRef, {
          'uid': user.uid,
          'username': normalized,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (oldLower.isNotEmpty) {
          final DocumentReference<Map<String, dynamic>> oldUsernameRef = _firestore
              .collection('usernames')
              .doc(oldLower);
          final DocumentSnapshot<Map<String, dynamic>> oldUsernameSnap = await tx
              .get(oldUsernameRef);
          final String oldUid = oldUsernameSnap.data()?['uid']?.toString() ?? '';
          if (oldUsernameSnap.exists && oldUid == user.uid) {
            tx.delete(oldUsernameRef);
          }
        }

        tx.update(userRef, {
          'username': normalized,
          'usernameLower': normalized,
          'usernameChangedOnce': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Permission denied saat ganti username. Pastikan Firestore rules terbaru sudah dideploy.',
        );
      }
      rethrow;
    }
  }

  Future<String> uploadProfilePhoto(File imageFile) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final Reference ref = _storage.ref().child(
      'profile_images/${user.uid}.jpg',
    );
    await ref.putFile(
      imageFile,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=300',
      ),
    );
    final String baseUrl = await ref.getDownloadURL();
    final Uri uri = Uri.parse(baseUrl);
    final Map<String, String> query = <String, String>{
      ...uri.queryParameters,
      'v': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    final String versionedUrl = uri.replace(queryParameters: query).toString();
    await _firestore.collection('users').doc(user.uid).set({
      'photoUrl': versionedUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.updatePhotoURL(versionedUrl);
    await user.reload();
    return versionedUrl;
  }

  String _normalizeUsername(String raw) {
    String value = raw.trim().toLowerCase();
    value = value.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return value;
  }

  bool _isValidUsername(String username) {
    return RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username);
  }
}
