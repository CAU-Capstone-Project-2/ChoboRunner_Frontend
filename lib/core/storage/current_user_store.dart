import 'package:shared_preferences/shared_preferences.dart';

/// 현재 로그인된 사용자 id를 SharedPreferences에 영속화한다.
/// 앱 전역에서 사용되는 공용 저장소.
class CurrentUserStore {
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
