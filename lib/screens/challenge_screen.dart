import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late TextEditingController _challengeController;

  @override
  void initState() {
    super.initState();
    _challengeController = TextEditingController();
  }

  @override
  void dispose() {
    _challengeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('30-Day Challenge'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, provider, child) {
          if (_challengeController.text != provider.data.challenge) {
            _challengeController.text = provider.data.challenge;
            _challengeController.selection = TextSelection.fromPosition(
              TextPosition(offset: _challengeController.text.length),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 60,
                  color: Color(0xFFFF9800),
                ),
                const SizedBox(height: 16),
                const Text(
                  'My 30-Day Challenge',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Define your challenge and commit to it for 30 days!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _challengeController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Example: Complete all my habits every day for 30 days',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                  ),
                  onChanged: (value) {
                    // Debounced save happens automatically via provider
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      provider.updateChallenge(_challengeController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Challenge saved!'),
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Challenge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
