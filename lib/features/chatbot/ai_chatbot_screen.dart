import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/theme.dart';
import '../../core/app_localizations.dart';
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
  Map<String, dynamic>? _recommendations;
  String? _userCropId;

  // Chat state
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;

  static const Map<String, String> _cropEmoji = {
    'Tomato': '🍅', 'Chili': '🌶️', 'Lettuce': '🥬',
    'Cabbage': '🥦', 'Cucumber': '🥒', 'Carrot': '🥕',
    'Potato': '🥔', 'Onion': '🧅', 'Pepper': '🫑',
    'Spinach': '🥬', 'Broccoli': '🥦', 'Other': '🌱',
  };

  final List<String> _cropTypes = [
    'Tomato',
    'Chili',
    'Lettuce',
    'Cabbage',
    'Cucumber',
    'Carrot',
    'Potato',
    'Onion',
    'Pepper',
    'Spinach',
    'Broccoli',
    'Other',
  ];

  // Mutable — overwritten by Firestore data on load. Falls back to _defaultCropThresholds.
  Map<String, Map<String, dynamic>> _cropDatabase = {};

  // Source-backed defaults (FAO-56, UF/IFAS HS1207, UC IPM, NHB India).
  static const Map<String, Map<String, dynamic>> _defaultCropThresholds = {
    'Tomato': {
      'moistureMin': 60, 'moistureMax': 80,
      'phMin': 6.0, 'phMax': 6.8,
      'tempMin': 21, 'tempMax': 27,
      'humidityMin': 65, 'humidityMax': 75,
      'tip': 'Tomatoes need consistent moisture. Avoid wetting leaves to prevent disease. Critical watering during fruit set and expansion.',
    },
    'Chili': {
      'moistureMin': 50, 'moistureMax': 70,
      'phMin': 6.0, 'phMax': 7.0,
      'tempMin': 20, 'tempMax': 30,
      'humidityMin': 60, 'humidityMax': 80,
      'tip': 'Chili prefers well-drained soil. Avoid overwatering — it causes flower and fruit drop. Reduce watering at fruit maturity.',
    },
    'Lettuce': {
      'moistureMin': 60, 'moistureMax': 75,
      'phMin': 6.0, 'phMax': 7.0,
      'tempMin': 15, 'tempMax': 22,
      'humidityMin': 60, 'humidityMax': 70,
      'tip': 'Lettuce has shallow roots (15–30 cm). Keep soil consistently moist but not waterlogged. Grows best in cool conditions.',
    },
    'Cabbage': {
      'moistureMin': 60, 'moistureMax': 75,
      'phMin': 6.0, 'phMax': 7.0,
      'tempMin': 15, 'tempMax': 22,
      'humidityMin': 60, 'humidityMax': 75,
      'tip': 'Cabbage needs consistent moisture for head formation. Mulch to retain soil moisture. Critical period is during head development.',
    },
    'Cucumber': {
      'moistureMin': 60, 'moistureMax': 80,
      'phMin': 6.0, 'phMax': 7.0,
      'tempMin': 18, 'tempMax': 30,
      'humidityMin': 60, 'humidityMax': 85,
      'tip': 'Cucumbers need consistent moisture. Mulch helps retain soil moisture. Avoid wetting foliage to prevent fungal diseases.',
    },
    'Carrot': {
      'moistureMin': 55, 'moistureMax': 70,
      'phMin': 6.0, 'phMax': 6.8,
      'tempMin': 16, 'tempMax': 21,
      'humidityMin': 60, 'humidityMax': 75,
      'tip': 'Carrots require consistent moisture during germination. Avoid over-watering to prevent root rot. Deep watering encourages straight root growth.',
    },
    'Potato': {
      'moistureMin': 60, 'moistureMax': 80,
      'phMin': 5.0, 'phMax': 6.0,
      'tempMin': 15, 'tempMax': 20,
      'humidityMin': 65, 'humidityMax': 80,
      'tip': 'Potatoes need consistent moisture. Irregular watering causes misshapen tubers. Reduce watering as vines die back before harvest.',
    },
    'Onion': {
      'moistureMin': 50, 'moistureMax': 70,
      'phMin': 6.0, 'phMax': 7.0,
      'tempMin': 13, 'tempMax': 24,
      'humidityMin': 55, 'humidityMax': 70,
      'tip': 'Onions need consistent moisture early on. Reduce watering as bulbs mature and necks soften. Stop irrigation 2 weeks before harvest.',
    },
    'Pepper': {
      'moistureMin': 55, 'moistureMax': 70,
      'phMin': 6.0, 'phMax': 6.8,
      'tempMin': 20, 'tempMax': 30,
      'humidityMin': 60, 'humidityMax': 80,
      'tip': 'Peppers prefer deep, infrequent watering. Avoid wet foliage to prevent disease. Water stress at fruit set reduces yield.',
    },
    'Spinach': {
      'moistureMin': 60, 'moistureMax': 75,
      'phMin': 6.0, 'phMax': 7.5,
      'tempMin': 10, 'tempMax': 24,
      'humidityMin': 60, 'humidityMax': 70,
      'tip': 'Spinach prefers cool, moist conditions. Mulch to keep soil cool and retain moisture. Bolts quickly in high heat.',
    },
    'Broccoli': {
      'moistureMin': 60, 'moistureMax': 75,
      'phMin': 6.0, 'phMax': 7.0,
      'tempMin': 15, 'tempMax': 22,
      'humidityMin': 60, 'humidityMax': 75,
      'tip': 'Broccoli needs consistent moisture for head development. Water stress causes premature flowering. Mulch to retain soil moisture and keep roots cool.',
    },
    'Other': {
      'moistureMin': 50, 'moistureMax': 75,
      'phMin': 6.0, 'phMax': 7.0,
      'tempMin': 18, 'tempMax': 30,
      'humidityMin': 60, 'humidityMax': 80,
      'tip': 'Maintain consistent soil moisture and check pH regularly. Irrigate early morning to reduce evaporation losses.',
    },
  };

  @override
  void initState() {
    super.initState();
    _cropDatabase = Map.from(_defaultCropThresholds);
    _recommendations = _cropDatabase[_selectedCrop];
    _loadUserCrop();
    _loadCropThresholds();
  }

  /// Fetches crop thresholds from Firestore `crop_thresholds` collection.
  /// Seeds the collection from [_defaultCropThresholds] if it is empty.
  Future<void> _loadCropThresholds() async {
    try {
      final col = _firestore.collection('crop_thresholds');
      final snap = await col.limit(1).get();

      if (snap.docs.isEmpty) {
        // First run — seed Firestore from defaults
        final batch = _firestore.batch();
        _defaultCropThresholds.forEach((crop, data) {
          batch.set(col.doc(crop), data);
        });
        await batch.commit();
      }

      // Fetch all threshold docs
      final allSnap = await col.get();
      if (allSnap.docs.isEmpty) return;

      final fetched = <String, Map<String, dynamic>>{};
      for (final doc in allSnap.docs) {
        fetched[doc.id] = Map<String, dynamic>.from(doc.data());
      }

      if (mounted) {
        setState(() {
          _cropDatabase = fetched;
          _recommendations = _cropDatabase[_selectedCrop];
        });
      }
    } catch (_) {
      // Keep local defaults on any error
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<_FarmContext> _fetchFarmContext() async {
    final user = _auth.currentUser;
    final deviceId = SelectedCropService().selectedCrop?.deviceId;

    // ── RTDB: live sensor data ──
    Map<String, dynamic> sensorData = {};
    Map<String, String> sensorHealth = {};
    bool isOnline = false;
    String? pumpStatus;

    if (deviceId != null) {
      try {
        final rtdb = RtdbService();
        final results = await Future.wait([
          rtdb.getLiveData(deviceId),
          rtdb.getSensorHealth(deviceId),
          rtdb.isDeviceOnline(deviceId),
          rtdb.getPumpStatus(deviceId),
        ]);
        final liveSnapshot = results[0] as DataSnapshot;
        sensorHealth = results[1] as Map<String, String>;
        isOnline = results[2] as bool;
        pumpStatus = results[3] as String?;
        if (liveSnapshot.exists && liveSnapshot.value != null) {
          sensorData = Map<String, dynamic>.from(liveSnapshot.value as Map);
        }
      } catch (_) {}
    }

    // ── Firestore: crops, irrigation rules, thresholds ──
    List<Map<String, dynamic>> userCrops = [];
    Map<String, dynamic>? irrigationRule;
    Map<String, dynamic>? cropThreshold;

    if (user != null) {
      try {
        // Kick off all futures simultaneously (parallel network calls)
        final cropsF = _firestore
            .collection('crops')
            .where('farmer_id', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .get();

        final rulesF = _userCropId != null
            ? _firestore
                .collection('irrigation_rules')
                .where('crop_id', isEqualTo: _userCropId)
                .limit(1)
                .get()
            : null;

        final threshF = _firestore
            .collection('crop_thresholds')
            .doc(_selectedCrop)
            .get();

        // Await results (they've been running in parallel since the futures were created)
        final cropsSnap = await cropsF;
        final rulesSnap = rulesF != null ? await rulesF : null;
        final threshSnap = await threshF;

        userCrops = cropsSnap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          return data;
        }).toList();

        if (rulesSnap != null && rulesSnap.docs.isNotEmpty) {
          irrigationRule = Map<String, dynamic>.from(rulesSnap.docs.first.data());
        }

        if (threshSnap.exists && threshSnap.data() != null) {
          cropThreshold = Map<String, dynamic>.from(threshSnap.data()!);
        }
      } catch (_) {}
    }

    return _FarmContext(
      sensorData: sensorData,
      sensorHealth: sensorHealth,
      deviceOnline: isOnline,
      pumpStatus: pumpStatus,
      userCrops: userCrops,
      irrigationRule: irrigationRule,
      cropThreshold: cropThreshold,
    );
  }

  Future<void> _openChatPanel() async {
    if (_chatMessages.isEmpty) {
      setState(() => _isChatLoading = true);
      final ctx = await _fetchFarmContext();

      final statusLabel = ctx.deviceOnline ? '🟢 ONLINE' : '🔴 OFFLINE';
      final soil = ctx.sensorData['soil']?.toString() ?? 'N/A';
      final ph = ctx.sensorData['ph']?.toString() ?? 'N/A';
      final temp = ctx.sensorData['temp']?.toString() ?? 'N/A';
      final humidity = ctx.sensorData['humidity']?.toString() ?? 'N/A';
      final tank = ctx.sensorData['waterLevel']?.toString() ?? 'N/A';
      final pump = ctx.pumpStatus ?? 'unknown';

      final cropCount = ctx.userCrops.length;
      final cropLine = cropCount > 0
          ? '$cropCount active crop${cropCount > 1 ? 's' : ''} found'
          : 'No active crops found';

      final irrigLine = ctx.irrigationRule != null
          ? 'Mode: ${ctx.irrigationRule!['mode'] ?? 'unknown'}'
          : 'No irrigation rules set';

      _chatMessages.add({
        'role': 'assistant',
        'text': 'Hello! I\'m your AI farm advisor. I have access to your live sensor data and farm records.\n\n'
            '**Device:** $statusLabel\n'
            '**Crop focus:** $_selectedCrop | $cropLine\n\n'
            '**Live Readings:**\n'
            '• Soil: $soil% | pH: $ph | Temp: $temp°C\n'
            '• Humidity: $humidity% | Tank: $tank% | Pump: $pump\n\n'
            '**Irrigation:** $irrigLine\n\n'
            'Ask me anything about your crop, sensors, or irrigation — I\'ll only answer based on your actual data.',
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

    // Snapshot history BEFORE adding current message
    final history = List<Map<String, String>>.from(_chatMessages);

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
        conversationHistory: history,
        userCrops: ctx.userCrops,
        irrigationRule: ctx.irrigationRule,
        cropThreshold: ctx.cropThreshold,
      );
      setState(() {
        _chatMessages.add({'role': 'assistant', 'text': reply});
        _isChatLoading = false;
      });
    } catch (e) {
      final errorText = e.toString().contains('ClaudeException:')
          ? e.toString().replaceFirst('ClaudeException: ', '')
          : 'Unable to reach AI right now. Please check your connection and try again.';
      setState(() {
        _chatMessages.add({'role': 'assistant', 'text': errorText});
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
        'Is my soil moisture okay for $_selectedCrop?',
        'Is my current temperature suitable?',
        'How do I set up auto-irrigation?',
        'How do I connect my device?',
        'Is my pump working correctly?',
        'What does my pH level mean for my crop?',
        'How do I create a support ticket?',
        'How do I add a new crop?',
      ];

  Widget _buildSuggestedQuestions(StateSetter setSheetState) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        border: Border(top: BorderSide(color: ThemeColors.border(context))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              AppLocalizations.of(context).t('Suggested'),
              style: TextStyle(
                color: ThemeColors.textSecondary(context).withOpacity(0.4),
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
              decoration: BoxDecoration(
                color: ThemeColors.bg(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ThemeColors.border(context),
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
                            Text(
                              AppLocalizations.of(context).t('AI Farm Advisor'),
                              style: TextStyle(
                                color: ThemeColors.textPrimary(context),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Farm advisor & app guide • $_selectedCrop',
                              style: TextStyle(
                                color: ThemeColors.textSecondary(context).withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(color: ThemeColors.border(context), height: 1),
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
                      color: ThemeColors.surface(context),
                      border: Border(
                        top: BorderSide(color: ThemeColors.border(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: TextStyle(color: ThemeColors.textPrimary(context)),
                            decoration: InputDecoration(
                              hintText: 'Ask about your crop or how to use the app...',
                              hintStyle: TextStyle(
                                color: ThemeColors.textSecondary(context).withOpacity(0.4),
                              ),
                              filled: true,
                              fillColor: ThemeColors.bg(context),
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
                            child: Icon(
                              Icons.send_rounded,
                              color: ThemeColors.bg(context),
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
          color: isUser ? AppColors.primary : ThemeColors.surface(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: ThemeColors.border(context)),
        ),
        child: isUser
            ? Text(
                text,
                style: TextStyle(
                  color: ThemeColors.bg(context),
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
          style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14, height: 1.5),
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
          style: TextStyle(
            color: ThemeColors.textSecondary(context),
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
        style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14, height: 1.5),
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
    // Cycle through contextual loading messages based on chat length
    final hints = [
      'Reading your sensor data...',
      'Checking your farm records...',
      'Analyzing crop conditions...',
      'Preparing advice...',
    ];
    final hint = hints[(_chatMessages.length - 1) % hints.length];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: ThemeColors.border(context)),
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
              hint,
              style: TextStyle(
                color: ThemeColors.textSecondary(context).withOpacity(0.5),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                child: _buildCropSelector(),
              ),
            ),
            if (_recommendations != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _buildThresholdsSection(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildTipCard(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildAskAiBanner(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: _buildApplyButton(),
                ),
              ),
            ],
          ],
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
            Text(
              AppLocalizations.of(context).t('AI Assistant'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).t('Crop Threshold Recommendations'),
              style: TextStyle(
                fontSize: 13,
                color: ThemeColors.textSecondary(context).withOpacity(0.5),
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _openChatPanel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.35)),
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

  Widget _buildCropSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SELECT CROP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ThemeColors.textSecondary(context).withOpacity(0.55),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cropTypes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final crop = _cropTypes[i];
              final selected = crop == _selectedCrop;
              final emoji = _cropEmoji[crop] ?? '🌱';
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedCrop = crop;
                  _recommendations = _cropDatabase[crop];
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : ThemeColors.surface(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected ? AppColors.primary : ThemeColors.border(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        crop,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : ThemeColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdsSection() {
    if (_recommendations == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'OPTIMAL THRESHOLDS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ThemeColors.textSecondary(context).withOpacity(0.55),
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_cropEmoji[_selectedCrop] ?? '🌱'} $_selectedCrop',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildThresholdCard(
                icon: Icons.water_drop_rounded,
                iconColor: AppColors.soilMoisture,
                label: 'Soil Moisture',
                minVal: (_recommendations!['moistureMin'] as num).toDouble(),
                maxVal: (_recommendations!['moistureMax'] as num).toDouble(),
                unit: '%',
                scaleMax: 100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildThresholdCard(
                icon: Icons.science_rounded,
                iconColor: AppColors.phLevel,
                label: 'pH Level',
                minVal: (_recommendations!['phMin'] as num).toDouble(),
                maxVal: (_recommendations!['phMax'] as num).toDouble(),
                unit: '',
                scaleMax: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildThresholdCard(
                icon: Icons.thermostat_rounded,
                iconColor: AppColors.temperature,
                label: 'Temperature',
                minVal: (_recommendations!['tempMin'] as num?)?.toDouble() ?? 18,
                maxVal: (_recommendations!['tempMax'] as num?)?.toDouble() ?? 30,
                unit: '°C',
                scaleMax: 50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildThresholdCard(
                icon: Icons.water_rounded,
                iconColor: AppColors.humidity,
                label: 'Humidity',
                minVal: (_recommendations!['humidityMin'] as num?)?.toDouble() ?? 60,
                maxVal: (_recommendations!['humidityMax'] as num?)?.toDouble() ?? 80,
                unit: '%',
                scaleMax: 100,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _fmtVal(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  Widget _buildThresholdCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double minVal,
    required double maxVal,
    required String unit,
    required double scaleMax,
  }) {
    final barStart = (minVal / scaleMax).clamp(0.0, 1.0);
    final barWidth = ((maxVal - minVal) / scaleMax).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ThemeColors.textSecondary(context).withOpacity(0.55),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_fmtVal(minVal)} – ${_fmtVal(maxVal)}$unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 5,
                    width: w,
                    decoration: BoxDecoration(
                      color: ThemeColors.border(context),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Positioned(
                    left: barStart * w,
                    child: Container(
                      height: 5,
                      width: (barWidth * w).clamp(4.0, w),
                      decoration: BoxDecoration(
                        color: iconColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              );
            },
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
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pro Tip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _recommendations!['tip'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textPrimary(context),
                    height: 1.5,
                  ),
                ),
              ],
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
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Have questions about your crop?',
                    style: TextStyle(
                      color: ThemeColors.textPrimary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chat with your AI farm advisor →',
                    style: TextStyle(
                      color: AppColors.primary.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right, color: Colors.white, size: 16),
            ),
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
          foregroundColor: ThemeColors.bg(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 22),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context).t('Apply to Auto-Irrigation'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyToIrrigation() async {
    if (_recommendations == null || _userCropId == null) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('No crop selected')),
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
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update(ruleData);
      } else {
        await _firestore.collection('irrigation_rules').add(ruleData);
      }

      if (mounted) {
        // Show success message
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('Settings applied! Redirecting to irrigation...')),
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
  final List<Map<String, dynamic>> userCrops;
  final Map<String, dynamic>? irrigationRule;
  final Map<String, dynamic>? cropThreshold;

  _FarmContext({
    required this.sensorData,
    required this.sensorHealth,
    required this.deviceOnline,
    required this.pumpStatus,
    this.userCrops = const [],
    this.irrigationRule,
    this.cropThreshold,
  });

  factory _FarmContext.empty() => _FarmContext(
        sensorData: {},
        sensorHealth: {},
        deviceOnline: false,
        pumpStatus: null,
      );
}
