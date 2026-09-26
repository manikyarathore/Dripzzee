import 'package:shared_preferences/shared_preferences.dart';

/// Recent search queries, per user, on this device.
class RecentSearchStore {
  static const _max = 8;

  String _key(String uid) => 'recent_searches_$uid';

  Future<List<String>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key(uid)) ?? <String>[];
  }

  Future<List<String>> add(String uid, String query) async {
    final q = query.trim();
    final list = await load(uid);
    if (q.isEmpty) return list;
    list.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
    list.insert(0, q);
    final trimmed = list.take(_max).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(uid), trimmed);
    return trimmed;
  }

  Future<List<String>> remove(String uid, String query) async {
    final list = await load(uid)
      ..remove(query);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(uid), list);
    return list;
  }

  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}
