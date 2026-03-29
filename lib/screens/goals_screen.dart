import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data_provider.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late TextEditingController _goalsController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _goalsController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _goalsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals & Notes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, provider, child) {
          if (_goalsController.text != provider.data.goals) {
            _goalsController.text = provider.data.goals;
          }
          if (_notesController.text != provider.data.dailyNotes) {
            _notesController.text = provider.data.dailyNotes;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.flag,
                  size: 60,
                  color: Color(0xFF2196F3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Long-Term Goals',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'What do you want to achieve?',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _goalsController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Example: Improve my health, learn a new skill, etc.',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      provider.updateGoals(_goalsController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Goals saved!'),
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Goals'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Daily Notes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quick reminders and thoughts',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Things to remember...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      provider.updateDailyNotes(_notesController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notes saved!'),
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Notes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
