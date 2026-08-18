import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

enum AuthFailure {
  invalidCredentials,
  emailNotConfirmed,
  emailAlreadyRegistered,
  weakPassword,
  network,
  unknown,
}

class AuthResult {
  const AuthResult._({
    required this.success,
    this.failure,
    this.needsEmailConfirmation = false,
    this.message,
  });

  final bool success;
  final AuthFailure? failure;
  final bool needsEmailConfirmation;
  final String? message;

  factory AuthResult.ok() => const AuthResult._(success: true);

  factory AuthResult.needsConfirmation() => const AuthResult._(
        success: false,
        needsEmailConfirmation: true,
      );

  factory AuthResult.fail(AuthFailure failure, {String? message}) =>
      AuthResult._(success: false, failure: failure, message: message);
}

class AuthService {
  AuthService._();

  static bool get isConfigured => SupabaseConfig.isConfigured;

  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser =>
      isConfigured ? _client.auth.currentUser : null;

  static bool get hasSession =>
      isConfigured && _client.auth.currentSession != null;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) {
      return AuthResult.fail(AuthFailure.unknown);
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        return AuthResult.fail(AuthFailure.unknown);
      }
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(
        _mapAuthException(e),
        message: e.message,
      );
    } catch (_) {
      return AuthResult.fail(AuthFailure.network);
    }
  }

  static Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!isConfigured) {
      return AuthResult.fail(AuthFailure.unknown);
    }

    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': name.trim()},
      );

      if (response.session != null) {
        return AuthResult.ok();
      }
      if (response.user != null) {
        return AuthResult.needsConfirmation();
      }
      return AuthResult.fail(AuthFailure.unknown);
    } on AuthException catch (e) {
      return AuthResult.fail(
        _mapAuthException(e),
        message: e.message,
      );
    } catch (_) {
      return AuthResult.fail(AuthFailure.network);
    }
  }

  static Future<void> signOut() async {
    if (!isConfigured) return;
    await _client.auth.signOut();
  }

  /// Resend signup confirmation email (for accounts created while confirm was on).
  static Future<AuthResult> resendSignupConfirmation(String email) async {
    if (!isConfigured) {
      return AuthResult.fail(AuthFailure.unknown);
    }

    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.fail(
        _mapAuthException(e),
        message: e.message,
      );
    } catch (_) {
      return AuthResult.fail(AuthFailure.network);
    }
  }

  static AuthFailure _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return AuthFailure.invalidCredentials;
    }
    if (msg.contains('email not confirmed')) {
      return AuthFailure.emailNotConfirmed;
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return AuthFailure.emailAlreadyRegistered;
    }
    if (msg.contains('password') && msg.contains('weak')) {
      return AuthFailure.weakPassword;
    }
    return AuthFailure.unknown;
  }

  static String failureMessage(AuthFailure failure) {
    return switch (failure) {
      AuthFailure.invalidCredentials =>
        'Email or password is incorrect.',
      AuthFailure.emailNotConfirmed =>
        'Please confirm your email before signing in. '
        'If you registered before turning off email confirmation in Supabase, '
        'delete the user under Authentication → Users and sign up again, '
        'or tap “Resend confirmation email” below.',
      AuthFailure.emailAlreadyRegistered =>
        'An account with this email already exists.',
      AuthFailure.weakPassword =>
        'Password is too weak — use at least 6 characters.',
      AuthFailure.network =>
        'Network error. Check your connection and try again.',
      AuthFailure.unknown =>
        'Something went wrong. Please try again.',
    };
  }
}
