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
  String? _automaticIdToken;
  String? _lastPhone;
  int _requestGeneration = 0;

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

  /// Returns true when Android completed phone verification automatically.
  Future<bool> sendOtp(String rawPhone) async {
    final phone = normalizeIndianPhone(rawPhone);
    final generation = ++_requestGeneration;
    if (_lastPhone != phone) {
      _resendToken = null;
      _lastPhone = phone;
    }
    _verificationId = null;
    _webConfirmation = null;
    _automaticIdToken = null;

    if (kIsWeb) {
      _webConfirmation = await _auth.signInWithPhoneNumber(phone);
      return false;
    }

    final sent = Completer<bool>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (phoneCredential) async {
        if (generation != _requestGeneration) return;
        try {
          final credential = await _auth.signInWithCredential(phoneCredential);
          final token = await credential.user?.getIdToken(true);
          if (generation != _requestGeneration) return;
          if (token != null && token.isNotEmpty) {
            _automaticIdToken = token;
            if (!sent.isCompleted) sent.complete(true);
          } else if (!sent.isCompleted) {
            sent.completeError(
              StateError('Firebase did not return an authentication token.'),
            );
          }
        } catch (error, stackTrace) {
          if (!sent.isCompleted) sent.completeError(error, stackTrace);
        } finally {
          try {
            await _auth.signOut();
          } catch (_) {}
        }
      },
      verificationFailed: (error) {
        if (generation != _requestGeneration) return;
        if (!sent.isCompleted) sent.completeError(error);
      },
      codeSent: (verificationId, resendToken) {
        if (generation != _requestGeneration) return;
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!sent.isCompleted) sent.complete(false);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (generation != _requestGeneration) return;
        _verificationId ??= verificationId;
      },
    );
    return sent.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw TimeoutException(
        'Phone verification timed out. Check the network and request a new OTP.',
      ),
    );
  }

  Future<String> verifyOtp(String smsCode) async {
    final automaticToken = _automaticIdToken;
    if (automaticToken != null && automaticToken.isNotEmpty) {
      _automaticIdToken = null;
      return automaticToken;
    }

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
