import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GeminiService {
  static const String _apiKeyKey = 'gemini_api_key';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    wOptions: WindowsOptions(
      useBackwardCompatibility: false,
    ),
  );
  
  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
  }

  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  Future<String> getDailyInsight(
    Map<String, dynamic> habitData,
    int currentStreak,
    double completionRate,
  ) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final prompt = '''
Based on the user's habit tracking data:
- Current streak: $currentStreak days
- Completion rate: ${(completionRate * 100).toStringAsFixed(1)}%
- Total habits being tracked: ${habitData['habits']?.length ?? 0}

Provide a personalized, encouraging 2-3 sentence motivational message to help them stay on track.
''';

    return await _callGeminiApi(apiKey, prompt);
  }

  Future<String> analyzePatterns(
    Map<String, dynamic> habitData,
    Map<String, int> completionCounts,
  ) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final prompt = '''
Analyze the user's 30-day habit tracking patterns:

Habits: ${habitData['habits']}
Completion counts per habit: $completionCounts

Provide:
1. 📊 Key patterns identified
2. 💪 Strengths and what they're doing well
3. 🎯 Areas needing attention
4. ✨ Specific recommendations

Format with emojis and bullet points for readability.
''';

    return await _callGeminiApi(apiKey, prompt);
  }

  Future<String> suggestHabits(
    List<String> currentHabits,
    String userGoal,
  ) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final prompt = '''
Current habits: ${currentHabits.join(', ')}
User's goal: $userGoal

Suggest 3-5 new complementary habits that would help achieve this goal. 
For each habit, provide:
- Habit name
- Brief explanation of how it helps

Format as a numbered list.
''';

    return await _callGeminiApi(apiKey, prompt);
  }

  Future<String> analyzeWorkLifeBalance(
    int totalWorkTimeSeconds,
    int workDaysCount,
    double habitCompletionRate,
    int completedTasks,
    int totalTasks,
  ) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final workHours = (totalWorkTimeSeconds / 3600).toStringAsFixed(1);
    final avgHoursPerDay = workDaysCount > 0 ? (totalWorkTimeSeconds / workDaysCount / 3600).toStringAsFixed(1) : '0';

    final prompt = '''
Analyze the user's work-life balance based on their recent tracking data:

📊 Work Metrics:
- Total work time: $workHours hours over $workDaysCount days
- Average daily work time: $avgHoursPerDay hours

📝 Personal Development:
- Habit completion rate: ${(habitCompletionRate * 100).toStringAsFixed(1)}%
- Tasks completed: $completedTasks out of $totalTasks

Provide:
1. 🎯 Overall work-life balance assessment
2. ⚠️ Any concerns or red flags
3. ✅ Positive observations
4. 💡 3 specific recommendations for improvement

Keep it motivating and actionable. Use emojis and bullet points.
''';

    return await _callGeminiApi(apiKey, prompt);
  }

  Future<String> getWeeklyRecap(
    Map<String, dynamic> fullData,
    Map<String, int> habitCompletionCounts,
    int totalWorkTimeSeconds,
    int completedTasks,
    int totalTasks,
  ) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final workHours = (totalWorkTimeSeconds / 3600).toStringAsFixed(1);

    final prompt = '''
Generate a comprehensive weekly recap based on the user's data:

🔄 Habits:
${habitCompletionCounts.entries.map((e) => '- ${e.key}: ${e.value} completions').join('\n')}

✅ Tasks: $completedTasks/$totalTasks completed
⏰ Work Time: $workHours hours tracked

Provide:
1. 🎉 Top achievements this week
2. 📊 Key statistics summary
3. 💪 Areas of improvement
4. 🚀 Goals for next week
5. ⭐ Motivational message

Make it encouraging, specific, and actionable. Use emojis liberally.
''';

    return await _callGeminiApi(apiKey, prompt);
  }

  Future<String> analyzeProductivityPatterns(
    Map<String, dynamic> fullData,
    Map<String, int> workTimeByDate,
    Map<String, int> weeklyBreakdown,
  ) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final prompt = '''
Analyze productivity patterns across different dimensions:

⏰ Work Time Distribution:
${workTimeByDate.entries.take(10).map((e) => '- ${e.key}: ${(e.value / 3600).toStringAsFixed(1)}h').join('\n')}

📅 Weekly Activity Breakdown:
${weeklyBreakdown.entries.map((e) => '- ${e.key}: ${e.value} completions').join('\n')}

Provide insights on:
1. 📈 Most productive days/times
2. 📉 Low productivity periods
3. 🔄 Consistency patterns
4. 💡 Optimization suggestions
5. ⚡ Energy management tips

Be specific with days and times. Include actionable recommendations.
''';

    return await _callGeminiApi(apiKey, prompt);
  }

  Future<String> getSmartRecommendations(
    Map<String, dynamic> fullData,
    Map<String, dynamic> statistics,
    List<String> recentReflections,
  ) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured');
    }

    final reflectionsSummary = recentReflections.isEmpty 
        ? 'No recent reflections'
        : recentReflections.take(3).join('\n- ');

    final prompt = '''
Based on holistic analysis of the user's data:

📊 Statistics: $statistics

📝 Recent Reflections:
- $reflectionsSummary

Provide personalized, actionable recommendations:

1. 🎯 Priority Focus Areas (top 3)
2. 🔧 Quick Wins (easy improvements)
3. 🚀 Stretch Goals (challenging but achievable)
4. ⚖️ Balance Adjustments (if needed)
5. 🎨 Lifestyle Enhancements

Make recommendations specific, measurable, and tied to their actual data. Use emojis.
''';

    return await _callGeminiApi(apiKey, prompt);
  }

  Future<String> _callGeminiApi(String apiKey, String prompt) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        return text ?? 'No response from AI';
      } else {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }
}
