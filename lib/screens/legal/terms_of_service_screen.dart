import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const <Widget>[
          Text(
            'Last updated: February 16, 2026',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 14),
          _TermsSection(
            title: '1. Acceptance of Terms',
            body:
                'By creating an account or using SincerelySea, you agree to these Terms of Service and all applicable policies.',
          ),
          _TermsSection(
            title: '2. Account Responsibilities',
            body:
                'You are responsible for maintaining account security, keeping credentials confidential, and ensuring information you provide is accurate.',
          ),
          _TermsSection(
            title: '3. User Content',
            body:
                'You retain ownership of content you upload. You grant the app a limited license to host, process, and display that content to operate social features.',
          ),
          _TermsSection(
            title: '4. Prohibited Conduct',
            body:
                'Do not post unlawful, abusive, infringing, or harmful content. Do not attempt to abuse platform services, scrape data, or bypass security controls.',
          ),
          _TermsSection(
            title: '5. Enforcement and Termination',
            body:
                'We may remove content or restrict accounts that violate policies. You can request account deletion using available account lifecycle controls.',
          ),
          _TermsSection(
            title: '6. Service Availability',
            body:
                'We aim to keep services stable but do not guarantee uninterrupted availability. Features may change, be improved, or retired over time.',
          ),
          _TermsSection(
            title: '7. Liability',
            body:
                'The service is provided as-is to the extent permitted by law. We are not liable for indirect damages resulting from service usage.',
          ),
          _TermsSection(
            title: '8. Contact',
            body:
                'For legal or support questions, use the support channel documented in your project settings.',
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
