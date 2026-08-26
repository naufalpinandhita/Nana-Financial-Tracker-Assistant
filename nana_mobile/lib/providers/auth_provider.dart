import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../models/user_profile.dart';
import 'app_providers.dart';

enum AuthStatus { unknown, authenticated, needsProfileSetup, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;
  final bool isLoading;

  AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(AuthState(status: AuthStatus.unknown, isLoading: true)) {
    checkAuthStatus();
  }

  ApiService get _api => _ref.read(apiServiceProvider);

  /// Set token in memory (authTokenProvider) AND persist to SharedPreferences.
  Future<void> _setToken(String token) async {
    _ref.read(authTokenProvider.notifier).state = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// Clear token from memory AND SharedPreferences.
  Future<void> _clearToken() async {
    _ref.read(authTokenProvider.notifier).state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('jwt_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        _ref.read(authTokenProvider.notifier).state = savedToken;
        final user = await _api.getMe();
        if (user != null) {
          // If username is not set, send to profile setup
          final status = (user.username == null || user.username!.isEmpty)
              ? AuthStatus.needsProfileSetup
              : AuthStatus.authenticated;
          state = AuthState(status: status, user: user);
          return;
        }
      }
    } catch (_) {}
    await _clearToken();
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Clear any existing token first
      await _clearToken();
      final res = await _api.register(name: name, email: email, password: password);
      final newToken = res['token'] as String?;
      if (newToken != null) {
        await _setToken(newToken);
      }
      final user = UserProfile.fromJson(res['user']);
      // After register, always go to profile setup (username not set yet)
      state = AuthState(status: AuthStatus.needsProfileSetup, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _clearToken();
      final res = await _api.login(identifier: identifier, password: password);
      final newToken = res['token'] as String?;
      if (newToken != null) {
        await _setToken(newToken);
      }
      final user = UserProfile.fromJson(res['user']);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _clearToken();
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final authentication = await account.authentication;
      final res = await _api.loginWithGoogle(
        idToken: authentication.idToken,
        email: account.email,
        name: account.displayName,
        googleId: account.id,
        avatarUrl: account.photoUrl,
      );

      final newToken = res['token'] as String?;
      if (newToken != null) {
        await _setToken(newToken);
      }
      final user = UserProfile.fromJson(res['user']);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> setupProfile({
    required String username,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updatedUser = await _api.setupProfile(
        username: username,
        avatarUrl: avatarUrl,
      );
      state = AuthState(status: AuthStatus.authenticated, user: updatedUser);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {    await _clearToken();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    state = AuthState(status: AuthStatus.unauthenticated, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
