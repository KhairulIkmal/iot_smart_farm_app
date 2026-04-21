import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/theme.dart';
import '../../services/claude_service.dart';
import '../../services/rtdb_service.dart';
import '../../services/selected_crop_service.dart';
import '../navigation/main_navigation.dart';

/// ------------------------------------------------------------
/// AI CHATBOT SCREEN (AI ASSIST TAB)
/// Smart Crop Recommendations
/// ------------------------------------------------------------
class AiChatbotScreen extends StatefulWidget {
  const AiChatbotScreen({super.key});

  @override
  State<AiChatbotScreen> createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedCrop = 'Tomato';
  bool _isLoading = false;
  Map<String, dynamic>? _recommendations;
  String? _userCropId;

  // Chat state
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;

  final List<String> _cropTypes = [
    'Tomato',
    'Cabbage',
    'Carrots',
    'Corn',
    'Wheat',
    'Rice',
    'Potato',
    'Lettuce',
    'Cucumber',
    'Pepper',
    'Onion',
    'Spinach',
  ];

  final Map<String, Map<String, dynamic>> _cropDatabase = {
    'Tomato': {
      'moistureMin': 60,
      'moistureMax': 80,
      'phMin': 6.0,
      'phMax': 6.8,
      'bestTime': '06:00 AM',
      'frequency': 'Daily',
      'tip':
          'Tomatoes need consistent moisture. Avoid wetting leaves to prevent disease.',
    },
    'Cabbage': {
      'moistureMin': 60,
      'moistureMax': 75,
      'phMin': 6.0,
      'phMax': 7.5,
      'bestTime': '06:00 AM',
      'frequency': 'Every 2 Days',
      'tip':
          'Cabbage needs consistent moisture for head formation. Mulch to retain soil moisture.',
    },
    'Carrots': {
      'moistureMin': 60,
      'moistureMax': 75,
      'phMin': 6.0,
      'phMax': 6.8,
      'bestTime': '06:00 AM',
      'frequency': 'Every 2 Days',
      'tip':
          'Carrots require consistent moisture during germination. Avoid over-watering to prevent root rot.',
    },
    'Corn': {
      'moistureMin': 50,
      'moistureMax': 70,
      'phMin': 5.8,
      'phMax': 7.0,
      'bestTime': '07:00 AM',
      'frequency': 'Every 2-3 Days',
      'tip':
          'Corn needs deep watering. Critical periods are tasseling and ear development.',
    },
    'Wheat': {
      'moistureMin': 40,
      'moistureMax': 60,
      'phMin': 6.0,
      'phMax': 7.5,
      'bestTime': '06:30 AM',
      'frequency': 'Every 3-4 Days',
      'tip':
          'Wheat is drought-tolerant but needs moisture during flowering and grain filling.',
    },
    'Rice': {
      'moistureMin': 80,
      'moistureMax': 95,
      'phMin': 5.5,
      'phMax': 6.5,
      'bestTime': '05:00 AM',
      'frequency': 'Continuous',
      'tip':
          'Rice requires flooded conditions. Maintain 2-5cm water depth during growing season.',
    },
    'Potato': {
      'moistureMin': 60,
      'moistureMax': 80,
      'phMin': 5.0,
      'phMax': 6.0,
      'bestTime': '06:00 AM',
      'frequency': 'Every 2-3 Days',
      'tip':
          'Potatoes need consistent moisture. Irregular watering causes misshapen tubers.',
    },
    'Lettuce': {
      'moistureMin': 65,
      'moistureMax': 80,
      'phMin': 6.0,
      'phMax': 7.0,
      'bestTime': '05:30 AM',
      'frequency': 'Daily',
      'tip':
          'Lettuce has shallow roots. Keep soil consistently moist but not waterlogged.',
    },
    'Cucumber': {
      'moistureMin': 65,
      'moistureMax': 85,
      'phMin': 6.0,
      'phMax': 7.0,
      'bestTime': '06:00 AM',
      'frequency': 'Daily',
      'tip':
          'Cucumbers need consistent moisture. Mulch helps retain soil moisture.',
    },
    'Pepper': {
      'moistureMin': 55,
      'moistureMax': 70,
      'phMin': 6.0,
      'phMax': 6.8,
      'bestTime': '06:30 AM',
      'frequency': 'Every 2 Days',
      'tip':
          'Peppers prefer deep, infrequent watering. Avoid wet foliage to prevent disease.',
    },
    'Onion': {
      'moistureMin': 50,
      'moistureMax': 70,
      'phMin': 6.0,
      'phMax': 7.0,
      'bestTime': '06:00 AM',
      'frequency': 'Every 3 Days',
      'tip':
          'Onions need consistent moisture early on. Reduce watering as bulbs mature.',
    },
    'Spinach': {
      'moistureMin': 60,
      'moistureMax': 75,
      'phMin': 6.5,
      'phMax': 7.5,
      'bestTime': '05:30 AM',
      'frequency': 'Every 2 Days',
      'tip':
          'Spinach prefers cool, moist conditions. Mulch to keep soil cool and retain moisture.',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadUserCrop();
    _recommendations = _cropDatabase[_selectedCrop];
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<_FarmContext> _fetchFarmContext() async {
    final deviceId = SelectedCropService().selectedCrop?.deviceId;
    if (deviceId == null) return _FarmContext.empty();

    try {
      final rtdb = RtdbService();
      final results = await Future.wait([
        rtdb.getLiveData(deviceId),
        rtdb.getSensorHealth(deviceId),
        rtdb.isDeviceOnline(deviceId),
        rtdb.getPumpStatus(deviceId),
      ]);

      final liveSnapshot = results[0] as DataSnapshot;
      final sensorHealth = results[1] as Map<String, String>;
      final isOnline = results[2] as bool;
      final pumpStatus = results[3] as String?;

      final sensorData = liveSnapshot.exists && liveSnapshot.value != null
          ? Map<String, dynamic>.from(liveSnapshot.value as Map)
          : <String, dynamic>{};

      return _FarmContext(
        sensorData: sensorData,
        sensorHealth: sensorHealth,
        deviceOnline: isOnline,
        pumpStatus: pumpStatus,
      );
    } catch (_) {
      return _FarmContext.empty();
    }
  }

  Future<void> _openChatPanel() async {
    if (_chatMessages.isEmpty) {
      setState(() => _isChatLoading = true);
      final ctx = await _fetchFarmContext();

      final soil = ctx.sensorData['soil']?.toString() ?? 'N/A';
      final ph = ctx.sensorData['ph']?.toString() ?? 'N/A';
      final temp = ctx.sensorData['temp']?.toString() ?? 'N/A';
      final statusLabel = ctx.deviceOnline ? 'ONLINE' : 'OFFLINE';

      _chatMessages.add({
        'role': 'assistant',
        'text':
            'Hello! I\'m your AI farm advisor.\n\nDevice: $statusLabel | Crop: $_selectedCrop\nSoil: $soil% | pH: $ph | Temp: $temp°C\n\nWhat would you like to know?',
      });
      setState(() => _isChatLoading = false);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildChatBottomSheet(),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _chatController.clear();

    setState(() {
      _chatMessages.add({'role': 'user', 'text': text.trim()});
      _isChatLoading = true;
    });
    _scrollToBottom();

    try {
      final ctx = await _fetchFarmContext();
      final reply = await ClaudeService().askCropAdvisor(
        cropType: _selectedCrop,
        sensorData: ctx.sensorData,
        sensorHealth: ctx.sensorHealth,
        deviceOnline: ctx.deviceOnline,
        pumpStatus: ctx.pumpStatus,
        userMessage: text.trim(),
      );
      setState(() {
        _chatMessages.add({'role': 'assistant', 'text': reply});
        _isChatLoading = false;
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'role': 'assistant',
          'text': 'Sorry, I couldn\'t connect right now. Please try again.',
        });
        _isChatLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> get _suggestedQuestions => [
        'Is my soil moisture good for $_selectedCrop?',
        'What pH level does $_selectedCrop need?',
        'When is the best time to water $_selectedCrop?',
        'How often should I irrigate $_selectedCrop?',
      ];

  Widget _buildSuggestedQuestions(StateSetter setSheetState) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.borderDark)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Suggested',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestedQuestions.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      _sendMessage(q);
                      setSheetState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        q,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildChatBottomSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Farm Advisor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Powered by Claude AI • $_selectedCrop',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(color: AppColors.borderDark, height: 1),
                  // Messages
                  Expanded(
                    child: ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _chatMessages.length + (_isChatLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _chatMessages.length) {
                          return _buildTypingIndicator();
                        }
                        final msg = _chatMessages[index];
                        final isUser = msg['role'] == 'user';
                        return _buildMessageBubble(
                          text: msg['text'] ?? '',
                          isUser: isUser,
                        );
                      },
                    ),
                  ),
                  // Suggested questions (hidden once user starts chatting)
                  if (_chatMessages.length <= 1)
                    _buildSuggestedQuestions(setSheetState),
                  // Input
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      border: Border(
                        top: BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Ask about your $_selectedCrop...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                              ),
                              filled: true,
                              fillColor: AppColors.backgroundDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (text) {
                              _sendMessage(text);
                              setSheetState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _sendMessage(_chatController.text);
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: AppColors.backgroundDark,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble({required String text, required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceDark,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.borderDark),
        ),
        child: isUser
            ? Text(
                text,
                style: const TextStyle(
                  color: AppColors.backgroundDark,
                  fontSize: 14,
                  height: 1.4,
                ),
              )
            : _buildRichMessage(text),
      ),
    );
  }

