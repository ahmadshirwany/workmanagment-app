import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';

class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({super.key});

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  late DateTime _selectedDate;
  late TextEditingController _reflectionController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _reflectionController = TextEditingController();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _loadReflection(AppDataProvider provider) {
    final dateString = _formatDate(_selectedDate);
    _reflectionController.text = provider.getReflection(dateString);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReflection(Provider.of<AppDataProvider>(context, listen: false));
    }
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    if (tomorrow.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() {
        _selectedDate = tomorrow;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Reflection'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, provider, child) {
          // Load reflection when date changes
          if (_reflectionController.text != provider.getReflection(_formatDate(_selectedDate))) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadReflection(provider);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.edit_note,
                  size: 60,
                  color: Color(0xFF9C27B0),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Daily Journal',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF9C27B0)),
                          onPressed: _previousDay,
                          tooltip: 'Previous Day',
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.calendar_today, color: Color(0xFF9C27B0), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF9C27B0)),
                          onPressed: _nextDay,
                          tooltip: 'Next Day',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _reflectionController,
                  maxLines: 15,
                  decoration: const InputDecoration(
                    hintText: 'How was your day? What did you learn? What are you grateful for?',
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
                      provider.saveReflection(
                        _formatDate(_selectedDate),
                        _reflectionController.text,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reflection saved!'),
                          backgroundColor: Color(0xFF4CAF50),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Reflection'),
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
