import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<String>> {
  static const _key = 'favorite_tech_ids';

  FavoritesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? [];
  }

  Future<void> toggleFavorite(String techId) async {
    final prefs = await SharedPreferences.getInstance();
    if (state.contains(techId)) {
      state = state.where((id) => id != techId).toList();
    } else {
      state = [...state, techId];
    }
    await prefs.setStringList(_key, state);
  }

  bool isFavorite(String techId) => state.contains(techId);
}