  /// Parses markdown-like AI responses into rich Flutter widgets
  Widget _buildRichMessage(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Bullet point
      final bulletMatch = RegExp(r'^[-*•]\s+(.+)').firstMatch(line);
      if (bulletMatch != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(color: AppColors.primary, fontSize: 14, height: 1.5)),
              Expanded(child: _buildInlineRich(bulletMatch.group(1)!)),
            ],
          ),
        ));
        continue;
      }

      // Numbered list
      final numMatch = RegExp(r'^(\d+)\.\s+(.+)').firstMatch(line);
      if (numMatch != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${numMatch.group(1)}. ',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5)),
              Expanded(child: _buildInlineRich(numMatch.group(2)!)),
            ],
          ),
        ));
        continue;
      }

      // Heading (## or ###)
      final headingMatch = RegExp(r'^#{1,3}\s+(.+)').firstMatch(line);
      if (headingMatch != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            headingMatch.group(1)!,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
        ));
        continue;
      }

      // Normal line
      widgets.add(_buildInlineRich(line));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parses inline **bold** and *italic* within a line
  Widget _buildInlineRich(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)');
    int last = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ));
      }
      final raw = match.group(0)!;
      if (raw.startsWith('**')) {
        final inner = raw.substring(2, raw.length - 2);
        spans.add(TextSpan(
          text: inner,
          style: TextStyle(
            color: _getSensorColor(inner),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: raw.substring(1, raw.length - 1),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ));
      }
      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Maps bold keywords to sensor-themed colors
  Color _getSensorColor(String text) {
    final t = text.toLowerCase();
    if (t.contains('soil') || t.contains('moisture')) return AppColors.soilMoisture;
    if (t.contains('ph') || t.contains('acid') || t.contains('alkalin')) return AppColors.phLevel;
    if (t.contains('temp') || t.contains('heat') || t.contains('hot') || t.contains('cold')) return AppColors.temperature;
    if (t.contains('humid')) return AppColors.humidity;
    if (t.contains('water') || t.contains('tank') || t.contains('pump')) return AppColors.waterTank;
    if (t.contains('warn') || t.contains('critical') || t.contains('error') || t.contains('attention')) return AppColors.warning;
    if (t.contains('good') || t.contains('optimal') || t.contains('normal') || t.contains('healthy')) return AppColors.primary;
    return AppColors.primary;
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Analyzing your farm...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUserCrop() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final crops = await _firestore
        .collection('crops')
        .where('farmer_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (crops.docs.isNotEmpty) {
      final cropData = crops.docs.first.data();
      final cropType = cropData['crop_type'] ?? 'Tomato';

      setState(() {
        _userCropId = crops.docs.first.id;
        // Only set the crop if it exists in our list, otherwise default to Tomato
        _selectedCrop = _cropTypes.contains(cropType) ? cropType : 'Tomato';
        _recommendations = _cropDatabase[_selectedCrop];
      });
    }
  }

  void _getRecommendations() {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _recommendations = _cropDatabase[_selectedCrop];
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildCropSelectorCard(),
              const SizedBox(height: 24),
              if (_recommendations != null) ...[
                _buildOptimalSettingsCard(),
                const SizedBox(height: 16),
                _buildTipCard(),
                const SizedBox(height: 16),
                _buildAskAiBanner(),
                const SizedBox(height: 16),
                _buildApplyButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Assistant',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Smart Crop Recommendations',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _openChatPanel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 18),
                SizedBox(width: 6),
                Text(
                  'Ask AI',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Select Crop',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vegetable Type',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCrop,
                isExpanded: true,
                dropdownColor: AppColors.surfaceDark,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondaryDark,
                ),
                items: _cropTypes.map((crop) {
                  return DropdownMenuItem<String>(
                    value: crop,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.eco,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          crop,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCrop = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _getRecommendations,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : const Text(
                      'Get Recommendations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimalSettingsCard() {
    if (_recommendations == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Optimal Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSettingTile(
                  icon: Icons.water_drop,
                  iconColor: AppColors.soilMoisture,
                  label: 'Moisture Range',
                  value:
                      '${_recommendations!['moistureMin']} - ${_recommendations!['moistureMax']}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSettingTile(
                  icon: Icons.science,
                  iconColor: AppColors.phLevel,
                  label: 'Ideal pH',
                  value:
                      '${_recommendations!['phMin']} - ${_recommendations!['phMax']}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSettingTile(
                  icon: Icons.wb_sunny,
                  iconColor: AppColors.warning,
                  label: 'Best Time',
                  value: _recommendations!['bestTime'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSettingTile(
                  icon: Icons.calendar_today,
                  iconColor: AppColors.primary,
                  label: 'Frequency',
                  value: _recommendations!['frequency'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    if (_recommendations == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _recommendations!['tip'],
              style: TextStyle(
                fontSize: 14,
                color: AppColors.info,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAskAiBanner() {
    return GestureDetector(
      onTap: _openChatPanel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Have questions about your crop?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chat with your AI farm advisor',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _applyToIrrigation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.backgroundDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 22),
            SizedBox(width: 8),
            Text(
              'Apply to Auto-Irrigation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyToIrrigation() async {
    if (_recommendations == null || _userCropId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No crop selected'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    try {
      final existing = await _firestore
          .collection('irrigation_rules')
          .where('crop_id', isEqualTo: _userCropId)
          .limit(1)
          .get();

      final ruleData = {
        'crop_id': _userCropId,
        'mode': 'auto',
        'soil_min': _recommendations!['moistureMin'],
        'soil_max': _recommendations!['moistureMax'],
        'ph_min': _recommendations!['phMin'],
        'ph_max': _recommendations!['phMax'],
        'schedule': 'morning',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update(ruleData);
      } else {
        await _firestore.collection('irrigation_rules').add(ruleData);
      }

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings applied! Redirecting to irrigation...'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Wait a moment for user to see the message, then navigate
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to Main Navigation and switch to Irrigation tab (index 2) with Auto tab (index 1)
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainNavigation(
                initialIndex: 2, // Irrigation tab
                irrigationTabIndex: 1, // Auto tab (0 = Manual, 1 = Auto)
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to apply settings'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}

class _FarmContext {
  final Map<String, dynamic> sensorData;
  final Map<String, String> sensorHealth;
  final bool deviceOnline;
  final String? pumpStatus;

  _FarmContext({
    required this.sensorData,
    required this.sensorHealth,
    required this.deviceOnline,
    required this.pumpStatus,
  });

  factory _FarmContext.empty() => _FarmContext(
        sensorData: {},
        sensorHealth: {},
        deviceOnline: false,
        pumpStatus: null,
      );
}
