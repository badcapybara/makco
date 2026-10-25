import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _favouritesKey = 'makco_favourite_stations';

/// Station codes the rider has starred, persisted locally.
class FavouritesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    Future<void>.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = (prefs.getStringList(_favouritesKey) ?? const []).toSet();
    } catch (_) {
      state = const {};
    }
  }

  Future<void> _persist(Set<String> codes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favouritesKey, codes.toList());
    } catch (_) {}
  }

  bool contains(String code) => state.contains(code);

  Future<void> toggle(String code) async {
    final next = {...state};
    if (!next.remove(code)) next.add(code);
    state = next;
    await _persist(next);
  }
}

final favouritesProvider = NotifierProvider<FavouritesController, Set<String>>(
  FavouritesController.new,
);
