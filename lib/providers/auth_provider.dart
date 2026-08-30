import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_xtream/data/repositories/auth_repository.dart';
import 'package:iptv_xtream/data/parsers/m3u_parser.dart';
import 'package:iptv_xtream/models/server_model.dart';

// ---------------------------------------------------------------------------
// AUTH STATE
// ---------------------------------------------------------------------------

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final ServerInfo? serverInfo;
  final String? errorMessage;
  final ParseResult? m3uData;

  const AuthState({
    this.status = AuthStatus.initial,
    this.serverInfo,
    this.errorMessage,
    this.m3uData,
  });

  const AuthState.initial() : this();

  AuthState copyWith({
    AuthStatus? status,
    ServerInfo? serverInfo,
    String? errorMessage,
    ParseResult? m3uData,
  }) {
    return AuthState(
      status: status ?? this.status,
      serverInfo: serverInfo ?? this.serverInfo,
      errorMessage: errorMessage,
      m3uData: m3uData ?? this.m3uData,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

// ---------------------------------------------------------------------------
// AUTH NOTIFIER
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  bool _isRestoring = false;

  AuthNotifier(this._repository) : super(const AuthState(status: AuthStatus.loading)) {
    restoreSession();
  }

  // LOGIN WITH XTREAM CODES CREDENTIALS
  Future<void> loginWithXtream({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final serverInfo = await _repository.loginWithXtream(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        serverInfo: serverInfo,
      );
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  // LOGIN WITH AN M3U PLAYLIST URL
  Future<void> loginWithM3u({required String m3uUrl}) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final result = await _repository.loginWithM3u(m3uUrl: m3uUrl);

      state = AuthState(
        status: AuthStatus.authenticated,
        serverInfo: result.serverInfo,
        m3uData: result.parseResult,
      );
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  void setError(String? error) {
    if (error == null) {
      state = state.copyWith(errorMessage: null);
    } else {
      state = AuthState(status: AuthStatus.error, errorMessage: error);
    }
  }

  // TRY TO RESTORE A PREVIOUS SESSION
  Future<void> restoreSession() async {
    if (_isRestoring) return;
    _isRestoring = true;
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final loginType = await _repository.getSavedLoginType();
      if (loginType == 'm3u') {
        final m3uUrl = await _repository.getSavedM3uUrl();
        if (m3uUrl != null && m3uUrl.isNotEmpty) {
          await loginWithM3u(m3uUrl: m3uUrl);
          if (state.status == AuthStatus.error) {
            // M3U LOADING FAILED FALLBACK TO SAVED XTREAM CREDENTIALS IF AVAILABLE
            final serverInfo = await _repository.restoreSession();
            if (serverInfo != null) {
              state = AuthState(
                status: AuthStatus.authenticated,
                serverInfo: serverInfo,
              );
            }
          }
          return;
        }
      }

      final serverInfo = await _repository.restoreSession();
      if (serverInfo != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          serverInfo: serverInfo,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    } finally {
      _isRestoring = false;
    }
  }

  // LOGOUT AND CLEAR ALL CREDENTIALS
  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// ---------------------------------------------------------------------------
// PROVIDERS
// ---------------------------------------------------------------------------

// REPOSITORY PROVIDER
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// AUTH STATE PROVIDER
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

// CONVENIENCE PROVIDER FOR CHECKING IF THE USER IS AUTHENTICATED
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

// PROVIDES THE ACTIVE SERVER INFO (NULL IF NOT LOGGED IN)
final serverInfoProvider = Provider<ServerInfo?>((ref) {
  return ref.watch(authProvider).serverInfo;
});
