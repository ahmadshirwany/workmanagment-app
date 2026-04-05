import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/ai_chat_message.dart';
import '../providers/ai_coach_provider.dart';
import 'ai_history_screen.dart';

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _speechReady = false;
  bool _isListening = false;
  int _lastMessageCount = 0;
  bool _lastLoadingState = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeSpeech();
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _speechReady = available;
    });
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

  Future<void> _sendMessage(AICoachProvider coach) async {
    final text = _inputController.text.trim();
    if (text.isEmpty || coach.isLoading) return;

    _inputController.clear();
    await coach.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _sendQuickAction(AICoachProvider coach, String actionType) async {
    if (coach.isLoading) return;
    await coach.sendQuickAction(actionType);
    _scrollToBottom();
  }

  Future<void> _toggleVoiceInput() async {
    if (!_speechReady) {
      await _initializeSpeech();
      if (!_speechReady && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice input is unavailable on this device right now.'),
          ),
        );
      }
      return;
    }

    if (_isListening) {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speechToText.listen(
      listenFor: const Duration(seconds: 35),
      pauseFor: const Duration(seconds: 4),
      listenOptions: stt.SpeechListenOptions(partialResults: true),
      onResult: (result) {
        if (!mounted) return;
        final transcript = result.recognizedWords.trim();
        if (transcript.isEmpty) return;
        _inputController.text = transcript;
        _inputController.selection = TextSelection.collapsed(
          offset: transcript.length,
        );
        setState(() {});
      },
    );
  }

  Future<void> _openHistoryScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AIHistoryScreen()),
    );
    if (!mounted) return;
    _scrollToBottom();
  }

  void _syncPendingContext(AICoachProvider coach) {
    final pendingContext = coach.consumePendingCoachContext();
    if (pendingContext == null || pendingContext.trim().isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inputController.text = pendingContext.trim();
      _inputController.selection = TextSelection.collapsed(
        offset: _inputController.text.length,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily motivation moved into your coach draft.'),
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void _syncAutoScroll(AICoachProvider coach) {
    final currentCount = coach.activeMessages.length;
    final currentLoading = coach.isLoading;

    if (currentCount != _lastMessageCount || currentLoading != _lastLoadingState) {
      _lastMessageCount = currentCount;
      _lastLoadingState = currentLoading;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<bool> _saveApiKey(AICoachProvider coach) async {
    final raw = _apiKeyController.text.trim();
    if (raw.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Gemini API key first.'),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return false;
    }

    try {
      await coach.saveApiKey(raw);
      _apiKeyController.clear();

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save API key: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
      return false;
    }
  }

  Future<void> _confirmClearHistory(AICoachProvider coach) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear AI History?'),
          content: const Text(
            'This removes all saved conversations from local storage. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;
    await coach.clearHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI history cleared.')),
    );
  }

  void _showApiKeyDialog(AICoachProvider coach) {
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
              onPressed: () async {
                final saved = await _saveApiKey(coach);
                if (!context.mounted || !saved) return;
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
    return Consumer<AICoachProvider>(
      builder: (context, coach, child) {
        _syncPendingContext(coach);
        _syncAutoScroll(coach);

        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Coach'),
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: _openHistoryScreen,
                tooltip: 'History',
              ),
              IconButton(
                icon: const Icon(Icons.key),
                onPressed: () => _showApiKeyDialog(coach),
                tooltip: 'API Key',
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'new') {
                    await coach.startNewConversation();
                  }
                  if (value == 'clear') {
                    await _confirmClearHistory(coach);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'new',
                    child: Text('New conversation'),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('Clear all history'),
                  ),
                ],
              ),
            ],
          ),
          body: coach.isInitialized
              ? _buildChatInterface(coach)
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildChatInterface(AICoachProvider coach) {
    final messages = coach.activeMessages;

    return Column(
      children: [
        if (!coach.hasApiKey)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFF57F17)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Add a Gemini API key for personalized responses.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => _showApiKeyDialog(coach),
                  child: const Text('Add key'),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF9C27B0).withValues(alpha: 0.05),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionChip(
                  label: 'Give me a pep talk',
                  onTap: () => _sendQuickAction(coach, 'pep_talk'),
                  isEnabled: !coach.isLoading,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: 'What should I focus on today?',
                  onTap: () => _sendQuickAction(coach, 'focus_today'),
                  isEnabled: !coach.isLoading,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: coach.dynamicQuickActionLabel,
                  onTap: () => _sendQuickAction(coach, 'dynamic'),
                  isEnabled: !coach.isLoading,
                ),
                const SizedBox(width: 8),
                _buildQuickActionChip(
                  label: 'Roast my lazy day',
                  onTap: () => _sendQuickAction(coach, 'roast_lazy_day'),
                  isEnabled: !coach.isLoading,
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length + (coach.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length && coach.isLoading) {
                return _buildTypingIndicator();
              }
              return _buildMessageBubble(messages[index]);
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.15),
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
                    onSubmitted: (_) => _sendMessage(coach),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _isListening
                        ? const Color(0xFFD32F2F)
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                    onPressed: coach.isLoading ? null : _toggleVoiceInput,
                    tooltip: _isListening
                        ? 'Stop voice input'
                        : 'Start voice input',
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
                    onPressed: coach.isLoading ? null : () => _sendMessage(coach),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip({
    required String label,
    required VoidCallback onTap,
    required bool isEnabled,
  }) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: isEnabled ? onTap : null,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF9C27B0), width: 1),
      labelStyle: const TextStyle(color: Color(0xFF9C27B0)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildMessageBubble(AIChatMessage message) {
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
