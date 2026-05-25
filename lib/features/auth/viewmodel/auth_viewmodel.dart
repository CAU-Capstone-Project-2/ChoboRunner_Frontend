import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/user.dart';
import '../model/user_api_service.dart';
import 'session_store.dart';

/// 로그인 상태.
///
/// - [unknown]: 앱 시작 직후, 저장된 세션을 읽기 전. 라우터는 이 동안 splash를 보임.
/// - [signedOut]: 세션 없음. 로그인/회원가입 화면으로 보냄.
/// - [signedIn]: [userId]가 설정됨. 정상 화면 진입 가능.
enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? error;
  final bool isBusy;

  const AuthState({
    required this.status,
    this.userId,
    this.error,
    this.isBusy = false,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? error,
    bool? isBusy,
    bool clearError = false,
    bool clearUserId = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: clearUserId ? null : (userId ?? this.userId),
      error: clearError ? null : (error ?? this.error),
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

class AuthViewModel extends Notifier<AuthState> {
  late final UserApiService _api;
  late final SessionStore _store;

  @override
  AuthState build() {
    _api = ref.read(userApiServiceProvider);
    _store = ref.read(sessionStoreProvider);
    // 비동기로 저장된 세션 복구
    _restore();
    return const AuthState.unknown();
  }

  Future<void> _restore() async {
    final userId = await _store.readUserId();
    if (userId == null || userId.isEmpty) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }
    state = AuthState(status: AuthStatus.signedIn, userId: userId);
  }

  /// 로그인 — `POST /api/users/login {username, password}`.
  Future<bool> signIn({required String username, required String password}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await _api.login(username: username, password: password);
      await _store.writeUserId(user.id);
      state = AuthState(status: AuthStatus.signedIn, userId: user.id);
      return true;
    } on InvalidCredentialsException {
      state = state.copyWith(isBusy: false, error: '아이디 또는 비밀번호가 일치하지 않습니다.');
      return false;
    } on UserApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.userMessage);
      return false;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: '로그인 실패: $e');
      return false;
    }
  }

  /// 회원가입.
  ///
  /// User.id는 백엔드가 자동 발급(Integer). 응답 body의 id를 세션에 저장.
  /// username 중복은 [findByUsername]으로 사전 체크.
  Future<bool> signUp({required String username, required String password}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final existing = await _api.findByUsername(username);
      if (existing != null) {
        state = state.copyWith(isBusy: false, error: '이미 사용 중인 아이디입니다.');
        return false;
      }
      final created = await _api.createUser(User(
        id: '',
        username: username,
        password: password,
      ));
      await _store.writeUserId(created.id);
      state = AuthState(status: AuthStatus.signedIn, userId: created.id);
      return true;
    } on UserApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.userMessage);
      return false;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: '회원가입 실패: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _store.clear();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final userApiServiceProvider = Provider<UserApiService>((ref) {
  return UserApiService();
});

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SessionStore();
});

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthState>(AuthViewModel.new);
