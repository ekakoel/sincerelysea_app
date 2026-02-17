import 'package:shared_preferences/shared_preferences.dart';

class HiddenContentPreferences {
  const HiddenContentPreferences({
    required this.hideTextOnlyPosts,
    required this.hidePostsWithMutedKeywords,
    required this.mutedKeywords,
  });

  final bool hideTextOnlyPosts;
  final bool hidePostsWithMutedKeywords;
  final List<String> mutedKeywords;
}

class HiddenContentPreferencesService {
  static const String _kHideTextOnlyPosts = 'hidden_pref_hide_text_only_posts';
  static const String _kHideMutedKeywords = 'hidden_pref_hide_muted_keywords';
  static const String _kMutedKeywordsCsv = 'hidden_pref_muted_keywords_csv';

  Future<HiddenContentPreferences> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return HiddenContentPreferences(
      hideTextOnlyPosts: prefs.getBool(_kHideTextOnlyPosts) ?? false,
      hidePostsWithMutedKeywords: prefs.getBool(_kHideMutedKeywords) ?? true,
      mutedKeywords: _parseKeywords(prefs.getString(_kMutedKeywordsCsv) ?? ''),
    );
  }

  Future<void> setHideTextOnlyPosts(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHideTextOnlyPosts, value);
  }

  Future<void> setHidePostsWithMutedKeywords(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHideMutedKeywords, value);
  }

  Future<void> setMutedKeywords(String rawValue) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> keywords = _parseKeywords(rawValue);
    await prefs.setString(_kMutedKeywordsCsv, keywords.join(','));
  }

  bool shouldHidePostByPreferences(
    Map<String, dynamic> postData,
    HiddenContentPreferences preferences,
  ) {
    if (preferences.hideTextOnlyPosts) {
      final String imageUrl = postData['imageUrl']?.toString().trim() ?? '';
      if (imageUrl.isEmpty) {
        return true;
      }
    }

    if (preferences.hidePostsWithMutedKeywords &&
        preferences.mutedKeywords.isNotEmpty) {
      final String content = postData['content']?.toString().toLowerCase() ?? '';
      final List<String> hashtags =
          (postData['hashtags'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic tag) => tag.toString().toLowerCase())
              .toList();
      final String haystack = '$content ${hashtags.join(' ')}';
      for (final String keyword in preferences.mutedKeywords) {
        if (keyword.isNotEmpty && haystack.contains(keyword)) {
          return true;
        }
      }
    }

    return false;
  }

  List<String> _parseKeywords(String rawValue) {
    final Set<String> seen = <String>{};
    final List<String> keywords = <String>[];
    final List<String> parts = rawValue
        .toLowerCase()
        .split(RegExp(r'[,\\n]+'))
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    for (final String part in parts) {
      if (seen.add(part)) {
        keywords.add(part);
      }
    }
    return keywords;
  }
}
