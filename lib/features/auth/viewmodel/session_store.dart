import 'package:shared_preferences/shared_preferences.dart';

/// 현재 로그인된 사용자 id를 SharedPreferences에 영속화한다.
///
/// 키 하나만 다룬다. 토큰 기반 인증이 추가되면 토큰도 여기에 보관.
class SessionStore {
  static const String _kUserIdKey = 'auth.currentUserId';

  Future<String?> readUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserIdKey);
  }

  Future<void> writeUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserIdKey, userId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserIdKey);
  }
}
