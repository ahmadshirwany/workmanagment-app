import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_data_provider.dart';
import 'providers/ai_coach_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/home_navigation_provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppDataProvider()),
        ChangeNotifierProvider(create: (_) => HomeNavigationProvider()),
        ChangeNotifierProxyProvider<AppDataProvider, GamificationProvider>(
          create: (_) => GamificationProvider(),
          update: (_, appDataProvider, gamificationProvider) {
            final provider = gamificationProvider ?? GamificationProvider();
            provider.bind(appDataProvider);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<AppDataProvider, GamificationProvider,
            AICoachProvider>(
          create: (_) => AICoachProvider(),
          update: (_, appDataProvider, gamificationProvider, aiCoachProvider) {
            final provider = aiCoachProvider ?? AICoachProvider();
            provider.bind(appDataProvider, gamificationProvider);
            return provider;
          },
        ),
      ],
      child: const DisciplineApp(),
    );
  }
}

class DisciplineApp extends StatefulWidget {
  const DisciplineApp({super.key});

  @override
  State<DisciplineApp> createState() => _DisciplineAppState();
}

class _DisciplineAppState extends State<DisciplineApp>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  Timer? _dailyMaintenanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runMaintenanceCheck('app_launch');
    });

    _scheduleMidnightMaintenance();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _dailyMaintenanceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runMaintenanceCheck('app_resume');
    }
  }

  void _runMaintenanceCheck(String trigger) {
    if (!mounted) return;

    final gamificationProvider = context.read<GamificationProvider>();
    unawaited(gamificationProvider.runMaintenanceCheck(trigger: trigger));
  }

  void _scheduleMidnightMaintenance() {
    _midnightTimer?.cancel();
    _dailyMaintenanceTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = nextMidnight.difference(now);

    _midnightTimer = Timer(durationUntilMidnight, () {
      _runMaintenanceCheck('midnight');
      _dailyMaintenanceTimer = Timer.periodic(
        const Duration(days: 1),
        (_) => _runMaintenanceCheck('midnight'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Discipline Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2196F3),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF9C27B0),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
