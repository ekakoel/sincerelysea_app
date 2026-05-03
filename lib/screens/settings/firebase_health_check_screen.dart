import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class FirebaseHealthCheckScreen extends StatefulWidget {
  const FirebaseHealthCheckScreen({super.key});

  @override
  State<FirebaseHealthCheckScreen> createState() =>
      _FirebaseHealthCheckScreenState();
}

class _FirebaseHealthCheckScreenState extends State<FirebaseHealthCheckScreen> {
  bool _loading = true;
  String _projectId = '-';
  String _appId = '-';
  String _authState = 'Unknown';
  String _usersRead = 'Not checked';
  String _productsRead = 'Not checked';
  String _shopConfigRead = 'Not checked';
  String _lastError = '';

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() {
      _loading = true;
      _lastError = '';
      _usersRead = 'Checking...';
      _productsRead = 'Checking...';
      _shopConfigRead = 'Checking...';
    });

    try {
      final FirebaseApp app = Firebase.app();
      final User? user = FirebaseAuth.instance.currentUser;
      _projectId = app.options.projectId;
      _appId = app.options.appId;
      _authState = user == null ? 'Signed out' : 'Signed in (${user.uid})';

      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          _usersRead = 'OK';
        } on FirebaseException catch (e) {
          _usersRead = 'Failed (${e.code})';
        }
      } else {
        _usersRead = 'Skipped (needs sign in)';
      }

      try {
        await FirebaseFirestore.instance.collection('products').limit(1).get();
        _productsRead = 'OK';
      } on FirebaseException catch (e) {
        _productsRead = 'Failed (${e.code})';
      }

      try {
        await FirebaseFirestore.instance
            .collection('app_config')
            .doc('shop')
            .get();
        _shopConfigRead = 'OK';
      } on FirebaseException catch (e) {
        _shopConfigRead = 'Failed (${e.code})';
      }
    } catch (e) {
      _lastError = '$e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Health Check')),
      body: RefreshIndicator(
        onRefresh: _runChecks,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'App Firebase Binding',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    _line('Project ID', _projectId),
                    _line('App ID', _appId),
                    _line('Auth State', _authState),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Firestore Read Checks',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    _line('users/{uid}', _usersRead),
                    _line('products (limit 1)', _productsRead),
                    _line('app_config/shop', _shopConfigRead),
                  ],
                ),
              ),
            ),
            if (_lastError.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Last error: $_lastError',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _runChecks,
              icon: const Icon(Icons.refresh),
              label: const Text('Run Check Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
