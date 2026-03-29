import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/app_data_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  Color _getDayColor(DateTime day, AppDataProvider provider) {
    final dateString = _formatDate(day);
    final completionRate = provider.getDayCompletionRate(dateString);

    if (completionRate == 0) {
      return Colors.grey[300]!;
    } else if (completionRate > 0.66) {
      return const Color(0xFF4CAF50); // Green
    } else if (completionRate >= 0.33) {
      return const Color(0xFFFF9800); // Orange
    } else {
      return const Color(0xFFF44336); // Red
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AppDataProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Container(
                color: Colors.white,
                child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime.now(),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.yellow.shade700, width: 2),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: Colors.yellow.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getDayColor(day, provider),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: _isToday(day) ? Colors.yellow.shade700 : Colors.white,
                              fontWeight: _isToday(day) ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getDayColor(day, provider),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.yellow.shade700, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: Colors.yellow.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left),
                    rightChevronIcon: Icon(Icons.chevron_right),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Legend',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLegendItem('High completion (>66%)', const Color(0xFF4CAF50)),
                    _buildLegendItem('Medium completion (33-66%)', const Color(0xFFFF9800)),
                    _buildLegendItem('Low completion (<33%)', const Color(0xFFF44336)),
                    _buildLegendItem('No data', Colors.grey[300]!),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.yellow.shade700, width: 2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("Today's date"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Selected day info
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selected: ${_formatDate(_selectedDay)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Completion Rate: ${(provider.getDayCompletionRate(_formatDate(_selectedDay)) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          if (provider.data.habitData[_formatDate(_selectedDay)] != null) ...[
                            const Text(
                              'Habits:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...provider.getActiveHabitsForDate(_formatDate(_selectedDay)).map((habit) {
                              final completed = provider.isHabitCompleted(
                                habit,
                                _formatDate(_selectedDay),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      completed ? Icons.check_circle : Icons.cancel,
                                      color: completed ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(habit),
                                  ],
                                ),
                              );
                            }),
                          ] else
                            const Text(
                              'No data for this day',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
