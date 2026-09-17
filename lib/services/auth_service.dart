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
      '436229615260-jv6ds0j7foj27kmh4djomtebftgta8qf.apps.googleusercontent.com';

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize(
      serverClientId:
          defaultTargetPlatform == TargetPlatform.android
              ? _androidServerClientId
              : null,
    );

    _googleInitialized = true;
  }

  // ============================================================
  // EMAIL LOGIN
  // ============================================================

  Future<UserCredential> signInWithEmail(
    String email,
    String password,
  ) async {
    final UserCredential credential =
        await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final User? user = credential.user;

    if (user != null) {
      await _upsertUserProfile(user);
    }

    return credential;
  }

  // ============================================================
  // EMAIL REGISTER
  // ============================================================

  Future<User?> signUpWithEmail(
    String email,
    String password, {
    String? username,
  }) async {
    User? createdUser;

    try {
      final String normalizedEmail = email.trim();
      final String normalizedUsername =
          username == null ? '' : normalizeUsername(username);

      // ----------------------------------------------------------
      // 1. Create Firebase Authentication account
      // ----------------------------------------------------------

      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final User? user = credential.user;
      createdUser = user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-creation-failed',
          message: 'Firebase gagal membuat user.',
        );
      }

      // ----------------------------------------------------------
      // 2. Reserve custom username
      // ----------------------------------------------------------

      if (normalizedUsername.isNotEmpty) {
        if (!isUsernameFormatValid(normalizedUsername)) {
          throw FirebaseAuthException(
            code: 'invalid-username',
            message:
                'Username harus terdiri dari 3-20 karakter: a-z, 0-9, _.',
          );
        }

        await _reserveCustomUsername(
          user,
          normalizedUsername,
        );
      }

      // ----------------------------------------------------------
      // 3. Create/update Firestore profile
      // ----------------------------------------------------------

      await _upsertUserProfile(
        user,
        username: normalizedUsername.isEmpty
            ? null
            : normalizedUsername,
      );

      // ----------------------------------------------------------
      // 4. Send email verification
      // ----------------------------------------------------------

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }

      // ----------------------------------------------------------
      // 5. Telemetry
      // ----------------------------------------------------------

      await TelemetryService.instance.logRegisterSuccess(
        method: 'email',
      );

      return user;
    } catch (e, stackTrace) {
      debugPrint('SIGN-UP ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);

      // ----------------------------------------------------------
      // Rollback account if Firebase Auth user was already created
      // ----------------------------------------------------------

      if (createdUser != null) {
        await _rollbackFailedSignUp(createdUser);
      }

      rethrow;
    }
  }

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      if (googleAuth.idToken == null ||
          googleAuth.idToken!.isEmpty) {
        throw FirebaseAuthException(
          code: 'google-id-token-missing',
          message:
              'Google Sign-In gagal. ID token tidak tersedia. '
              'Periksa konfigurasi OAuth Firebase.',
        );
      }

      final AuthCredential credential =
          GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(
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

      if (e.code ==
              GoogleSignInExceptionCode.clientConfigurationError ||
          e.code ==
              GoogleSignInExceptionCode.providerConfigurationError) {
        throw FirebaseAuthException(
          code: 'google-signin-config-error',
          message:
              'Google Sign-In configuration tidak valid. '
              'Periksa package name, SHA-1/SHA-256, OAuth client, '
              'dan google-services.json.',
        );
      }

      if (e.code == GoogleSignInExceptionCode.uiUnavailable) {
        throw FirebaseAuthException(
          code: 'google-signin-ui-unavailable',
          message:
              'Google Sign-In UI tidak tersedia pada device/session ini. '
              'Silakan coba lagi.',
        );
      }

      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message:
            e.description ?? 'Google Sign-In gagal.',
      );
    } catch (e, stackTrace) {
      debugPrint('GOOGLE SIGN-IN ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out error: $e');
    }

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase sign-out error: $e');
    }
  }

  // ============================================================
  // PASSWORD RESET
  // ============================================================

  Future<void> sendPasswordResetEmail(
    String email,
  ) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // ============================================================
  // PROVIDER HELPERS
  // ============================================================

  bool usesPasswordProvider(User user) {
    return user.providerData.any(
      (info) => info.providerId == 'password',
    );
  }

  bool usesGoogleProvider(User user) {
    return user.providerData.any(
      (info) => info.providerId == 'google.com',
    );
  }

  // ============================================================
  // REAUTHENTICATION
  // ============================================================

  Future<void> reauthenticateForSensitiveAction({
    String? password,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('User not authenticated');
    }

    // ----------------------------------------------------------
    // Email/password account
    // ----------------------------------------------------------

    if (usesPasswordProvider(user)) {
      final String email = user.email ?? '';

      if (email.isEmpty) {
        throw Exception(
          'Email tidak ditemukan untuk reauthentication.',
        );
      }

      final String pass = password?.trim() ?? '';

      if (pass.isEmpty) {
        throw Exception(
          'Password diperlukan.',
        );
      }

      final AuthCredential credential =
          EmailAuthProvider.credential(
        email: email,
        password: pass,
      );

      await user.reauthenticateWithCredential(
        credential,
      );

      return;
    }

    // ----------------------------------------------------------
    // Google account
    // ----------------------------------------------------------

    if (usesGoogleProvider(user)) {
      await _ensureGoogleInitialized();

      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      if (googleAuth.idToken == null ||
          googleAuth.idToken!.isEmpty) {
        throw Exception(
          'Google ID token tidak tersedia.',
        );
      }

      final AuthCredential credential =
          GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(
        credential,
      );

      return;
    }

    throw Exception(
      'Unsupported provider for reauthentication.',
    );
  }

  // ============================================================
  // AUTH USER STREAM
  // ============================================================

  Stream<User?> get user {
    return _auth.userChanges();
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  Future<void> sendCurrentUserVerificationEmail() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User not authenticated',
      );
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

  // ============================================================
  // USERNAME VALIDATION
  // ============================================================

  bool isUsernameFormatValid(String username) {
    return RegExp(
      r'^[a-z0-9_]{3,20}$',
    ).hasMatch(username);
  }

  String normalizeUsername(String raw) {
    return raw.trim().toLowerCase();
  }

  // ============================================================
  // USERNAME AVAILABILITY
  // ============================================================

  Future<bool> isUsernameAvailable(
    String raw, {
    String? excludeUid,
  }) async {
    final String normalized = normalizeUsername(raw);

    if (!isUsernameFormatValid(normalized)) {
      return false;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore
              .collection('usernames')
              .doc(normalized)
              .get();

      if (!doc.exists) {
        return true;
      }

      if (excludeUid != null &&
          doc.data()?['uid']?.toString() == excludeUid) {
        return true;
      }

      return false;
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'USERNAME AVAILABILITY FIREBASE ERROR: '
        '${e.code} - ${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);

      throw FirebaseAuthException(
        code: 'username-check-failed',
        message:
            'Gagal memeriksa ketersediaan username. '
            'Firestore error: ${e.code}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'USERNAME AVAILABILITY ERROR: $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  // ============================================================
  // USER PROFILE
  // ============================================================

  Future<void> _upsertUserProfile(
    User user, {
    String? username,
  }) async {
    final DocumentReference<Map<String, dynamic>> userRef =
        _firestore.collection('users').doc(user.uid);

    DocumentSnapshot<Map<String, dynamic>> snapshot;

    // ----------------------------------------------------------
    // Read existing profile
    // ----------------------------------------------------------

    try {
      snapshot = await userRef.get();
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'PROFILE READ ERROR: ${e.code} - ${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);

      throw FirebaseAuthException(
        code: 'firestore-profile-read-failed',
        message:
            'Gagal membaca profile user di Firestore. '
            'Cek koneksi Firebase project dan Firestore Rules. '
            'Detail: ${e.code}',
      );
    }

    final Map<String, dynamic> existing =
        snapshot.data() ?? <String, dynamic>{};

    // ==========================================================
    // NEW USER
    // ==========================================================

    if (!snapshot.exists) {
      final String resolvedUsername;

      // --------------------------------------------------------
      // If register supplied custom username, use it.
      // The username document should already have been reserved
      // by _reserveCustomUsername().
      // --------------------------------------------------------

      if (username != null &&
          username.isNotEmpty &&
          isUsernameFormatValid(username)) {
        resolvedUsername = normalizeUsername(username);
      } else {
        // ------------------------------------------------------
        // Google / automatic username generation
        // ------------------------------------------------------

        final String base = _slugifyUsername(
          user.displayName ??
              user.email?.split('@').first ??
              'user',
        );

        resolvedUsername = await _findAvailableUsername(
          base,
        );

        // ------------------------------------------------------
        // Reserve automatically generated username
        // ------------------------------------------------------

        final String usernameLower =
            resolvedUsername.toLowerCase();

        try {
          await _firestore
              .collection('usernames')
              .doc(usernameLower)
              .set({
            'uid': user.uid,
            'username': resolvedUsername,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e, stackTrace) {
          debugPrint(
            'AUTO USERNAME CREATE ERROR: '
            '${e.code} - ${e.message}',
          );
          debugPrintStack(stackTrace: stackTrace);

          throw FirebaseAuthException(
            code: 'username-create-failed',
            message:
                'Gagal membuat username otomatis. '
                'Detail: ${e.code}',
          );
        }
      }

      // --------------------------------------------------------
      // Create user profile
      // --------------------------------------------------------

      final String usernameLower =
          resolvedUsername.toLowerCase();

      try {
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName':
              user.displayName ??
              user.email?.split('@').first ??
              'Anonymous',
          'photoUrl': user.photoURL ?? '',
          'role': 'user',
          'adminScopes': <String>[],
          'username': resolvedUsername,
          'usernameLower': usernameLower,
          'usernameChangedOnce': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e, stackTrace) {
        debugPrint(
          'PROFILE CREATE ERROR: '
          '${e.code} - ${e.message}',
        );
        debugPrintStack(stackTrace: stackTrace);

        throw FirebaseAuthException(
          code: 'firestore-profile-create-failed',
          message:
              'Gagal membuat profile user di Firestore. '
              'Cek Firestore Rules. '
              'Detail: ${e.code}',
        );
      }

      return;
    }

    // ==========================================================
    // EXISTING USER
    // ==========================================================

    try {
      await userRef.set({
        'email': user.email,
        'displayName':
            user.displayName ??
            user.email?.split('@').first ??
            'Anonymous',
        'photoUrl':
            user.photoURL ??
            existing['photoUrl'] ??
            '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'PROFILE UPDATE ERROR: '
        '${e.code} - ${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);

      throw FirebaseAuthException(
        code: 'firestore-profile-update-failed',
        message:
            'Gagal update profile user di Firestore. '
            'Cek rules dan struktur users/{uid}. '
            'Detail: ${e.code}',
      );
    }
  }

  // ============================================================
  // USERNAME RESERVATION
  // ============================================================

  Future<void> _reserveCustomUsername(
    User user,
    String username,
  ) async {
    final String normalized =
        normalizeUsername(username);

    if (!isUsernameFormatValid(normalized)) {
      throw FirebaseAuthException(
        code: 'invalid-username',
        message:
            'Username tidak valid.',
      );
    }

    final DocumentReference<Map<String, dynamic>> usernameRef =
        _firestore
            .collection('usernames')
            .doc(normalized);

    try {
      await _firestore.runTransaction(
        (Transaction tx) async {
          final DocumentSnapshot<Map<String, dynamic>> existing =
              await tx.get(usernameRef);

          // ----------------------------------------------------
          // Username already exists
          // ----------------------------------------------------

          if (existing.exists) {
            throw FirebaseAuthException(
              code: 'username-already-in-use',
              message:
                  'Username is already in use.',
            );
          }

          // ----------------------------------------------------
          // Reserve username
          // ----------------------------------------------------

          tx.set(
            usernameRef,
            {
              'uid': user.uid,
              'username': normalized,
              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );

          // ----------------------------------------------------
          // Also create the minimum user profile data.
          // _upsertUserProfile() will complete it afterwards.
          // ----------------------------------------------------

          tx.set(
            _firestore
                .collection('users')
                .doc(user.uid),
            {
              'uid': user.uid,
              'username': normalized,
              'usernameLower': normalized,
              'usernameChangedOnce': false,
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        },
      );
    } on FirebaseAuthException {
      rethrow;
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'USERNAME RESERVATION ERROR: '
        '${e.code} - ${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);

      throw FirebaseAuthException(
        code: 'username-reservation-failed',
        message:
            'Gagal menyimpan username. '
            'Firestore error: ${e.code}',
      );
    }
  }

  // ============================================================
  // AUTOMATIC USERNAME GENERATION
  // ============================================================

  String _slugifyUsername(String raw) {
    String value = raw.trim().toLowerCase();

    value = value.replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '_',
    );

    value = value.replaceAll(
      RegExp(r'_+'),
      '_',
    );

    value = value.replaceAll(
      RegExp(r'^_+|_+$'),
      '',
    );

    if (value.length < 3) {
      value = '${value}user';
    }

    if (value.length > 20) {
      value = value.substring(0, 20);
    }

    return value;
  }

  Future<String> _findAvailableUsername(
    String base,
  ) async {
    String candidate =
        _slugifyUsername(base);

    for (int i = 0; i < 30; i++) {
      final String name =
          i == 0 ? candidate : '$candidate$i';

      if (!isUsernameFormatValid(name)) {
        continue;
      }

      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore
              .collection('usernames')
              .doc(name)
              .get();

      if (!doc.exists) {
        return name;
      }
    }

    final int millis =
        DateTime.now().millisecondsSinceEpoch %
            100000;

    String seed =
        '${candidate}_$millis';

    if (seed.length > 20) {
      seed = seed.substring(0, 20);
    }

    if (isUsernameFormatValid(seed)) {
      return seed;
    }

    return 'user$millis';
  }

  // ============================================================
  // ROLLBACK FAILED REGISTRATION
  // ============================================================

  Future<void> _rollbackFailedSignUp(
    User user,
  ) async {
    debugPrint(
      'Rolling back failed sign-up for UID: ${user.uid}',
    );

    // ----------------------------------------------------------
    // Remove username documents owned by this UID
    // ----------------------------------------------------------

    try {
      final QuerySnapshot<Map<String, dynamic>> usernameDocs =
          await _firestore
              .collection('usernames')
              .where(
                'uid',
                isEqualTo: user.uid,
              )
              .limit(10)
              .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in usernameDocs.docs) {
        try {
          await doc.reference.delete();
        } catch (e) {
          debugPrint(
            'Rollback username delete failed: $e',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'Rollback username query failed: $e',
      );
    }

    // ----------------------------------------------------------
    // Remove user profile
    // ----------------------------------------------------------

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .delete();
    } catch (e) {
      debugPrint(
        'Rollback profile delete failed: $e',
      );
    }

    // ----------------------------------------------------------
    // Remove Firebase Authentication account
    // ----------------------------------------------------------

    try {
      await user.delete();
    } catch (e) {
      debugPrint(
        'Rollback Firebase Auth delete failed: $e',
      );
    }
  }
}
