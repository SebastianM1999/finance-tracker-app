import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy Policy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Last updated: May 2026', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 32),
              _Section(
                title: '1. Overview',
                body:
                    'FinTrack ("the app") is a personal finance tracker for private use. '
                    'This privacy policy explains what data is collected, how it is used, and your rights regarding your data.',
              ),
              _Section(
                title: '2. Data We Collect',
                body:
                    'When you sign in with Google, we receive your name, email address, and profile picture '
                    'provided by your Google account. Financial data you enter (transactions, accounts, investments) '
                    'is stored in your personal Firebase account linked to your Google identity.',
              ),
              _Section(
                title: '3. How We Use Your Data',
                body:
                    'Your data is used solely to provide the app\'s functionality. '
                    'We do not sell, share, or transfer your data to third parties. '
                    'No advertising or tracking is performed.',
              ),
              _Section(
                title: '4. Data Storage',
                body:
                    'All data is stored securely using Google Firebase (Firestore and Firebase Authentication), '
                    'operated by Google LLC. Data is stored on Google\'s servers in accordance with '
                    'Google\'s privacy practices (https://policies.google.com/privacy).',
              ),
              _Section(
                title: '5. Your Rights',
                body:
                    'You may request deletion of your data at any time by contacting us or by deleting '
                    'your account within the app. You can also revoke Google Sign-In access at any time '
                    'via your Google account settings.',
              ),
              _Section(
                title: '6. Contact',
                body: 'For any privacy-related questions, contact: sebastianmissler@web.de',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.6)),
        ],
      ),
    );
  }
}
