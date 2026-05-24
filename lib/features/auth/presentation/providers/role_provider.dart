import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final userRoleProvider = StateNotifierProvider<UserRoleNotifier, String?>((ref) {
  return UserRoleNotifier();
});

class UserRoleNotifier extends StateNotifier<String?> {
  UserRoleNotifier() : super(null) {
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('user_role');
  }

  Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
    state = role;
  }

  Future<void> clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    state = null;
  }
}
