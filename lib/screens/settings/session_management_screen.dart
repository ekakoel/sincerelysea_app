import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sincerelysea/services/auth_service.dart';

class SessionManagementScreen extends StatelessWidget {
  const SessionManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = context.watch<User?>();

    return Scaffold(
      appBar: AppBar(title: const Text('Session Management')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_iphone_outlined),
              title: const Text('Current device'),
              subtitle: Text(
                user?.email?.isNotEmpty == true
                    ? 'Signed in as ${user!.email}'
                    : 'Signed in session',
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('About sessions'),
              subtitle: Text(
                'Current release keeps one active session per device. '
                'Global multi-device revoke can be added using backend token registry.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () async {
              await context.read<AuthService>().signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out from this device'),
          ),
        ],
      ),
    );
  }
}
