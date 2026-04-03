import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sincerelysea/services/telemetry_service.dart';

class AuthService {
  AuthService();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;
  static const String _androidServerClientId =
      '215566920705-vgsplkm55ie45plp5ep2cg0qlsnls756.apps.googleusercontent.com';

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(
      serverClientId:
          defaultTargetPlatform == TargetPlatform.android
          ? _androidServerClientId
          : null,
    );
    _googleInitialized = true;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final User? user = credential.user;
    if (user != null) {
      await _upsertUserProfile(user);
    }
    return credential;
  }

  Future<User?> signUpWithEmail(
    String email,
    String password, {
    String? username,
  }) async {
    User? createdUser;
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final User? user = credential.user;
      createdUser = user;
      if (user != null) {
        if (username != null && username.trim().isNotEmpty) {
          await _reserveCustomUsername(user, username);
        }
        await _upsertUserProfile(user);
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
        await TelemetryService.instance.logRegisterSuccess(method: 'email');
      }
      return user;
    } catch (_) {
      if (createdUser != null) {
        await _rollbackFailedSignUp(createdUser);
      }
      rethrow;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw FirebaseAuthException(
          code: 'google-id-token-missing',
          message:
              'Google Sign-In failed. Missing ID token. Please recheck Firebase OAuth setup.',
        );
      }
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;
      if (user != null) {
        await _upsertUserProfile(user);
      }
      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw FirebaseAuthException(
          code: 'google-signin-config-error',
          message:
              'Google Sign-In configuration is invalid. Check package name, SHA-1/SHA-256, and google-services.json.',
        );
      }
      if (e.code == GoogleSignInExceptionCode.uiUnavailable) {
        throw FirebaseAuthException(
          code: 'google-signin-ui-unavailable',
          message:
              'Google Sign-In UI is unavailable on this device/session. Please try again.',
        );
      }
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: e.description ?? 'Google Sign-In failed.',
      );
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  bool usesPasswordProvider(User user) {
    return user.providerData.any((info) => info.providerId == 'password');
  }

  bool usesGoogleProvider(User user) {
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  Future<void> reauthenticateForSensitiveAction({String? password}) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (usesPasswordProvider(user)) {
      final String email = user.email ?? '';
      if (email.isEmpty) {
        throw Exception('Email not found for password reauthentication.');
      }
      final String pass = password?.trim() ?? '';
      if (pass.isEmpty) {
        throw Exception('Password is required.');
      }
      final AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: pass,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (usesGoogleProvider(user)) {
      await _ensureGoogleInitialized();
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    throw Exception('Unsupported provider for reauthentication.');
  }

  Stream<User?> get user => _auth.userChanges();

  Future<void> sendCurrentUserVerificationEmail() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    await user.sendEmailVerification();
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  bool isUsernameFormatValid(String username) {
    return RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username);
  }

  String normalizeUsername(String raw) {
    return raw.trim().toLowerCase();
  }

  Future<bool> isUsernameAvailable(String raw, {String? excludeUid}) async {
    final String normalized = normalizeUsername(raw);
    if (!isUsernameFormatValid(normalized)) {
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

  Future<void> _upsertUserProfile(User user) async {
    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userRef.get();
    final Map<String, dynamic> existing =
        snapshot.data() ?? <String, dynamic>{};

    if (!snapshot.exists) {
      final String base = _slugifyUsername(
        user.displayName ?? user.email?.split('@').first ?? 'user',
      );
      final String username = await _findAvailableUsername(base);
      final String usernameLower = username.toLowerCase();

      await _firestore.collection('usernames').doc(usernameLower).set({
        'uid': user.uid,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName':
            user.displayName ?? user.email?.split('@').first ?? 'Anonymous',
        'photoUrl': user.photoURL ?? '',
        'role': 'user',
        'username': username,
        'usernameLower': usernameLower,
        'usernameChangedOnce': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    // Existing document: only update fields allowed by firestore.rules usernameUnchanged().
    await userRef.set({
      'email': user.email,
      'displayName':
          user.displayName ?? user.email?.split('@').first ?? 'Anonymous',
      'photoUrl': user.photoURL ?? existing['photoUrl'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _slugifyUsername(String raw) {
    String value = raw.trim().toLowerCase();
    value = value.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    value = value.replaceAll(RegExp(r'_+'), '_');
    value = value.replaceAll(RegExp(r'^_+|_+$'), '');
    if (value.length < 3) {
      value = '${value}user';
    }
    if (value.length > 20) {
      value = value.substring(0, 20);
    }
    return value;
  }

  Future<String> _findAvailableUsername(String base) async {
    String candidate = _slugifyUsername(base);
    for (int i = 0; i < 30; i++) {
      final String name = i == 0 ? candidate : '$candidate$i';
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection('usernames')
          .doc(name)
          .get();
      if (!doc.exists) {
        return name;
      }
    }
    final int millis = DateTime.now().millisecondsSinceEpoch % 100000;
    final String seed = '$candidate$millis';
    return seed.length <= 20 ? seed : seed.substring(0, 20);
  }

  Future<void> _reserveCustomUsername(User user, String username) async {
    final String normalized = _slugifyUsername(username);
    final DocumentReference<Map<String, dynamic>> usernameRef = _firestore
        .collection('usernames')
        .doc(normalized);
    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> existing = await tx.get(
        usernameRef,
      );
      if (existing.exists) {
        throw FirebaseAuthException(
          code: 'username-already-in-use',
          message: 'Username is already in use.',
        );
      }
      tx.set(usernameRef, {
        'uid': user.uid,
        'username': normalized,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(_firestore.collection('users').doc(user.uid), {
        'uid': user.uid,
        'username': normalized,
        'usernameLower': normalized,
        'usernameChangedOnce': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _rollbackFailedSignUp(User user) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> usernameDocs = await _firestore
          .collection('usernames')
          .where('uid', isEqualTo: user.uid)
          .limit(10)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in usernameDocs.docs) {
        try {
          await doc.reference.delete();
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await _firestore.collection('users').doc(user.uid).delete();
    } catch (_) {}

    try {
      await user.delete();
    } catch (_) {}
  }
}
