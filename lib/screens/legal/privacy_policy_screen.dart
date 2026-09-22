import 'package:flutter/material.dart';
import 'package:sincerelysea/config/legal_content.dart';

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
            'Version ${LegalContent.privacyVersion} - Last updated: ${LegalContent.lastUpdated}',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 14),
          _PolicySection(
            title: '1. Account Information',
            body:
                'We process information used to create and secure your account, such as username, display name, email, profile details, and authentication information. Private account data is not presented as a public customer profile.',
          ),
          _PolicySection(
            title: '2. Public and Community Information',
            body:
                'Information you intentionally publish through profile and community features may be visible to other signed-in customers. This can include username, display name, profile image, bio, posts, comments, replies, and social interactions, subject to available privacy and visibility controls.',
          ),
          _PolicySection(
            title: '3. Commerce and Support Information',
            body:
                'Cart, checkout, and order features process product selections, quantities, order history, and the contact or delivery information required for fulfilment. Support tickets may include contact details, descriptions, attachments, and application or device diagnostics you submit.',
          ),
          _PolicySection(
            title: '4. Device, Notification, and Location Data',
            body:
                'The application may process notification and device or application information needed for notifications, security, and support. Location is processed when you choose to attach it to community content; this policy does not describe background precise-location collection.',
          ),
          _PolicySection(
            title: '5. How Information Is Used',
            body:
                'Information is used for authentication, profiles and community features, shopping and orders, notifications, support, abuse prevention, security, and operation of the application.',
          ),
          _PolicySection(
            title: '6. Sharing and Service Providers',
            body:
                'SincerelySea does not sell personal data. Firebase and Google services are used for authentication, database, storage, notifications, security, and related application operation. Information may also be disclosed when required by law or to protect users and the service.',
          ),
          _PolicySection(
            title: '7. Security',
            body:
                'We use access controls and trusted backend operations to reduce unauthorized access and modification. No internet or storage system can be guaranteed absolutely secure.',
          ),
          _PolicySection(
            title: '8. Customer Controls',
            body:
                'You can update public profile details, manage available privacy controls, export account data, block users, hide content, and manage notification or device permissions.',
          ),
          _PolicySection(
            title: '9. Account Deletion',
            body:
                'The account settings provide a deletion flow that requires recent authentication and asks the trusted backend to remove the account and associated application data. Some information may remain where technically or legally required.',
          ),
          _PolicySection(
            title: '10. Privacy and Data Requests',
            body:
                'Use ${LegalContent.supportReference} for privacy questions, data requests, account deletion help, or concerns about community and commerce information.',
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
