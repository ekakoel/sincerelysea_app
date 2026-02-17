import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/user_profile_service.dart';

class PrivacyControlsScreen extends StatefulWidget {
  const PrivacyControlsScreen({super.key});

  @override
  State<PrivacyControlsScreen> createState() => _PrivacyControlsScreenState();
}

class _PrivacyControlsScreenState extends State<PrivacyControlsScreen> {
  bool _initialized = false;
  bool _saving = false;
  bool _isPrivate = false;
  String _allowComments = 'everyone';

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<User?>();
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first.')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: context.read<UserProfileService>().profileStream(user.uid),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};
            if (!_initialized &&
                snapshot.connectionState != ConnectionState.waiting) {
              _isPrivate = data['isPrivate'] == true;
              _allowComments = data['allowComments']?.toString() ?? 'everyone';
              _initialized = true;
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('Privacy Controls'),
                actions: <Widget>[
                  TextButton(
                    onPressed: _saving ? null : _savePrivacy,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  SwitchListTile(
                    value: _isPrivate,
                    title: const Text('Private account'),
                    subtitle: const Text(
                      'Only approved followers can follow private accounts.',
                    ),
                    onChanged: (bool value) =>
                        setState(() => _isPrivate = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _allowComments,
                    decoration: const InputDecoration(
                      labelText: 'Who can comment on your posts',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'everyone',
                        child: Text('Everyone'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'followers',
                        child: Text('Followers only'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'none',
                        child: Text('No one'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _allowComments = value);
                    },
                  ),
                ],
              ),
            );
          },
    );
  }

  Future<void> _savePrivacy() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<UserProfileService>().updatePrivacySettings(
        isPrivate: _isPrivate,
        allowComments: _allowComments,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Privacy updated')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update privacy: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
