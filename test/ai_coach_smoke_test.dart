import 'package:discipline_tracker/providers/ai_coach_provider.dart';
import 'package:discipline_tracker/providers/app_data_provider.dart';
import 'package:discipline_tracker/providers/gamification_provider.dart';
import 'package:discipline_tracker/providers/home_navigation_provider.dart';
import 'package:discipline_tracker/screens/ai_coach_screen.dart';
import 'package:discipline_tracker/models/app_data.dart';
import 'package:discipline_tracker/models/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const MethodChannel _speechToTextChannel =
    MethodChannel('plugin.csdcorp.com/speech_to_text');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureStore;

  setUp(() async {
    secureStore = <String, String>{};
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
      switch (call.method) {
        case 'read':
          final key = (call.arguments as Map?)?['key'] as String?;
          return key == null ? null : secureStore[key];
        case 'write':
          final args = (call.arguments as Map?) ?? const {};
          final key = args['key'] as String?;
          final value = args['value'] as String?;
          if (key != null && value != null) {
            secureStore[key] = value;
          }
          return null;
        case 'readAll':
          return Map<String, String>.from(secureStore);
        case 'delete':
          final key = (call.arguments as Map?)?['key'] as String?;
          if (key != null) {
            secureStore.remove(key);
          }
          return null;
        case 'deleteAll':
          secureStore.clear();
          return null;
        case 'containsKey':
          final key = (call.arguments as Map?)?['key'] as String?;
          return key != null && secureStore.containsKey(key);
        case 'isProtectedDataAvailable':
          return true;
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_speechToTextChannel, (call) async {
      switch (call.method) {
        case 'initialize':
          return false;
        case 'has_permission':
          return false;
        case 'listen':
          return true;
        case 'stop':
        case 'cancel':
          return null;
        case 'locales':
          return <dynamic>[];
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_speechToTextChannel, null);
  });

  testWidgets('AI history keeps only latest 10 conversations', (tester) async {
    final appDataProvider = FakeAppDataProvider();
    final gamificationProvider = GamificationProvider()..bind(appDataProvider);
    final coachProvider = AICoachProvider()
      ..bind(appDataProvider, gamificationProvider);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    await _pumpUntil(tester, () => coachProvider.isInitialized);

    String? oldestConversationId;

    for (var i = 0; i < 11; i++) {
      await coachProvider.startNewConversation();
      if (i == 0) {
        oldestConversationId = coachProvider.activeConversation?.id;
      }
      await coachProvider.saveConversation();
    }

    expect(coachProvider.conversationHistory.length, 10);
    expect(
      coachProvider.conversationHistory
          .any((item) => item.id == oldestConversationId),
      isFalse,
    );
    expect(appDataProvider.data.aiHistory.length, 10);
  });

  testWidgets('Daily motivation card is shown once per day', (tester) async {
    final appDataProvider = FakeAppDataProvider();
    final gamificationProvider = GamificationProvider()..bind(appDataProvider);
    final coachProvider = AICoachProvider()
      ..bind(appDataProvider, gamificationProvider);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    await _pumpUntil(tester, () => coachProvider.isInitialized);

    final generated = await coachProvider.generateDailyMotivation(force: true);
    final firstGeneratedAt = generated['generatedAt'] as String?;

    expect((generated['message'] as String?)?.isNotEmpty, isTrue);
    expect(coachProvider.shouldShowDailyMotivationCard, isTrue);

    await coachProvider.markDailyMotivationSeen();
    expect(coachProvider.shouldShowDailyMotivationCard, isFalse);

    final second = await coachProvider.generateDailyMotivation();
    expect(second['generatedAt'], firstGeneratedAt);
  });

  testWidgets('Ask-coach context handoff is single-consume', (tester) async {
    final appDataProvider = FakeAppDataProvider();
    final gamificationProvider = GamificationProvider()..bind(appDataProvider);
    final coachProvider = AICoachProvider()
      ..bind(appDataProvider, gamificationProvider);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    await _pumpUntil(tester, () => coachProvider.isInitialized);

    coachProvider.setPendingCoachContext('Help me plan today.');

    expect(coachProvider.consumePendingCoachContext(), 'Help me plan today.');
    expect(coachProvider.consumePendingCoachContext(), isNull);
  });

  testWidgets('Voice button shows unavailable snackbar when speech init fails',
      (tester) async {
    final appDataProvider = FakeAppDataProvider();
    final gamificationProvider = GamificationProvider()..bind(appDataProvider);
    final coachProvider = AICoachProvider()
      ..bind(appDataProvider, gamificationProvider);

    await tester.pumpWidget(
      ChangeNotifierProvider<AICoachProvider>.value(
        value: coachProvider,
        child: const MaterialApp(home: AICoachScreen()),
      ),
    );

    await tester.pump();
    await _pumpUntil(tester, () => coachProvider.isInitialized);

    final micButton = find.byTooltip('Start voice input');
    expect(micButton, findsOneWidget);

    await tester.tap(micButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('Voice input is unavailable on this device right now.'),
      findsOneWidget,
    );
  });

  test('Home navigation request is one-shot', () {
    final navigationProvider = HomeNavigationProvider();

    navigationProvider.requestTab(2);
    expect(navigationProvider.requestedTab, 2);

    navigationProvider.clearRequest();
    expect(navigationProvider.requestedTab, isNull);
  });
}

class FakeAppDataProvider extends AppDataProvider {
  FakeAppDataProvider({AppData? seed})
      : _fakeData = seed ?? AppData.empty();

  AppData _fakeData;

  @override
  bool get isLoading => false;

  @override
  AppData get data => _fakeData;

  @override
  String getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> updateAiCoachData({
    List<Map<String, dynamic>>? aiHistory,
    Map<String, dynamic>? aiCoachMeta,
    Map<String, dynamic>? dailyMotivation,
  }) async {
    _fakeData = _fakeData.copyWith(
      aiHistory: aiHistory,
      aiCoachMeta: aiCoachMeta,
      dailyMotivation: dailyMotivation,
    );
    notifyListeners();
  }

  @override
  List<String> getRecentReflectionEntries({int limit = 5}) {
    final sorted = _fakeData.reflections.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return sorted
        .map((entry) => entry.value.trim())
        .where((text) => text.isNotEmpty)
        .take(limit)
        .toList();
  }

  @override
  String? getWeakestHabitName({String timePeriod = '30d'}) {
    if (_fakeData.habits.isEmpty) return null;
    final first = _fakeData.habits.first['name'] as String?;
    return first?.trim().isEmpty == true ? null : first;
  }

  @override
  bool isHoliday(String date) => _fakeData.holidayDates.contains(date);

  @override
  void recordAiCoachConversation() {
    // No-op in smoke tests.
  }

  @override
  Statistics getStatistics({String timePeriod = '30d'}) {
    return Statistics(
      daysTracked: 14,
      overallCompletionRate: 0.62,
      currentStreak: 3,
      longestStreak: 7,
      habitCompletionCounts: const {'Focus': 8},
      totalDailyTasks: 20,
      completedDailyTasks: 12,
      dailyTaskCompletionRate: 0.6,
      avgTasksPerDay: 2.0,
      totalWorkTimeSeconds: 5 * 3600,
      avgWorkTimePerDay: 50 * 60,
      maxWorkTimeSeconds: 90 * 60,
      mostProductiveWorkDay: null,
      workDaysCount: 6,
      bestPerformingHabit: null,
      mostProductiveDay: null,
      consistencyScore: 0.58,
      weeklyBreakdown: const {},
    );
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxPumps = 60,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  expect(condition(), isTrue, reason: 'Condition not met within pump limit.');
}
