import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserLocation {
  final String city;
  final String governorate;

  const UserLocation({
    required this.city,
    required this.governorate,
  });

  String get fullLocation => '$city، $governorate';
}

final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, UserLocation>((ref) {
  return UserLocationNotifier();
});

class UserLocationNotifier extends StateNotifier<UserLocation> {
  UserLocationNotifier()
      : super(const UserLocation(city: 'كفر الزيات', governorate: 'الغربية')) {
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString('user_city');
    final savedGov = prefs.getString('user_governorate');
    if (savedCity != null && savedGov != null) {
      state = UserLocation(city: savedCity, governorate: savedGov);
    }
  }

  Future<void> setLocation(String city, String governorate) async {
    state = UserLocation(city: city, governorate: governorate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_city', city);
    await prefs.setString('user_governorate', governorate);
  }
}
