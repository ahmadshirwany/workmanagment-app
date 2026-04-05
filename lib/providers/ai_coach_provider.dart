import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_chat_message.dart';
import '../models/ai_conversation.dart';
import '../services/gemini_service.dart';
import 'app_data_provider.dart';
import 'gamification_provider.dart';

class AICoachProvider extends ChangeNotifier {
  static const int _maxConversations = 10;
  static const Uuid _uuid = Uuid();

  final GeminiService _geminiService = GeminiService();

  AppDataProvider? _appDataProvider;
  GamificationProvider? _gamificationProvider;

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _bindInitializationScheduled = false;
  bool _hasApiKey = false;

  List<AIConversation> _conversationHistory = [];
  AIConversation? _activeConversation;

  Map<String, dynamic> _dailyMotivation = {};

  String _dynamicQuickActionLabel = 'Help me fix my weakest habit';
  String _dynamicQuickActionPrompt =
      'Give me a focused plan to improve my weakest habit this week.';

  String? _pendingCoachContext;

  bool get isLoading => _isLoading;
  bool get hasApiKey => _hasApiKey;
  bool get isInitialized => _isInitialized;
  List<AIConversation> get conversationHistory => _conversationHistory;
  AIConversation? get activeConversation => _activeConversation;
  List<AIChatMessage> get activeMessages =>
      _activeConversation?.messages ?? const [];
  Map<String, dynamic> get dailyMotivation => _dailyMotivation;
  String get dynamicQuickActionLabel => _dynamicQuickActionLabel;

