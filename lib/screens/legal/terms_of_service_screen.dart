import 'package:flutter/material.dart';
import 'package:sincerelysea/config/legal_content.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const <Widget>[
          Text(
            'Version ${LegalContent.termsVersion} - Last updated: ${LegalContent.lastUpdated}',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 14),
          _TermsSection(
            title: '1. Acceptance of Terms',
            body:
                'By creating an account or using the ${LegalContent.applicationName} mobile application, you agree to these Terms & Conditions and the Privacy Policy.',
          ),
          _TermsSection(
            title: '2. Account and Eligibility',
            body:
                'You must provide accurate registration information and be able to enter into these terms under applicable law. The mobile application is a customer-facing community and official-store service.',
          ),
          _TermsSection(
            title: '3. Customer Account Responsibilities',
            body:
                'Keep your credentials secure, maintain accurate account information, and promptly report suspected unauthorized access through in-app Support.',
          ),
          _TermsSection(
            title: '4. Community Content',
            body:
                'You retain rights in content you submit and permit SincerelySea to host, process, and display it as needed for profiles, posts, comments, replies, and other community features.',
          ),
          _TermsSection(
            title: '5. Prohibited Conduct',
            body:
                'Do not submit unlawful, abusive, deceptive, infringing, or harmful content; impersonate others; manipulate engagement; scrape personal data; or bypass security and access controls.',
          ),
          _TermsSection(
            title: '6. Product Information',
            body:
                'Products are offered by the official ${LegalContent.officialStoreName}. Descriptions, images, preorder information, and other product details may be corrected or updated when necessary.',
          ),
          _TermsSection(
            title: '7. Orders and Checkout',
            body:
                'You submit product selections, quantities, and required contact or delivery information. The trusted service validates products and creates the authoritative order record; customers cannot directly set order or payment status.',
          ),
          _TermsSection(
            title: '8. Pricing and Availability',
            body:
                'Prices, item snapshots, totals, and stock are determined from current official-store records when checkout is processed. Displayed estimates and availability may change before an order is accepted.',
          ),
          _TermsSection(
            title: '9. Order Cancellation',
            body:
                'Customer cancellation is available only while an order is in a system-eligible state, currently pending. Cancellation does not let a customer choose later fulfilment or payment states.',
          ),
          _TermsSection(
            title: '10. Product Reviews',
            body:
                'Where product review or product-experience features are available, submissions must be genuine, relevant, and follow the same community-content rules.',
          ),
          _TermsSection(
            title: '11. Intellectual Property',
            body:
                'SincerelySea branding, application design, and service materials remain protected by applicable intellectual-property rights. Do not reuse them without authorization.',
          ),
          _TermsSection(
            title: '12. Content Reporting and Moderation',
            body:
                'Customers may report content or accounts through available reporting tools. Reports may be reviewed and content or accounts may be restricted when rules are violated.',
          ),
          _TermsSection(
            title: '13. Service Availability',
            body:
                'The service may be interrupted, changed, improved, or retired. Continuous or error-free availability is not guaranteed.',
          ),
          _TermsSection(
            title: '14. Account Suspension or Termination',
            body:
                'Accounts or content may be restricted for misuse, security risks, or policy violations. Customers may use the available account-deletion control after required reauthentication.',
          ),
          _TermsSection(
            title: '15. Privacy',
            body:
                'The Privacy Policy explains the categories of information processed, visibility of community content, and available account controls.',
          ),
          _TermsSection(
            title: '16. Changes to the Service or Terms',
            body:
                'Features and these terms may be updated. The current version and last-updated date are displayed on this page.',
          ),
          _TermsSection(
            title: '17. Support and Contact',
            body:
                'Use ${LegalContent.supportReference} for account, community, shopping, order, privacy, deletion, or technical questions. No separate contact channel is promised here.',
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});

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
