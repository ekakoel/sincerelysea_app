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
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _locationResults =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _suggestedUsers =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastUserDoc;
  DocumentSnapshot<Map<String, dynamic>>? _lastHashtagDoc;
  DocumentSnapshot<Map<String, dynamic>>? _lastLocationDoc;
  bool _hasMoreUsers = true;
  bool _hasMoreHashtags = true;
  bool _hasMoreLocations = true;
  bool _loadingUsersMore = false;
  bool _loadingHashtagsMore = false;
  bool _loadingLocationsMore = false;
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
        _locationResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        _lastUserDoc = null;
        _lastHashtagDoc = null;
        _lastLocationDoc = null;
        _hasMoreUsers = true;
        _hasMoreHashtags = true;
        _hasMoreLocations = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _activeQuery = query;
      _userResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      _hashtagResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      _locationResults = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      _lastUserDoc = null;
      _lastHashtagDoc = null;
      _lastLocationDoc = null;
      _hasMoreUsers = true;
      _hasMoreHashtags = true;
      _hasMoreLocations = true;
    });
    final DiscoveryService service = context.read<DiscoveryService>();
    try {
      final List<QuerySnapshot<Map<String, dynamic>>> pages =
          await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
            service.searchUsersPage(query, limit: _pageSize),
            service.searchByHashtagPage(query, limit: _pageSize),
            service.searchByLocationPage(query, limit: _pageSize),
          ]);
      if (!mounted ||
          requestId != _searchRequestId ||
          _queryController.text.trim() != query) {
        return;
      }
      setState(() {
        _userResults = pages[0].docs;
        _hashtagResults = pages[1].docs;
        _locationResults = pages[2].docs;
        _lastUserDoc = _userResults.isNotEmpty ? _userResults.last : null;
        _lastHashtagDoc = _hashtagResults.isNotEmpty
            ? _hashtagResults.last
            : null;
        _lastLocationDoc = _locationResults.isNotEmpty
            ? _locationResults.last
            : null;
        _hasMoreUsers = _userResults.length >= _pageSize;
        _hasMoreHashtags = _hashtagResults.length >= _pageSize;
        _hasMoreLocations = _locationResults.length >= _pageSize;
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
      final QuerySnapshot<Map<String, dynamic>> page = await context
          .read<DiscoveryService>()
          .searchUsersPage(
            _activeQuery,
            startAfter: _lastUserDoc,
            limit: _pageSize,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _userResults.addAll(page.docs);
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
      final QuerySnapshot<Map<String, dynamic>> page = await context
          .read<DiscoveryService>()
          .searchByHashtagPage(
            _activeQuery,
            startAfter: _lastHashtagDoc,
            limit: _pageSize,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _hashtagResults.addAll(page.docs);
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

  Future<void> _loadMoreLocations() async {
    if (_isLoading ||
        _loadingLocationsMore ||
        !_hasMoreLocations ||
        _activeQuery.isEmpty) {
      return;
    }
    setState(() => _loadingLocationsMore = true);
    try {
      final QuerySnapshot<Map<String, dynamic>> page = await context
          .read<DiscoveryService>()
          .searchByLocationPage(
            _activeQuery,
            startAfter: _lastLocationDoc,
            limit: _pageSize,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _locationResults.addAll(page.docs);
        _lastLocationDoc = page.docs.isNotEmpty
            ? page.docs.last
            : _lastLocationDoc;
        _hasMoreLocations = page.docs.length >= _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingLocationsMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discover'),
          bottom: const TabBar(
            tabs: <Tab>[
              Tab(text: 'Users'),
              Tab(text: 'Hashtags'),
              Tab(text: 'Location'),
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
                      onSubmitted: (_) {
                        _searchDebounceTimer?.cancel();
                        _search();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search username / hashtag / location',
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
                  _buildPostTab(context, _hashtagResults, isHashtagTab: true),
                  _buildPostTab(context, _locationResults, isHashtagTab: false),
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
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts, {
    required bool isHashtagTab,
  }) {
    final AppSemanticColors semantic = context.semanticColors;
    final bool loadingMore = isHashtagTab
        ? _loadingHashtagsMore
        : _loadingLocationsMore;
    final bool hasMore = isHashtagTab ? _hasMoreHashtags : _hasMoreLocations;

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
          if (isHashtagTab) {
            _loadMoreHashtags();
          } else {
            _loadMoreLocations();
          }
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