  void bind(AppDataProvider appDataProvider, GamificationProvider gamificationProvider) {
    final providerChanged = !identical(_appDataProvider, appDataProvider);
    _appDataProvider = appDataProvider;
    _gamificationProvider = gamificationProvider;

    if (providerChanged) {
      _bindInitializationScheduled = false;
    }

    if (_bindInitializationScheduled || appDataProvider.isLoading) return;

    _bindInitializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = _appDataProvider;
      if (provider == null || provider.isLoading) {
        _bindInitializationScheduled = false;
        return;
      }
      unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return;

    await refreshApiKeyStatus();
    loadHistory();
    _dailyMotivation = Map<String, dynamic>.from(provider.data.dailyMotivation);
    _refreshDynamicQuickAction();

    _activeConversation ??= _buildFreshConversation();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> refreshApiKeyStatus() async {
    final key = await _geminiService.getApiKey();
    _hasApiKey = key != null && key.trim().isNotEmpty;
  }

  Future<void> saveApiKey(String apiKey) async {
    await _geminiService.saveApiKey(apiKey.trim());
    await refreshApiKeyStatus();
    notifyListeners();
  }

  void loadHistory() {
    final provider = _appDataProvider;
    if (provider == null) return;

    final raw = provider.data.aiHistory;
    final parsed = raw
        .map((item) => AIConversation.fromJson(item))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _conversationHistory = parsed.take(_maxConversations).toList();

    final activeId = provider.data.aiCoachMeta['activeConversationId'] as String?;
    if (activeId != null && activeId.isNotEmpty) {
      final found = _conversationHistory.where((item) => item.id == activeId);
      if (found.isNotEmpty) {
        _activeConversation = found.first;
      }
    }

    _activeConversation ??=
        _conversationHistory.isNotEmpty ? _conversationHistory.first : null;
  }

  Future<void> saveConversation([AIConversation? conversation]) async {
    final provider = _appDataProvider;
    final target = conversation ?? _activeConversation;
    if (provider == null || target == null) return;

    final updated = List<AIConversation>.from(_conversationHistory)
      ..removeWhere((item) => item.id == target.id)
      ..insert(0, target);

    _conversationHistory = updated.take(_maxConversations).toList();

    final updatedMeta = Map<String, dynamic>.from(provider.data.aiCoachMeta);
    updatedMeta['activeConversationId'] = target.id;
    updatedMeta['lastUpdatedAt'] = DateTime.now().toIso8601String();

    await provider.updateAiCoachData(
      aiHistory: _conversationHistory.map((item) => item.toJson()).toList(),
      aiCoachMeta: updatedMeta,
      dailyMotivation: _dailyMotivation,
    );

    notifyListeners();
  }

  Future<void> startNewConversation() async {
    _activeConversation = _buildFreshConversation();
    notifyListeners();
  }

  Future<void> restoreConversation(String conversationId) async {
    final found = _conversationHistory.where((item) => item.id == conversationId);
    if (found.isEmpty) return;

    _activeConversation = found.first;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    final provider = _appDataProvider;
    if (provider == null) return;

    _conversationHistory = [];
    _activeConversation = _buildFreshConversation();

    final updatedMeta = Map<String, dynamic>.from(provider.data.aiCoachMeta);
    updatedMeta['activeConversationId'] = _activeConversation!.id;

    await provider.updateAiCoachData(
      aiHistory: const [],
      aiCoachMeta: updatedMeta,
      dailyMotivation: _dailyMotivation,
    );

    notifyListeners();
  }

  Future<void> sendMessage(String input) async {
    final messageText = input.trim();
    if (messageText.isEmpty || _isLoading) return;

    _ensureActiveConversation();
    _appendMessage(
      AIChatMessage(
        id: _uuid.v4(),
        role: 'user',
        content: messageText,
        timestamp: DateTime.now(),
        type: 'chat',
      ),
    );
    await saveConversation();

    _isLoading = true;
    notifyListeners();

    try {
      _appDataProvider?.recordAiCoachConversation();
      final context = buildDailyContext(lastUserInput: messageText);
      final response = await _geminiService.generateContextualChatReply(
        userMessage: messageText,
        context: context,
      );

      _appendMessage(
        AIChatMessage(
          id: _uuid.v4(),
          role: 'assistant',
          content: response.trim(),
          timestamp: DateTime.now(),
          type: 'chat_reply',
        ),
      );
      await saveConversation();
    } catch (e) {
      final errorMessage = _buildAiErrorMessage(
        e,
        fallback:
            'I could not reach the AI service right now. Your chat is saved locally, and we can continue offline.',
      );
      _appendMessage(
        AIChatMessage(
          id: _uuid.v4(),
          role: 'assistant',
          content: errorMessage,
          timestamp: DateTime.now(),
          type: 'error',
        ),
      );
      await saveConversation();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendQuickAction(String actionType) async {
    if (_isLoading) return;

    final context = buildDailyContext();
    final action = _resolveQuickAction(actionType, context);

    _ensureActiveConversation();
    _appendMessage(
      AIChatMessage(
        id: _uuid.v4(),
        role: 'user',
        content: action['userLabel'] as String,
        timestamp: DateTime.now(),
        type: action['type'] as String,
      ),
    );
    await saveConversation();

    _isLoading = true;
    notifyListeners();

    try {
      _appDataProvider?.recordAiCoachConversation();
      final response = await _geminiService.generateQuickActionResponse(
        actionType: action['type'] as String,
        actionPrompt: action['prompt'] as String,
        context: context,
      );

      _appendMessage(
        AIChatMessage(
          id: _uuid.v4(),
          role: 'assistant',
          content: response.trim(),
          timestamp: DateTime.now(),
          type: action['type'] as String,
        ),
      );
      await saveConversation();
    } catch (e) {
      final errorMessage = _buildAiErrorMessage(
        e,
        fallback:
            'Could not fetch a quick action response right now. Try again in a moment.',
      );
      _appendMessage(
        AIChatMessage(
          id: _uuid.v4(),
          role: 'assistant',
          content: errorMessage,
          timestamp: DateTime.now(),
          type: 'error',
        ),
      );
      await saveConversation();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> buildDailyContext({String? lastUserInput}) {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) {
      return {
        'streak': 0,
        'disciplineScore': 0.0,
        'todayXp': 0,
        'maintenanceDays': 0,
        'recentReflections': const <String>[],
        'lastChatMessages': const <String>[],
      };
    }

    final stats30 = provider.getStatistics(timePeriod: '30d');
    final stats7 = provider.getStatistics(timePeriod: '7d');
    final today = provider.getTodayDateString();
    final todayXp = provider.data.dailyXp[today] ?? 0;

    final disciplineScore =
        (provider.data.disciplineScore['value'] as num?)?.toDouble() ?? 0.0;
    final weakHabit = provider.getWeakestHabitName(timePeriod: '30d');
    final challenge = provider.data.challenge.trim();

    final maintenanceDays = _gamificationProvider?.getMaintenanceActiveDays(days: 7) ??
        _fallbackMaintenanceDays(provider);

    final recentReflections = provider.getRecentReflectionEntries(limit: 3);
    final lastChatMessages = _lastThreeChatMessages();

    _refreshDynamicQuickAction(
      weakHabit: weakHabit,
      streak: stats30.currentStreak,
      maintenanceDays: maintenanceDays,
      completionRate: stats30.overallCompletionRate,
    );

    return {
      'date': today,
      'streak': stats30.currentStreak,
      'longestStreak': stats30.longestStreak,
      'disciplineScore': disciplineScore,
      'todayXp': todayXp,
      'maintenanceDays': maintenanceDays,
      'weeklyTaskCompletionRate': stats7.dailyTaskCompletionRate,
      'weeklyWorkHours': stats7.totalWorkTimeSeconds / 3600.0,
      'recentReflections': recentReflections,
      'lastChatMessages': lastChatMessages,
      'activeChallenge': challenge,
      'weakHabit': weakHabit ?? 'Not enough habit data yet',
      'lastUserInput': lastUserInput,
    };
  }

  Future<Map<String, dynamic>> generateDailyMotivation({bool force = false}) async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return _dailyMotivation;

    final today = provider.getTodayDateString();
    final lastDate = provider.data.aiCoachMeta['lastDailyMotivationDate'] as String?;

    if (!force && lastDate == today && _dailyMotivation['message'] is String) {
      return _dailyMotivation;
    }

    final context = buildDailyContext();
    await refreshApiKeyStatus();

    _isLoading = true;
    notifyListeners();

    try {
      final message = _hasApiKey
          ? await _geminiService.generateDailyMotivation(context)
          : _localFallbackMotivation(context);

      final isPositive = _isVeryPositive(message);
      _dailyMotivation = {
        'date': today,
        'message': message.trim(),
        'isPositive': isPositive,
        'generatedAt': DateTime.now().toIso8601String(),
        'source': _hasApiKey ? 'gemini' : 'local',
      };

      final updatedMeta = Map<String, dynamic>.from(provider.data.aiCoachMeta);
      updatedMeta['lastDailyMotivationDate'] = today;
      if ((updatedMeta['dailyCardSeenDate'] as String?) != today) {
        updatedMeta.remove('dailyCardSeenDate');
      }

      await provider.updateAiCoachData(
        aiHistory: _conversationHistory.map((item) => item.toJson()).toList(),
        aiCoachMeta: updatedMeta,
        dailyMotivation: _dailyMotivation,
      );

      return _dailyMotivation;
    } catch (e) {
      final fallback = _localFallbackMotivation(context);
      _dailyMotivation = {
        'date': today,
        'message': fallback,
        'isPositive': true,
        'generatedAt': DateTime.now().toIso8601String(),
        'source': 'local',
      };
      return _dailyMotivation;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureDailyMotivationForToday() async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return;

    final today = provider.getTodayDateString();
    if (_dailyMotivation['date'] == today &&
        (_dailyMotivation['message'] as String?)?.isNotEmpty == true) {
      return;
    }

    await generateDailyMotivation();
  }

  bool get shouldShowDailyMotivationCard {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return false;

    final today = provider.getTodayDateString();
    final motivationDate = _dailyMotivation['date'] as String?;
    final seenDate = provider.data.aiCoachMeta['dailyCardSeenDate'] as String?;

    return motivationDate == today && seenDate != today;
  }

  Future<void> markDailyMotivationSeen() async {
    final provider = _appDataProvider;
    if (provider == null || provider.isLoading) return;

    final today = provider.getTodayDateString();
    final updatedMeta = Map<String, dynamic>.from(provider.data.aiCoachMeta);
    updatedMeta['dailyCardSeenDate'] = today;

    await provider.updateAiCoachData(
      aiHistory: _conversationHistory.map((item) => item.toJson()).toList(),
      aiCoachMeta: updatedMeta,
      dailyMotivation: _dailyMotivation,
    );

    notifyListeners();
  }

  void setPendingCoachContext(String contextText) {
    _pendingCoachContext = contextText;
  }

  String? consumePendingCoachContext() {
    final value = _pendingCoachContext;
    _pendingCoachContext = null;
    return value;
  }

  void _ensureActiveConversation() {
    _activeConversation ??= _buildFreshConversation();
  }

  AIConversation _buildFreshConversation() {
    return AIConversation(
      id: _uuid.v4(),
      title: 'New conversation',
      messages: [
        AIChatMessage(
          id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          content: _hasApiKey
              ? 'Hey, I am your coach. Tell me what today looks like and I will help you lock in.'
              : 'Hey, I am your coach. Add your Gemini API key to unlock personalized coaching, and your local chat history will still be saved.',
          timestamp: DateTime.now(),
          type: 'welcome',
        )
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void _appendMessage(AIChatMessage message) {
    _ensureActiveConversation();

    final current = _activeConversation!;
    final updatedMessages = [...current.messages, message];

    final nextTitle = current.title == 'New conversation' && message.isUser
        ? _titleFromMessage(message.content)
        : current.title;

    _activeConversation = current.copyWith(
      title: nextTitle,
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    notifyListeners();
  }

  String _titleFromMessage(String input) {
    final compact = input.replaceAll('\n', ' ').trim();
    if (compact.length <= 40) return compact;
    return '${compact.substring(0, 40)}...';
  }

  int _fallbackMaintenanceDays(AppDataProvider provider) {
    final today = DateTime.now();
    int count = 0;

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (!provider.isHoliday(dateKey) && (provider.data.dailyXp[dateKey] ?? 0) >= 20) {
        count++;
      }
    }

    return count;
  }

  List<String> _lastThreeChatMessages() {
    final source = _activeConversation ??
        (_conversationHistory.isNotEmpty ? _conversationHistory.first : null);

    if (source == null || source.messages.isEmpty) return const [];

    final messages = source.messages;
    final start = messages.length > 3 ? messages.length - 3 : 0;
    return messages
        .sublist(start)
        .map((item) => '${item.role}: ${item.content}')
        .toList();
  }

  void _refreshDynamicQuickAction({
    String? weakHabit,
    int? streak,
    int? maintenanceDays,
    double? completionRate,
  }) {
    final resolvedWeakHabit = weakHabit ?? _appDataProvider?.getWeakestHabitName();
    final resolvedStreak = streak ??
        (_appDataProvider?.getStatistics(timePeriod: '30d').currentStreak ?? 0);
    final resolvedMaintenance = maintenanceDays ??
        (_gamificationProvider?.getMaintenanceActiveDays(days: 7) ?? 0);
    final resolvedCompletionRate = completionRate ??
        (_appDataProvider?.getStatistics(timePeriod: '30d').overallCompletionRate ?? 0);

    if (resolvedWeakHabit != null && resolvedWeakHabit.trim().isNotEmpty) {
      _dynamicQuickActionLabel = 'Motivate me for $resolvedWeakHabit';
      _dynamicQuickActionPrompt =
          'Give me a practical and motivating plan to improve "$resolvedWeakHabit" starting today.';
      return;
    }

    if (resolvedStreak == 0) {
      _dynamicQuickActionLabel = 'Help me restart today';
      _dynamicQuickActionPrompt =
          'I lost momentum. Give me a low-friction restart plan for today.';
      return;
    }

    if (resolvedMaintenance < 4) {
      _dynamicQuickActionLabel = 'Fix my morning routine';
      _dynamicQuickActionPrompt =
          'Help me fix my morning routine with a simple and realistic checklist.';
      return;
    }

    if (resolvedCompletionRate < 0.6) {
      _dynamicQuickActionLabel = 'How do I stop procrastinating?';
      _dynamicQuickActionPrompt =
          'I keep procrastinating. Give me a direct anti-procrastination plan for today.';
      return;
    }

    _dynamicQuickActionLabel = 'How can I level up this week?';
    _dynamicQuickActionPrompt =
        'Give me a high-performance plan to level up this week without burnout.';
  }

  Map<String, dynamic> _resolveQuickAction(
    String actionType,
    Map<String, dynamic> context,
  ) {
    switch (actionType) {
      case 'pep_talk':
        return {
          'type': 'pep_talk',
          'userLabel': 'Give me a pep talk',
          'prompt': 'Give me an energetic pep talk based on my actual progress data.',
        };
      case 'focus_today':
        return {
          'type': 'focus_today',
          'userLabel': 'What should I focus on today?',
          'prompt': 'Tell me what I should focus on today using my current streak, XP, and weak spots.',
        };
      case 'roast_lazy_day':
        return {
          'type': 'roast_lazy_day',
          'userLabel': 'Roast my lazy day',
          'prompt':
              'Roast my lazy day in a playful, funny, supportive tone. Keep it light and motivating, never insulting.',
        };
      case 'dynamic':
      default:
        _refreshDynamicQuickAction(
          weakHabit: context['weakHabit'] as String?,
          streak: context['streak'] as int?,
          maintenanceDays: context['maintenanceDays'] as int?,
          completionRate: (context['weeklyTaskCompletionRate'] as num?)?.toDouble(),
        );
        return {
          'type': 'dynamic_action',
          'userLabel': _dynamicQuickActionLabel,
          'prompt': _dynamicQuickActionPrompt,
        };
    }
  }

  bool _isVeryPositive(String message) {
    final text = message.toLowerCase();
    const positiveMarkers = [
      'amazing',
      'great job',
      'fantastic',
      'proud',
      'excellent',
      'unstoppable',
      'elite',
      'incredible',
    ];

    int hits = 0;
    for (final marker in positiveMarkers) {
      if (text.contains(marker)) hits++;
    }

    return hits >= 2;
  }

  String _localFallbackMotivation(Map<String, dynamic> context) {
    final streak = context['streak'] as int? ?? 0;
    final score = (context['disciplineScore'] as num?)?.toDouble() ?? 0;
    final weakHabit = context['weakHabit'] as String? ?? 'your weakest habit';

    if (streak == 0) {
      return 'Fresh start day. Win the first hour, then stack one small action for $weakHabit. Momentum beats perfection.';
    }

    if (score >= 80) {
      return 'You are in strong rhythm right now. Protect that edge today with one focused block and one clean habit streak extension.';
    }

    return 'You are closer than you think. Prioritize $weakHabit early today, finish one meaningful task, and let the streak carry the rest.';
  }

  String _buildAiErrorMessage(
    Object error, {
    required String fallback,
  }) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final normalized = raw.toLowerCase();

    if (normalized.contains('api key not configured')) {
      return 'No API key is currently available on this device. Tap the key icon to save your Gemini API key.';
    }

    if (normalized.contains('api key was rejected') ||
        (normalized.contains('api key') &&
            (normalized.contains('invalid') || normalized.contains('restricted')))) {
      return 'Your API key was rejected on this device. In Google AI Studio, use a valid key with Generative Language API access, then save it again.';
    }

    if (normalized.contains('quota')) {
      return 'Gemini quota is currently exhausted for this key. Please try again later or use another key.';
    }

    if (normalized.contains('internet') ||
        normalized.contains('network') ||
        normalized.contains('timed out')) {
      return 'Network issue while contacting Gemini. Check your internet connection and try again.';
    }

    return '$fallback\n\nDetails: $raw';
  }
}
