import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Owns only Firebase's SMS challenge. Application sessions continue to be
/// issued by FastAPI after it verifies the resulting Firebase ID token.
class FirebasePhoneAuthService {
  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;

  FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Firebase Phone OTP is not configured. Add the Firebase app settings '
        'and enable Phone Authentication.',
      );
    }
    return FirebaseAuth.instance;
  }

  String normalizeIndianPhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    throw const FormatException('Enter a valid 10-digit Indian mobile number');
  }

  Future<void> sendOtp(String rawPhone) async {
    final phone = normalizeIndianPhone(rawPhone);
    _verificationId = null;
    _webConfirmation = null;

    if (kIsWeb) {
      _webConfirmation = await _auth.signInWithPhoneNumber(phone);
      return;
    }

    final sent = Completer<void>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {
        // Keep the same explicit six-digit-code UX on every platform. Android
        // may still suggest/autofill the received code at the keyboard level.
      },
      verificationFailed: (error) {
        if (!sent.isCompleted) sent.completeError(error);
      },
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!sent.isCompleted) sent.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId ??= verificationId;
      },
    );
    await sent.future.timeout(const Duration(seconds: 90));
  }

  Future<String> verifyOtp(String smsCode) async {
    final UserCredential credential;
    if (kIsWeb) {
      final confirmation = _webConfirmation;
      if (confirmation == null) {
        throw StateError('Request a new OTP before verifying the code.');
      }
      credential = await confirmation.confirm(smsCode);
    } else {
      final verificationId = _verificationId;
      if (verificationId == null) {
        throw StateError('Request a new OTP before verifying the code.');
      }
      final phoneCredential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      credential = await _auth.signInWithCredential(phoneCredential);
    }

    final idToken = await credential.user?.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Firebase did not return an authentication token.');
    }

    // FastAPI owns the durable application session; Firebase is used only to
    // prove control of the phone number for this OTP exchange.
    await _auth.signOut();
    return idToken;
  }
}
