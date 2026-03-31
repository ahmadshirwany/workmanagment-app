import 'package:flutter/material.dart';
import 'habits_screen.dart';
import 'challenge_screen.dart';
import 'reflection_screen.dart';
import 'goals_screen.dart';
import 'statistics_screen.dart';
import 'calendar_screen.dart';
import 'data_management_screen.dart';
import 'ai_coach_screen.dart';
import 'settings_screen.dart';
import 'work_time_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Primary screens in new order: Daily Tasks, Stats, AI Coach, and rest
  final List<Widget> _primaryScreens = [
    const HabitsScreen(),           // 0: Daily Tasks
    const StatisticsScreen(),       // 1: Stats
    const AICoachScreen(),          // 2: AI Coach
    const WorkTimeScreen(),         // 3: Work Time
    const CalendarScreen(),         // 4: Calendar
    const ChallengeScreen(),        // 5: Challenge
    const ReflectionScreen(),       // 6: Reflection
    const GoalsScreen(),            // 7: Goals
    const DataManagementScreen(),   // 8: Data
    const SettingsScreen(),         // 9: Settings
  ];

  final List<Tab> _primaryTabs = const [
    Tab(icon: Icon(Icons.check_circle), text: 'Daily Tasks'),
    Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
    Tab(icon: Icon(Icons.psychology), text: 'AI Coach'),
    Tab(icon: Icon(Icons.timer), text: 'Work Time'),
    Tab(icon: Icon(Icons.calendar_today), text: 'Calendar'),
    Tab(icon: Icon(Icons.emoji_events), text: 'Challenge'),
    Tab(icon: Icon(Icons.edit_note), text: 'Reflection'),
    Tab(icon: Icon(Icons.flag), text: 'Goals'),
    Tab(icon: Icon(Icons.save), text: 'Data'),
    Tab(icon: Icon(Icons.settings), text: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _primaryScreens.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: _primaryScreens,
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        elevation: 8,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          tabs: _primaryTabs,
        ),
      ),
    );
  }
}
