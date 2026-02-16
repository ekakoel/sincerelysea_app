import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthExceptionHandler {
  static String handleException(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'Email is not registered.';
        case 'invalid-email':
          return 'Invalid email format.';
        case 'email-already-in-use':
          return 'Email is already in use.';
        case 'weak-password':
          return 'Password is too weak.';
        case 'wrong-password':
          return 'Wrong password.';
        case 'invalid-credential':
          return 'Invalid credentials. Please sign in again.';
        case 'requires-recent-login':
          return 'Session is too old. Please sign in again.';
        case 'user-mismatch':
          return 'Account does not match for re-verification.';
        case 'user-disabled':
          return 'Account is disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Failed to connect to the internet.';
        default:
          return e.message ?? 'Authentication error occurred.';
      }
    }
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'failed-precondition':
          return 'Please reauthenticate your account, then try again.';
        case 'unauthenticated':
          return 'Session expired. Please sign in again.';
        case 'permission-denied':
          return 'You do not have permission for this action.';
        case 'not-found':
          return 'Data not found.';
        case 'resource-exhausted':
          return 'Too many requests. Please try again shortly.';
        case 'deadline-exceeded':
          return 'Request timed out. Check your connection and try again.';
        default:
          return e.message ?? 'Server error occurred.';
      }
    }
    return 'Error: $e';
  }
}
