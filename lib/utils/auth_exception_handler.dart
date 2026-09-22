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
          return 'Authentication failed. Please try again.';
      }
    }
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'failed-precondition':
          return _failedPreconditionMessage(e.message);
        case 'unauthenticated':
          return 'Your session could not be verified. Restart the app, sign in, and try again.';
        case 'permission-denied':
          return 'You do not have permission for this action.';
        case 'invalid-argument':
          return 'Some submitted information is invalid. Review it and try again.';
        case 'not-found':
          return 'The requested item is no longer available.';
        case 'resource-exhausted':
          return 'Too many requests. Please try again shortly.';
        case 'deadline-exceeded':
          return 'Request timed out. Check your connection and try again.';
        case 'unavailable':
          return 'The service is temporarily unavailable. Please try again.';
        default:
          return 'The request could not be completed. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  static String _failedPreconditionMessage(String? rawMessage) {
    final String message = (rawMessage ?? '').toLowerCase();
    if (message.contains('recent login') ||
        message.contains('reauthenticate')) {
      return 'Please sign in again, then retry this action.';
    }
    if (message.contains('only pending')) {
      return 'Only pending orders can be cancelled.';
    }
    if (message.contains('legacy order') || message.contains('restock')) {
      return 'This order cannot be cancelled in the app. Contact Support for help.';
    }
    if (message.contains('stock')) {
      return 'Some products do not have enough stock. Review your cart and try again.';
    }
    if (message.contains('product') ||
        message.contains('inventory') ||
        message.contains('price') ||
        message.contains('order items')) {
      return 'Some cart items changed or are unavailable. Review your cart and try again.';
    }
    return 'This action cannot be completed right now.';
  }
}
