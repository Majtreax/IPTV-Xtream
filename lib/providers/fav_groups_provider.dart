import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final favoriteGroupsProvider =
    StateNotifierProvider<FavoriteGroupsNotifier, List<String?>>((ref) {
      return FavoriteGroupsNotifier();
    });

class FavoriteGroupsNotifier extends StateNotifier<List<String?>> {
  FavoriteGroupsNotifier() : super([null, null, null]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = [
      prefs.getString('fav_col_0'),
      prefs.getString('fav_col_1'),
      prefs.getString('fav_col_2'),
    ];
    state = list;
  }

  Future<void> setColumnCategory(int columnIndex, String? categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    if (categoryId == null) {
      await prefs.remove('fav_col_$columnIndex');
    } else {
      await prefs.setString('fav_col_$columnIndex', categoryId);
    }
    final newList = List<String?>.from(state);
    newList[columnIndex] = categoryId;
    state = newList;
  }
}
