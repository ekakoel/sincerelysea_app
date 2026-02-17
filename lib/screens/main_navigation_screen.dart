import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/screens/discovery/discovery_screen.dart';
import 'package:sincerelysea/screens/home/home_screen.dart';
import 'package:sincerelysea/screens/map/map_posts_screen.dart';
import 'package:sincerelysea/screens/post/shared_post_detail_screen.dart';
import 'package:sincerelysea/screens/profile/profile_screen.dart';
import 'package:sincerelysea/services/deep_link_service.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  DeepLinkService? _deepLinkService;
  bool _isOpeningDeepLink = false;
  static const double _bottomNavIconTopPadding = 4;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DeepLinkService service = context.read<DeepLinkService>();
    if (_deepLinkService == service) {
      return;
    }
    _deepLinkService?.removeListener(_onDeepLinkChanged);
    _deepLinkService = service;
    _deepLinkService!.addListener(_onDeepLinkChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPendingSharedPostIfAny();
    });
  }

  @override
  void dispose() {
    _deepLinkService?.removeListener(_onDeepLinkChanged);
    super.dispose();
  }

  void _onDeepLinkChanged() {
    _openPendingSharedPostIfAny();
  }

  Future<void> _openPendingSharedPostIfAny() async {
    if (!mounted || _isOpeningDeepLink || _deepLinkService == null) {
      return;
    }
    final User? user = context.read<User?>();
    if (user == null) {
      return;
    }
    final String? postId = _deepLinkService!.consumePendingPostId();
    if (postId == null || postId.isEmpty) {
      return;
    }
    _isOpeningDeepLink = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedPostDetailScreen(postId: postId),
      ),
    );
    _isOpeningDeepLink = false;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final List<Widget> pages = <Widget>[
      const HomeScreen(),
      const DiscoveryScreen(),
      _currentIndex == 2 ? const MapPostsScreen() : const SizedBox.shrink(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.65),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        currentIndex: _currentIndex,
        onTap: (int value) => setState(() => _currentIndex = value),
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(top: _bottomNavIconTopPadding),
              child: const Icon(Icons.home),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(top: _bottomNavIconTopPadding),
              child: const Icon(Icons.search),
            ),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(top: _bottomNavIconTopPadding),
              child: const Icon(Icons.explore),
            ),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(top: _bottomNavIconTopPadding),
              child: const Icon(Icons.person),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
