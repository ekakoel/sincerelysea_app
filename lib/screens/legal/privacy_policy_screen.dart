import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const <Widget>[
          Text(
            'Last updated: February 16, 2026',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 14),
          _PolicySection(
            title: '1. Information We Collect',
            body:
                'We collect account data (email, username, profile details), content you upload (posts, images, comments), and basic usage metadata to provide and improve the app.',
          ),
          _PolicySection(
            title: '2. How We Use Your Data',
            body:
                'We use your data to authenticate your account, show your profile and posts, enable social features (follow, comments, notifications), and protect platform security.',
          ),
          _PolicySection(
            title: '3. Storage and Security',
            body:
                'Your data is stored in Firebase services with access controls enforced by security rules. We apply reasonable safeguards, but no internet service is 100% risk-free.',
          ),
          _PolicySection(
            title: '4. Sharing and Visibility',
            body:
                'Content visibility depends on your privacy settings. Public posts may be visible to other users. We do not sell your personal data.',
          ),
          _PolicySection(
            title: '5. Your Rights',
            body:
                'You can update profile details, manage privacy settings, and request account deletion through available account controls.',
          ),
          _PolicySection(
            title: '6. Contact',
            body:
                'If you have privacy questions, contact the app support channel listed in your project documentation.',
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
