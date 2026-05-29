import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';

class SupportChatScreen extends StatefulWidget {
  final String ticketId;
  final String subject;

  const SupportChatScreen({
    super.key,
    required this.ticketId,
    required this.subject,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _ticketStatus = 'open';
  String? _farmerName;
  bool _sending = false;
  bool _uploadingImage = false;
  bool _inputEmpty = true;
  int _prevMessageCount = 0;

  final ImagePicker _imagePicker = ImagePicker();

  static const _chatSuggestions = [
    'My device keeps going offline',
    'The sensor readings seem wrong',
    'Pump is not turning on',
    'How do I reset my device?',
    'The app is not showing data',
  ];

  // uid → photoURL (null = no photo, absent = not yet fetched)
  final Map<String, String?> _photoCache = {};

  @override
  void initState() {
    super.initState();
    _clearUnread();
    _fetchFarmerName();
    _inputController.addListener(() {
      final empty = _inputController.text.isEmpty;
      if (empty != _inputEmpty) setState(() => _inputEmpty = empty);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _clearUnread() async {
    await _firestore
        .collection('support_tickets')
        .doc(widget.ticketId)
        .update({'unread_farmer': 0});
  }

  Future<void> _fetchFarmerName() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final docs = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (docs.docs.isNotEmpty) {
        final data = docs.docs.first.data();
        if (mounted) {
          setState(() {
            _farmerName = data['name'] ?? data['displayName'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchPhotos(List<String> uids) async {
    final missing = uids.where((uid) => !_photoCache.containsKey(uid)).toList();
    if (missing.isEmpty) return;
    // Mark as known (null) to avoid duplicate fetches while awaiting
    for (final uid in missing) {
      _photoCache[uid] = null;
    }
    for (int i = 0; i < missing.length; i += 10) {
      final batch = missing.sublist(i, (i + 10).clamp(0, missing.length));
      try {
        final snap = await _firestore
            .collection('users')
            .where('uid', whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          final uid = d['uid'] as String?;
          if (uid != null) _photoCache[uid] = d['photoURL'] as String?;
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    final user = _auth.currentUser!;
    setState(() => _sending = true);
    _inputController.clear();

    try {
      await _firestore
          .collection('support_tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
        'sender_uid': user.uid,
        'sender_name': _farmerName ?? user.displayName ?? 'Farmer',
        'sender_role': 'farmer',
        'text': text,
        'sent_at': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('support_tickets').doc(widget.ticketId).update({
        'updated_at': FieldValue.serverTimestamp(),
        'unread_farmer': 0,
      });
    } catch (_) {}

    if (mounted) setState(() => _sending = false);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ThemeColors.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Send Image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _imageSourceOption(
                      ctx: ctx,
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imageSourceOption(
                      ctx: ctx,
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSourceOption({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked == null) return;

    final user = _auth.currentUser!;
    setState(() => _uploadingImage = true);

    try {
      // Upload to Firebase Storage
      final ext = picked.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance
          .ref()
          .child('support_tickets')
          .child(widget.ticketId)
          .child(fileName);

      final uploadTask = await ref.putFile(File(picked.path));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Save message to Firestore
      await _firestore
          .collection('support_tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .add({
        'sender_uid': user.uid,
        'sender_name': _farmerName ?? user.displayName ?? 'Farmer',
        'sender_role': 'farmer',
        'type': 'image',
        'image_url': downloadUrl,
        'text': '',
        'sent_at': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('support_tickets')
          .doc(widget.ticketId)
          .update({
        'updated_at': FieldValue.serverTimestamp(),
        'unread_farmer': 0,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send image. Please try again.')),
        );
      }
    }

    if (mounted) setState(() => _uploadingImage = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.primary;
      case 'in_progress':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Resolved';
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      // Disable body resize — only the input bar moves up, not the entire ListView.
      // Rebuilding the whole message list on keyboard open causes the lag.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: ThemeColors.bg(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ThemeColors.border(context)),
            ),
            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
          ),
        ),
        title: Text(
          widget.subject,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ThemeColors.textPrimary(context),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('support_tickets')
                .doc(widget.ticketId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final status = data['status'] as String? ?? 'open';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _ticketStatus != status) {
                    setState(() => _ticketStatus = status);
                  }
                });
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: ThemeColors.border(context)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('support_tickets')
                  .doc(widget.ticketId)
                  .collection('messages')
                  .orderBy('sent_at', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        color: ThemeColors.textSecondary(context).withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                final newCount = docs.length;

                // Pre-fetch photos for any new sender UIDs
                final uids = docs
                    .map((d) => (d.data() as Map<String, dynamic>)['sender_uid'] as String?)
                    .whereType<String>()
                    .toSet()
                    .toList();
                if (uids.any((uid) => !_photoCache.containsKey(uid))) {
                  _fetchPhotos(uids);
                }

                // Only scroll when message count changes — not on keyboard open/close.
                if (newCount != _prevMessageCount) {
                  final isFirstLoad = _prevMessageCount == 0;
                  _prevMessageCount = newCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      if (isFirstLoad) {
                        // Jump instantly on first load — no animation lag.
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      } else {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        );
                      }
                    }
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final type = data['type'] as String?;

                    // Device info attachment card
                    if (type == 'device_info') {
                      return _buildDeviceInfoCard(data);
                    }

                    final role       = data['sender_role'] as String? ?? 'farmer';
                    final text       = data['text']        as String? ?? '';
                    final imageUrl   = data['image_url']   as String?;
                    final senderName = data['sender_name'] as String? ?? '';
                    final senderUid  = data['sender_uid']  as String? ?? '';
                    final sentAt     = data['sent_at']     as Timestamp?;
                    final isFarmer   = role == 'farmer';

                    final bool showAvatar = index == 0 ||
                        (docs[index - 1].data() as Map<String, dynamic>)['sender_role'] != role;

                    if (imageUrl != null && imageUrl.isNotEmpty) {
                      return _buildImageBubble(
                        imageUrl: imageUrl,
                        senderName: senderName,
                        senderUid: senderUid,
                        isFarmer: isFarmer,
                        showAvatar: showAvatar,
                        sentAt: sentAt,
                      );
                    }

                    return _buildBubble(
                      text: text,
                      senderName: senderName,
                      senderUid: senderUid,
                      isFarmer: isFarmer,
                      showAvatar: showAvatar,
                      sentAt: sentAt,
                    );
                  },
                );
              },
            ),
          ),
          if (_ticketStatus == 'resolved')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: ThemeColors.surface(context),
              child: Center(
                child: Text(
                  'This ticket has been resolved',
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
                ),
              ),
            )
          else
            Padding(
              // Only this wrapper responds to the keyboard — body doesn't resize.
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChatSuggestions(),
                  Container(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                border: Border(top: BorderSide(color: ThemeColors.border(context))),
              ),
              child: Row(
                children: [
                  // Attachment button
                  GestureDetector(
                    onTap: _uploadingImage ? null : _showImageSourceSheet,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ThemeColors.bg(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _uploadingImage
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            )
                          : Icon(
                              Icons.attach_file_rounded,
                              color: ThemeColors.textSecondary(context).withOpacity(0.5),
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: TextStyle(color: ThemeColors.textPrimary(context)),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
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
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _sending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ThemeColors.bg(context),
                                ),
                              ),
                            )
                          : Icon(
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
              ), // closes Column
            ), // closes Padding(viewInsets)
        ],
      ),
    );
  }

  Widget _buildChatSuggestions() {
    if (!_inputEmpty) return const SizedBox.shrink();
    return Container(
      color: ThemeColors.surface(context),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _chatSuggestions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _inputController.text = _chatSuggestions[i],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Text(
                    _chatSuggestions[i],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard(Map<String, dynamic> data) {
    final uniqueCode = data['unique_code'] as String? ?? data['device_id'] as String? ?? '—';
    final cropName   = data['crop_name']  as String? ?? '';
    final imageUrl   = data['image_url']  as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ThemeColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(13),
                  ),
                  border: Border(bottom: BorderSide(color: ThemeColors.border(context))),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.memory_rounded, color: AppColors.primary, size: 15),
                    const SizedBox(width: 6),
                    const Text(
                      'Device Details',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ],
                ),
              ),

              // Crop image + fields row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Crop thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _cropPlaceholder(),
                            )
                          : _cropPlaceholder(),
                    ),
                    const SizedBox(width: 12),
                    // Info fields
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('Device', uniqueCode),
                          if (cropName.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            _infoRow('Crop', cropName),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cropPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 28),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ThemeColors.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageBubble({
    required String imageUrl,
    required String senderName,
    required String senderUid,
    required bool isFarmer,
    required bool showAvatar,
    required Timestamp? sentAt,
  }) {
    const metaStyle = TextStyle(fontSize: 11, color: Colors.white38);
    const nameStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white38);

    final imageWidget = GestureDetector(
      onTap: () => _openImageViewer(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 200,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 200,
              height: 160,
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: 200,
            height: 100,
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.broken_image_outlined, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );

    if (isFarmer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Text(senderName, style: nameStyle),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: imageWidget,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, right: 4),
            child: Text(_formatTime(sentAt), style: metaStyle),
          ),
        ],
      );
    }

    // Admin side
    final photoURL = _photoCache[senderUid];
    final parts = senderName.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final ini = parts.isEmpty
        ? '?'
        : parts.map((w) => w[0]).join().substring(0, parts.length > 1 ? 2 : 1).toUpperCase();

    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.15),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoURL != null
          ? Image.network(photoURL, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
              Center(child: Text(ini, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary))))
          : Center(child: Text(ini, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary))),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          showAvatar ? avatar : const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(senderName, style: nameStyle),
                  ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A402D),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                  ),
                  child: imageWidget,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2),
                  child: Text(_formatTime(sentAt), style: metaStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openImageViewer(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: InteractiveViewer(
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble({
    required String text,
    required String senderName,
    required String senderUid,
    required bool isFarmer,
    required bool showAvatar,
    required Timestamp? sentAt,
  }) {
    const bubbleTextStyle = TextStyle(fontSize: 14, color: Colors.white, height: 1.4);
    const metaStyle  = TextStyle(fontSize: 11, color: Colors.white38);
    const nameStyle  = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white38);

    // Farmer messages — right side, no avatar
    if (isFarmer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Text(senderName, style: nameStyle),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(text, style: bubbleTextStyle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, right: 4),
            child: Text(_formatTime(sentAt), style: metaStyle),
          ),
        ],
      );
    }

    // Admin messages — left side with avatar
    final photoURL = _photoCache[senderUid];
    final _parts = senderName.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final ini = _parts.isEmpty ? '?' : _parts.map((w) => w[0]).join().substring(0, _parts.length > 1 ? 2 : 1).toUpperCase();

    final avatar = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.15),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoURL != null
          ? Image.network(
              photoURL,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(ini, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            )
          : Center(
              child: Text(ini, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar — show on first of a group, invisible spacer otherwise
          showAvatar ? avatar : const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAvatar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(senderName, style: nameStyle),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A402D),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(text, style: bubbleTextStyle),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 2),
                  child: Text(_formatTime(sentAt), style: metaStyle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
