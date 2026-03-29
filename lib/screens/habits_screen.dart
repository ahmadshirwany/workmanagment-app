import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_data_provider.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final TextEditingController _habitController = TextEditingController();
  final TextEditingController _taskController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _habitController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  void _showAddHabitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Habit'),
          content: TextField(
            controller: _habitController,
            decoration: const InputDecoration(
              hintText: 'Enter habit name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _addHabit(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _habitController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addHabit,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addHabit() {
    if (_habitController.text.trim().isNotEmpty) {
      Provider.of<AppDataProvider>(context, listen: false)
          .addHabit(_habitController.text.trim());
      _habitController.clear();
      Navigator.pop(context);
    }
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Daily Task'),
          content: TextField(
            controller: _taskController,
            decoration: const InputDecoration(
              hintText: 'Enter task name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _addTask(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _taskController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addTask,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addTask() {
    if (_taskController.text.trim().isNotEmpty) {
      final dateString = _formatDate(_selectedDate);
      Provider.of<AppDataProvider>(context, listen: false)
          .addDailyTask(dateString, _taskController.text.trim());
      _taskController.clear();
      Navigator.pop(context);
    }
  }

  void _showEditHabitDialog(String oldHabitName) {
    _habitController.text = oldHabitName;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Habit'),
          content: TextField(
            controller: _habitController,
            decoration: const InputDecoration(
              hintText: 'Enter new habit name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _updateHabit(oldHabitName),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _habitController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _updateHabit(oldHabitName),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _updateHabit(String oldHabitName) {
    if (_habitController.text.trim().isNotEmpty) {
      Provider.of<AppDataProvider>(context, listen: false)
          .updateHabit(oldHabitName, _habitController.text.trim());
      _habitController.clear();
      Navigator.pop(context);
    }
  }

  void _showEditTaskDialog(String date, String taskId, String oldTaskName) {
    _taskController.text = oldTaskName;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Task'),
          content: TextField(
            controller: _taskController,
            decoration: const InputDecoration(
              hintText: 'Enter new task name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) => _updateTask(date, taskId),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _taskController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _updateTask(date, taskId),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _updateTask(String date, String taskId) {
    if (_taskController.text.trim().isNotEmpty) {
      Provider.of<AppDataProvider>(context, listen: false)
          .updateDailyTask(date, taskId, _taskController.text.trim());
      _taskController.clear();
      Navigator.pop(context);
    }
  }

  void _confirmDeleteHabit(String habit) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Habit'),
          content: Text('Are you sure you want to delete "$habit"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<AppDataProvider>(context, listen: false)
                    .removeHabit(habit);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Tasks'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final selectedDateString = _formatDate(_selectedDate);
          final activeHabitNames = provider.getActiveHabitsForDate(selectedDateString);
          final dailyTasks = provider.getDailyTasks(selectedDateString);

          return Column(
            children: [
              // Date Selector
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2196F3)),
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
                                  const Icon(Icons.calendar_today, color: Color(0xFF2196F3), size: 20),
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
                        icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFF2196F3)),
                        onPressed: _nextDay,
                        tooltip: 'Next Day',
                      ),
                    ],
                  ),
                ),
              ),
              
              // Holiday Toggle
              Consumer<AppDataProvider>(
                builder: (context, provider, child) {
                  final isHoliday = provider.isHoliday(selectedDateString);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: isHoliday ? Colors.orange[50] : null,
                    child: InkWell(
                      onTap: () {
                        provider.toggleHoliday(selectedDateString);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isHoliday ? Icons.beach_access : Icons.work_outline,
                                  color: isHoliday ? Colors.orange : Colors.grey[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isHoliday ? 'Holiday/Vacation Day' : 'Mark as Holiday/Vacation',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isHoliday ? FontWeight.w600 : FontWeight.normal,
                                      color: isHoliday ? Colors.orange[800] : Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: isHoliday,
                                  onChanged: (_) {
                                    provider.toggleHoliday(selectedDateString);
                                  },
                                  activeColor: Colors.orange,
                                ),
                              ],
                            ),
                            if (isHoliday)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 36),
                                child: Text(
                                  'This day will not be included in statistics',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 8),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // HABITS Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🔄 Recurring Habits',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF2196F3)),
                          onPressed: _showAddHabitDialog,
                          tooltip: 'Add Habit',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (activeHabitNames.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No recurring habits yet. Tap + to add one!',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...activeHabitNames.map((habit) {
                        final isCompleted = provider.isHabitCompleted(habit, selectedDateString);
                        final streak = provider.getHabitStreak(habit);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Checkbox(
                              value: isCompleted,
                              onChanged: (_) {
                                provider.toggleHabit(habit, selectedDateString);
                              },
                              activeColor: const Color(0xFF4CAF50),
                            ),
                            title: Text(
                              habit,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            subtitle: streak > 0
                                ? Row(
                                    children: [
                                      const Text('🔥'),
                                      const SizedBox(width: 4),
                                      Text('$streak day${streak > 1 ? 's' : ''} streak'),
                                    ],
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                                  onPressed: () => _showEditHabitDialog(habit),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDeleteHabit(habit),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    
                    const SizedBox(height: 24),
                    
                    // DAILY TASKS Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📝 Daily Tasks',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF9C27B0)),
                          onPressed: _showAddTaskDialog,
                          tooltip: 'Add Task',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    if (dailyTasks.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No tasks for this day. Tap + to add one!',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...dailyTasks.map((task) {
                        final taskId = task['id'] as String;
                        final taskName = task['name'] as String;
                        final isCompleted = task['completed'] as bool;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.purple[50],
                          child: ListTile(
                            leading: Checkbox(
                              value: isCompleted,
                              onChanged: (_) {
                                provider.toggleDailyTask(selectedDateString, taskId);
                              },
                              activeColor: const Color(0xFF9C27B0),
                            ),
                            title: Text(
                              taskName,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFF9C27B0)),
                                  onPressed: () => _showEditTaskDialog(selectedDateString, taskId, taskName),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    provider.removeDailyTask(selectedDateString, taskId);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
