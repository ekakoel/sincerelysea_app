import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/theme/app_semantic_colors.dart';
import 'package:sincerelysea/screens/post/shared_post_detail_screen.dart';
import 'package:sincerelysea/screens/profile/user_profile_preview_screen.dart';
import 'package:sincerelysea/services/discovery_service.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  static const int _pageSize = 20;
  static const Duration _searchDebounce = Duration(milliseconds: 400);
  final TextEditingController _queryController = TextEditingController();
  Timer? _searchDebounceTimer;
  int _searchRequestId = 0;
  String _activeQuery = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _userResults =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _hashtagResults =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _suggestedUsers =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastUserDoc;
  DocumentSnapshot<Map<String, dynamic>>? _lastHashtagDoc;
  bool _hasMoreUsers = true;
  bool _hasMoreHashtags = true;
  bool _loadingUsersMore = false;
  bool _loadingHashtagsMore = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }
      _search();
    });
  }

  Future<void> _loadSuggestions() async {
    final DiscoveryService service = context.read<DiscoveryService>();
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> data = await service
        .suggestedUsers();
    if (!mounted) {
      return;
    }
    setState(() => _suggestedUsers = data);
  }

  Future<void> _search() async {
    final int requestId = ++_searchRequestId;
    final String query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _activeQuery = '';
        _userResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        _hashtagResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        _lastUserDoc = null;
        _lastHashtagDoc = null;
        _hasMoreUsers = true;
        _hasMoreHashtags = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _activeQuery = query;
      _userResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      _hashtagResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      _lastUserDoc = null;
      _lastHashtagDoc = null;
      _hasMoreUsers = true;
      _hasMoreHashtags = true;
    });
    final DiscoveryService service = context.read<DiscoveryService>();
    final String userBackendQuery = _backendSeedQuery(query);
    final String hashtagBackendQuery = _backendSeedQuery(
      query,
      isHashtag: true,
    );
    try {
      final List<QuerySnapshot<Map<String, dynamic>>> pages =
          await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
            service.searchUsersPage(userBackendQuery, limit: _pageSize),
            service.searchByHashtagPage(hashtagBackendQuery, limit: _pageSize),
          ]);
      if (!mounted ||
          requestId != _searchRequestId ||
          _queryController.text.trim() != query) {
        return;
      }
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredUsers =
          _rankUsersByRelevance(pages[0].docs, query);
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredHashtags =
          _rankHashtagPostsByRelevance(pages[1].docs, query);
      setState(() {
        _userResults = filteredUsers;
        _hashtagResults = filteredHashtags;
        _lastUserDoc = pages[0].docs.isNotEmpty ? pages[0].docs.last : null;
        _lastHashtagDoc = pages[1].docs.isNotEmpty ? pages[1].docs.last : null;
        _hasMoreUsers = pages[0].docs.length >= _pageSize;
        _hasMoreHashtags = pages[1].docs.length >= _pageSize;
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoading ||
        _loadingUsersMore ||
        !_hasMoreUsers ||
        _activeQuery.isEmpty) {
      return;
    }
    setState(() => _loadingUsersMore = true);
    try {
      final String backendQuery = _backendSeedQuery(_activeQuery);
      final QuerySnapshot<Map<String, dynamic>> page = await context
          .read<DiscoveryService>()
          .searchUsersPage(
            backendQuery,
            startAfter: _lastUserDoc,
            limit: _pageSize,
          );
      if (!mounted) {
        return;
      }
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredUsers =
          _rankUsersByRelevance(page.docs, _activeQuery);
      setState(() {
        _userResults.addAll(filteredUsers);
        _lastUserDoc = page.docs.isNotEmpty ? page.docs.last : _lastUserDoc;
        _hasMoreUsers = page.docs.length >= _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingUsersMore = false);
      }
    }
  }

  Future<void> _loadMoreHashtags() async {
    if (_isLoading ||
        _loadingHashtagsMore ||
        !_hasMoreHashtags ||
        _activeQuery.isEmpty) {
      return;
    }
    setState(() => _loadingHashtagsMore = true);
    try {
      final String backendQuery = _backendSeedQuery(
        _activeQuery,
        isHashtag: true,
      );
      final QuerySnapshot<Map<String, dynamic>> page = await context
          .read<DiscoveryService>()
          .searchByHashtagPage(
            backendQuery,
            startAfter: _lastHashtagDoc,
            limit: _pageSize,
          );
      if (!mounted) {
        return;
      }
      final List<QueryDocumentSnapshot<Map<String, dynamic>>>
      filteredHashtags = _rankHashtagPostsByRelevance(page.docs, _activeQuery);
      setState(() {
        _hashtagResults.addAll(filteredHashtags);
        _lastHashtagDoc = page.docs.isNotEmpty
            ? page.docs.last
            : _lastHashtagDoc;
        _hasMoreHashtags = page.docs.length >= _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingHashtagsMore = false);
      }
    }
  }

  String _backendSeedQuery(String query, {bool isHashtag = false}) {
    final List<String> tokens = _queryTokens(query);
    if (tokens.isEmpty) {
      return '';
    }
    final String firstToken = tokens.first;
    if (isHashtag) {
      return firstToken.startsWith('#') ? firstToken : '#$firstToken';
    }
    return firstToken;
  }

  List<String> _queryTokens(String query) {
    return query
        .trim()
        .toLowerCase()
        .split(RegExp(r'[,\s]+'))
        .map((String token) => token.trim())
        .where((String token) => token.isNotEmpty)
        .toSet()
        .toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _rankUsersByRelevance(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String query,
  ) {
    final List<String> tokens = _queryTokens(query);
    if (tokens.isEmpty) {
      return docs;
    }
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final Map<String, dynamic> aData = a.data();
      final Map<String, dynamic> bData = b.data();
      final String aHaystack =
          '${aData['username']?.toString().toLowerCase() ?? ''} '
          '${aData['displayName']?.toString().toLowerCase() ?? ''}';
      final String bHaystack =
          '${bData['username']?.toString().toLowerCase() ?? ''} '
          '${bData['displayName']?.toString().toLowerCase() ?? ''}';
      return _compareRelevance(aHaystack, bHaystack, tokens);
    });
    return sorted.where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final Map<String, dynamic> data = doc.data();
      final String username = data['username']?.toString().toLowerCase() ?? '';
      final String displayName =
          data['displayName']?.toString().toLowerCase() ?? '';
      final String haystack = '$username $displayName';
      return tokens.any((String token) => haystack.contains(token));
    }).toList();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _rankHashtagPostsByRelevance(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String query,
  ) {
    final List<String> tokens = _queryTokens(query)
        .map((String token) => token.startsWith('#') ? token : '#$token')
        .toList();
    if (tokens.isEmpty) {
      return docs;
    }
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final List<String> aHashtags =
          (a.data()['hashtags'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString().toLowerCase())
              .toList();
      final List<String> bHashtags =
          (b.data()['hashtags'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString().toLowerCase())
              .toList();
      return _compareRelevance(
        aHashtags.join(' '),
        bHashtags.join(' '),
        tokens,
      );
    });
    return sorted.where((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final List<String> hashtags =
          (doc.data()['hashtags'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic value) => value.toString().toLowerCase())
              .toList();
      return tokens.any(
        (String token) => hashtags.any(
          (String hashtag) =>
              hashtag.contains(token) ||
              hashtag.replaceFirst('#', '').contains(token.replaceFirst('#', '')),
        ),
      );
    }).toList();
  }

  int _compareRelevance(String aHaystack, String bHaystack, List<String> tokens) {
    final _RelevanceScore aScore = _scoreText(aHaystack, tokens);
    final _RelevanceScore bScore = _scoreText(bHaystack, tokens);

    if (aScore.fullMatch != bScore.fullMatch) {
      return aScore.fullMatch ? -1 : 1;
    }
    if (aScore.matchCount != bScore.matchCount) {
      return bScore.matchCount.compareTo(aScore.matchCount);
    }
    if (aScore.tightness != bScore.tightness) {
      return aScore.tightness.compareTo(bScore.tightness);
    }
    return aScore.firstMatchIndex.compareTo(bScore.firstMatchIndex);
  }

  _RelevanceScore _scoreText(String haystack, List<String> tokens) {
    final List<int> positions = <int>[];
    for (final String token in tokens) {
      final int index = haystack.indexOf(token);
      if (index >= 0) {
        positions.add(index);
      }
    }
    positions.sort();
    final bool fullMatch = positions.length == tokens.length;
    final int tightness = positions.length <= 1
        ? 0
        : positions.last - positions.first;
    final int firstMatchIndex = positions.isEmpty ? 1 << 20 : positions.first;
    return _RelevanceScore(
      fullMatch: fullMatch,
      matchCount: positions.length,
      tightness: tightness,
      firstMatchIndex: firstMatchIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discover'),
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: 'Users'),
              Tab(text: 'Hashtags'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      textInputAction: TextInputAction.search,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) {
                        _searchDebounceTimer?.cancel();
                        _search();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search username / hashtag',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _searchDebounceTimer?.cancel();
                            _search();
                          },
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Search'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _buildUserTab(context),
                  _buildPostTab(context, _hashtagResults),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTab(BuildContext context) {
    final AppSemanticColors semantic = context.semanticColors;
    final bool isSearching = _activeQuery.isNotEmpty;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> list = isSearching
        ? _userResults
        : _suggestedUsers;
    if (list.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    final bool showBottomLoader =
        isSearching && (_loadingUsersMore || _hasMoreUsers);
    return ListView.builder(
      itemCount: list.length + (showBottomLoader ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (showBottomLoader && index == list.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (isSearching && index >= list.length - 3) {
          _loadMoreUsers();
        }
        final Map<String, dynamic> data = list[index].data();
        final String uid = data['uid']?.toString() ?? list[index].id;
        final String username = data['username']?.toString() ?? 'user';
        final String displayName = data['displayName']?.toString() ?? username;
        return Column(
          children: <Widget>[
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(displayName),
              subtitle: Text('@$username'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UserProfilePreviewScreen(
                      userId: uid,
                      initialUsername: username,
                    ),
                  ),
                );
              },
            ),
            Divider(height: 1, color: semantic.divider),
          ],
        );
      },
    );
  }

  Widget _buildPostTab(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
  ) {
    final AppSemanticColors semantic = context.semanticColors;
    final bool loadingMore = _loadingHashtagsMore;
    final bool hasMore = _hasMoreHashtags;

    if (posts.isEmpty) {
      return const Center(child: Text('No posts found.'));
    }

    final bool showBottomLoader =
        _activeQuery.isNotEmpty && (loadingMore || hasMore);
    return ListView.builder(
      itemCount: posts.length + (showBottomLoader ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (showBottomLoader && index == posts.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (_activeQuery.isNotEmpty && index >= posts.length - 3) {
          _loadMoreHashtags();
        }
        final Map<String, dynamic> data = posts[index].data();
        final String caption = data['content']?.toString() ?? '';
        final String username = data['username']?.toString() ?? 'Anonymous';
        return Column(
          children: <Widget>[
            ListTile(
              title: Text(
                caption.isEmpty ? '(No caption)' : caption,
                maxLines: 2,
              ),
              subtitle: Text('@$username'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SharedPostDetailScreen(postId: posts[index].id),
                  ),
                );
              },
            ),
            Divider(height: 1, color: semantic.divider),
          ],
        );
      },
    );
  }
}

class _RelevanceScore {
  const _RelevanceScore({
    required this.fullMatch,
    required this.matchCount,
    required this.tightness,
    required this.firstMatchIndex,
  });

  final bool fullMatch;
  final int matchCount;
  final int tightness;
  final int firstMatchIndex;
}
