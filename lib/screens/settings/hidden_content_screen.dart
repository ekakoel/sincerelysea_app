import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/hidden_content_preferences_service.dart';
import 'package:sincerelysea/services/moderation_service.dart';

class HiddenContentScreen extends StatefulWidget {
  const HiddenContentScreen({super.key});

  @override
  State<HiddenContentScreen> createState() => _HiddenContentScreenState();
}

class _HiddenContentScreenState extends State<HiddenContentScreen> {
  final HiddenContentPreferencesService _preferencesService =
      HiddenContentPreferencesService();
  bool _loadingPreferences = true;
  bool _hideTextOnlyPosts = false;
  bool _hidePostsWithMutedKeywords = true;
  final TextEditingController _mutedKeywordsController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _mutedKeywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hidden Content')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Content Preferences',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingPreferences)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...<Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hide text-only posts'),
                      subtitle: const Text(
                        'Posts without image will be hidden from Home feed.',
                      ),
                      value: _hideTextOnlyPosts,
                      onChanged: (bool value) async {
                        await _preferencesService.setHideTextOnlyPosts(value);
                        if (!mounted) {
                          return;
                        }
                        setState(() => _hideTextOnlyPosts = value);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hide muted keywords'),
                      subtitle: const Text(
                        'Hide posts containing muted words in caption/hashtags.',
                      ),
                      value: _hidePostsWithMutedKeywords,
                      onChanged: (bool value) async {
                        await _preferencesService.setHidePostsWithMutedKeywords(
                          value,
                        );
                        if (!mounted) {
                          return;
                        }
                        setState(() => _hidePostsWithMutedKeywords = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mutedKeywordsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Muted keywords',
                        hintText: 'example: spam, gambling, nsfw',
                      ),
                      onChanged: (String value) async {
                        await _preferencesService.setMutedKeywords(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Separate keywords with comma. Changes apply on next feed refresh.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hidden Posts',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: context.read<ModerationService>().hiddenPostsStream(),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
              snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> hiddenDocs =
                  snapshot.data ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              if (hiddenDocs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hidden posts.'),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: hiddenDocs
                      .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                        final Map<String, dynamic> data = doc.data();
                        final String postId =
                            data['postId']?.toString() ?? doc.id;
                        return Column(
                          children: <Widget>[
                            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              future: FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(postId)
                                  .get(),
                              builder: (
                                BuildContext context,
                                AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                                postSnapshot,
                              ) {
                                final Map<String, dynamic>? postData =
                                    postSnapshot.data?.data();
                                final String username = (postData?['username']
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ==
                                            true
                                        ? postData!['username'].toString().trim()
                                        : data['postOwnerUsername']
                                              ?.toString()
                                              .trim()) ??
                                    '';
                                final String caption = (postData?['content']
                                                ?.toString()
                                                .trim()
                                                .isNotEmpty ==
                                            true
                                        ? postData!['content'].toString().trim()
                                        : data['postCaption']
                                              ?.toString()
                                              .trim()) ??
                                    '';
                                return ListTile(
                                  title: Text(
                                    username.isNotEmpty
                                        ? '@$username'
                                        : 'Unknown user',
                                  ),
                                  subtitle: Text(
                                    caption.isNotEmpty ? caption : 'No caption',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: TextButton(
                                    onPressed: () async {
                                      await context
                                          .read<ModerationService>()
                                          .unhidePost(postId);
                                    },
                                    child: const Text('Unhide'),
                                  ),
                                );
                              },
                            ),
                            if (hiddenDocs.last.id != doc.id)
                              const Divider(height: 1),
                          ],
                        );
                      })
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadPreferences() async {
    final HiddenContentPreferences preferences = await _preferencesService.load();
    if (!mounted) {
      return;
    }
    _mutedKeywordsController.text = preferences.mutedKeywords.join(', ');
    setState(() {
      _hideTextOnlyPosts = preferences.hideTextOnlyPosts;
      _hidePostsWithMutedKeywords = preferences.hidePostsWithMutedKeywords;
      _loadingPreferences = false;
    });
  }
}
