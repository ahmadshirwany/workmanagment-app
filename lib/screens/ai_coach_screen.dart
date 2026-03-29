import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/app_data_provider.dart';
import '../services/gemini_service.dart';

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? type;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.type,
  });
}

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> with AutomaticKeepAliveClientMixin {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasApiKey = false;
  int _messageLifetimeMinutes = 30;
  Timer? _cleanupTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
    _startCleanupTimer();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupOldMessages();
    });
  }

  void _cleanupOldMessages() {
    final cutoff = DateTime.now().subtract(Duration(minutes: _messageLifetimeMinutes));
    final welcomeMsg = _messages.isNotEmpty ? _messages.first : null;
    setState(() {
      _messages = _messages.where((msg) => 
        msg.id == 'welcome' || msg.timestamp.isAfter(cutoff)
      ).toList();
      // Re-add welcome if it was removed
      if (_messages.isEmpty && welcomeMsg != null) {
        _messages.add(welcomeMsg);
      }
    });
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      id: 'welcome',
      content: '👋 Hi! I\'m your AI Coach.\n\nAsk me anything about your goals, habits, or productivity. Use the quick actions above or type your question below!',
      isUser: false,
      timestamp: DateTime.now(),
      type: 'system',
    ));
  }

  Future<void> _checkApiKey() async {
    final apiKey = await _geminiService.getApiKey();
    setState(() {
      _hasApiKey = apiKey != null && apiKey.isNotEmpty;
    });
  }

  Future<void> _saveApiKey() async {
    await _geminiService.saveApiKey(_apiKeyController.text);
    _apiKeyController.clear();
    await _checkApiKey();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  void _addMessage(String content, {bool isUser = false, String? type}) {
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        isUser: isUser,
        timestamp: DateTime.now(),
        type: type,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    _addMessage(text, isUser: true, type: 'goal');

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<AppDataProvider>(context, listen: false);
      final habitNames = provider.getAllHabitNames();
      
      final response = await _geminiService.suggestHabits(habitNames, text);
      _addMessage(response, type: 'suggestion');
    } catch (e) {
      _addMessage('Sorry, I encountered an error. Please try again.', type: 'error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getQuickInsight(String type) async {
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<AppDataProvider>(context, listen: false);
      final stats = provider.getStatistics();
      String response;

      switch (type) {
        case 'motivation':
          _addMessage('💪 Give me motivation!', isUser: true);
          response = await _geminiService.getDailyInsight(
            provider.data.toJson(),
            stats.currentStreak,
            stats.overallCompletionRate,
          );
          break;
        case 'weekly':
          _addMessage('📊 Weekly recap please', isUser: true);
          response = await _geminiService.getWeeklyRecap(
            provider.data.toJson(),
            stats.habitCompletionCounts,
            stats.totalWorkTimeSeconds,
            stats.completedDailyTasks,
            stats.totalDailyTasks,
          );
          break;
        case 'tips':
          _addMessage('💡 Quick tips', isUser: true);
          final recentReflections = provider.data.reflections.entries
              .toList()
              ..sort((a, b) => b.key.compareTo(a.key));
          final reflectionTexts = recentReflections
              .take(3)
              .map((e) => e.value)
              .where((text) => text.isNotEmpty)
              .toList();
          response = await _geminiService.getSmartRecommendations(
            provider.data.toJson(),
            {
              'completionRate': stats.overallCompletionRate,
              'currentStreak': stats.currentStreak,
              'workHours': stats.totalWorkTimeSeconds / 3600,
              'taskCompletion': stats.dailyTaskCompletionRate,
            },
            reflectionTexts,
          );
          break;
        default:
          response = 'Unknown action';
      }

      _addMessage(response, type: type);
    } catch (e) {
      _addMessage('Sorry, something went wrong. Please try again.', type: 'error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.key, color: Color(0xFF9C27B0)),
              SizedBox(width: 8),
              Text('API Key'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your Google Gemini API key:'),
              const SizedBox(height: 8),
              const Text(
                'Get it free at: makersuite.google.com',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  hintText: 'Paste API Key here',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _apiKeyController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveApiKey();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int tempLifetime = _messageLifetimeMinutes;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.timer, color: Color(0xFF9C27B0)),
              SizedBox(width: 8),
              Text('Chat Settings'),
            ],
          ),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Messages auto-delete after:'),
                  const SizedBox(height: 16),
                  DropdownButton<int>(
                    value: tempLifetime,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 minutes')),
                      DropdownMenuItem(value: 15, child: Text('15 minutes')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes')),
                      DropdownMenuItem(value: 60, child: Text('1 hour')),
                      DropdownMenuItem(value: 1440, child: Text('24 hours')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => tempLifetime = value!);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _addWelcomeMessage();
                        });
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      label: const Text('Clear Chat'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _messageLifetimeMinutes = tempLifetime);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Coach'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.key),
            onPressed: _showApiKeyDialog,
            tooltip: 'API Key',
          ),
        ],
      ),
      body: !_hasApiKey ? _buildApiKeySetup() : _buildChatInterface(),
    );
  }

  Widget _buildApiKeySetup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                size: 64,
                color: Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Setup AI Coach',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add your free Google Gemini API key to get personalized coaching',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showApiKeyDialog,
              icon: const Icon(Icons.key),
              label: const Text('Add API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        // Quick Action Chips
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF9C27B0).withOpacity(0.05),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionChip('💪 Motivation', 'motivation'),
                const SizedBox(width: 8),
                _buildQuickActionChip('📊 Weekly', 'weekly'),
                const SizedBox(width: 8),
                _buildQuickActionChip('💡 Tips', 'tips'),
              ],
            ),
          ),
        ),
        
        // Chat Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isLoading) {
                return _buildTypingIndicator();
              }
              return _buildMessageBubble(_messages[index]);
            },
          ),
        ),
        
        // Input Area
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Ask about goals or habits...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF9C27B0),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip(String label, String type) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: _isLoading ? null : () => _getQuickInsight(type),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF9C27B0), width: 1),
      labelStyle: const TextStyle(color: Color(0xFF9C27B0)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final timeAgo = _getTimeAgo(message.timestamp);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.psychology, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF9C27B0) : Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isUser ? 0 : 40,
              right: isUser ? 0 : 0,
            ),
            child: Text(
              timeAgo,
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: const SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _TypingDot(delay: 0),
                  _TypingDot(delay: 150),
                  _TypingDot(delay: 300),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color.lerp(Colors.grey[300], const Color(0xFF9C27B0), _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
