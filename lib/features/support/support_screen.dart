import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';
import 'support_chat_screen.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // '' = active tickets only, 'resolved' = done/archived
  String _ticketFilter = '';

  String _formatUpdatedAt(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.radio_button_checked;
      case 'in_progress':
        return Icons.timelapse_rounded;
      default:
        return Icons.check_circle_rounded;
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

  void _showNewTicketDialog() {
    showDialog(
      context: context,
      builder: (_) => _NewTicketDialog(
        onCreated: (ticketId, subject) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SupportChatScreen(ticketId: ticketId, subject: subject),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('support_tickets')
              .where('farmer_uid', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.hasData ? [...snapshot.data!.docs] : <QueryDocumentSnapshot>[];
            allDocs.sort((a, b) {
              final at = (a.data() as Map<String, dynamic>)['updated_at'] as Timestamp?;
              final bt = (b.data() as Map<String, dynamic>)['updated_at'] as Timestamp?;
              if (at == null && bt == null) return 0;
              if (at == null) return 1;
              if (bt == null) return -1;
              return bt.compareTo(at);
            });

            final openCount = allDocs.where((d) =>
                (d.data() as Map<String, dynamic>)['status'] == 'open').length;
            final inProgressCount = allDocs.where((d) =>
                (d.data() as Map<String, dynamic>)['status'] == 'in_progress').length;
            final resolvedCount = allDocs.where((d) =>
                (d.data() as Map<String, dynamic>)['status'] == 'resolved').length;

            return CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ThemeColors.surface(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ThemeColors.border(context)),
                            ),
                            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Help & Support',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: ThemeColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Hero Banner ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _buildHeroBanner(),
                  ),
                ),

                // ── Stats Strip ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildStatsStrip(
                      total: allDocs.length,
                      open: openCount,
                      inProgress: inProgressCount,
                      resolved: resolvedCount,
                    ),
                  ),
                ),

                // ── Tickets Section Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'YOUR TICKETS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: ThemeColors.textSecondary(context).withOpacity(0.65),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _showNewTicketDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: Colors.white, size: 16),
                                SizedBox(width: 5),
                                Text(
                                  'New Ticket',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Filter Tabs ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ThemeColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ThemeColors.border(context)),
                      ),
                      child: Row(
                        children: [
                          _filterTab(
                            label: 'Active',
                            count: openCount + inProgressCount,
                            selected: _ticketFilter == '',
                            onTap: () => setState(() => _ticketFilter = ''),
                          ),
                          const SizedBox(width: 4),
                          _filterTab(
                            label: 'Done',
                            count: resolvedCount,
                            selected: _ticketFilter == 'resolved',
                            onTap: () => setState(() => _ticketFilter = 'resolved'),
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Ticket List or Empty State ──
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  )
                else
                  Builder(builder: (_) {
                    final filtered = _ticketFilter == 'resolved'
                        ? allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'resolved').toList()
                        : allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] != 'resolved').toList();

                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        child: _ticketFilter == 'resolved'
                            ? _buildEmptyResolved()
                            : _buildEmptyState(),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = filtered[index];
                            final data = doc.data() as Map<String, dynamic>;
                            return _buildTicketCard(doc.id, data);
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  /// ── Hero Banner ──
  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.18),
            AppColors.primary.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'re here to help 👋',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Having trouble with your device?\nSubmit a ticket and our team will\nget back to you shortly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context).withOpacity(0.65),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _infoPill(Icons.access_time_rounded, 'Avg. reply < 24h'),
                    const SizedBox(width: 8),
                    _infoPill(Icons.verified_outlined, 'Expert support'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.primary,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// ── Stats Strip ──
  Widget _buildStatsStrip({
    required int total,
    required int open,
    required int inProgress,
    required int resolved,
  }) {
    return Row(
      children: [
        Expanded(child: _statChip(label: 'Total', value: '$total', color: ThemeColors.textSecondary(context))),
        const SizedBox(width: 8),
        Expanded(child: _statChip(label: 'Open', value: '$open', color: AppColors.primary)),
        const SizedBox(width: 8),
        Expanded(child: _statChip(label: 'In Progress', value: '$inProgress', color: AppColors.warning)),
        const SizedBox(width: 8),
        Expanded(child: _statChip(label: 'Resolved', value: '$resolved', color: Colors.grey)),
      ],
    );
  }

  Widget _statChip({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// ── Ticket Card ──
  Widget _buildTicketCard(String docId, Map<String, dynamic> data) {
    final subject = data['subject'] as String? ?? '';
    final status = data['status'] as String? ?? 'open';
    final deviceId = data['device_code'] as String? ??
        data['device_id'] as String? ?? '';
    final updatedAt = data['updated_at'] as Timestamp?;
    final unread = (data['unread_farmer'] as int?) ?? 0;
    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SupportChatScreen(ticketId: docId, subject: subject),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread > 0 ? AppColors.primary.withOpacity(0.5) : ThemeColors.border(context),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // Status accent bar
              Container(
                width: 4,
                height: 80,
                color: statusColor,
              ),
              const SizedBox(width: 14),
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(status), color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ThemeColors.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          if (deviceId.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.memory, size: 11,
                                color: ThemeColors.textSecondary(context).withOpacity(0.4)),
                            const SizedBox(width: 3),
                            Text(
                              deviceId,
                              style: TextStyle(
                                fontSize: 11,
                                color: ThemeColors.textSecondary(context).withOpacity(0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatUpdatedAt(updatedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: ThemeColors.textSecondary(context).withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right side — unread badge or chevron
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: unread > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.chevron_right,
                        color: ThemeColors.textSecondary(context).withOpacity(0.3),
                        size: 20,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ── Filter Tab ──
  Widget _filterTab({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeColor = color ?? AppColors.primary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? activeColor
                      : ThemeColors.textSecondary(context).withOpacity(0.45),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? activeColor.withOpacity(0.2) : ThemeColors.border(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? activeColor
                          : ThemeColors.textSecondary(context).withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// ── Empty Resolved State ──
  Widget _buildEmptyResolved() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, size: 38, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            'No resolved tickets',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tickets marked as resolved\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: ThemeColors.textSecondary(context).withOpacity(0.45),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// ── Empty State ──
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.mark_chat_unread_outlined,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No tickets yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Having a problem with your device?\nOur support team is ready to help you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _showNewTicketDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_comment_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Start a Conversation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Typical response time: within 24 hours',
            style: TextStyle(
              fontSize: 12,
              color: ThemeColors.textSecondary(context).withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// NEW TICKET DIALOG
// ----------------------------------------------------------------
class _NewTicketDialog extends StatefulWidget {
  final void Function(String ticketId, String subject) onCreated;

  const _NewTicketDialog({required this.onCreated});

  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _loadingDevices = true;
  bool _submitting = false;
  String? _farmerName;

  // Each entry: { device_id, unique_code, crop_name }
  List<Map<String, String>> _devices = [];
  int _selectedIdx = 0;

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchDevices() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loadingDevices = false);
      return;
    }

    try {
      // Farmer name
      final userDocs = await _firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (userDocs.docs.isNotEmpty) {
        final ud = userDocs.docs.first.data();
        _farmerName = ud['name'] as String? ?? ud['displayName'] as String? ?? 'Farmer';
      }

      // All active crops — no limit
      final crops = await _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (crops.docs.isEmpty) {
        setState(() => _loadingDevices = false);
        return;
      }

      // Collect device IDs then batch-fetch device docs for unique_code
      final deviceIds = crops.docs
          .map((d) => d.data()['device_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final Map<String, String> uniqueCodeMap = {};
      for (int i = 0; i < deviceIds.length; i += 10) {
        final batch = deviceIds.sublist(i, (i + 10).clamp(0, deviceIds.length));
        try {
          final devSnap = await _firestore
              .collection('devices')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          for (final doc in devSnap.docs) {
            final uc = doc.data()['unique_code'] as String?;
            if (uc != null && uc.isNotEmpty) uniqueCodeMap[doc.id] = uc;
          }
        } catch (_) {}
      }

      final devices = crops.docs
          .map((doc) {
            final data = doc.data();
            final deviceId = data['device_id'] as String? ?? '';
            if (deviceId.isEmpty) return null;
            final cropName = data['crop_name'] as String? ??
                data['crop_type'] as String? ?? '';
            final uniqueCode = uniqueCodeMap[deviceId] ??
                data['unique_code'] as String? ?? deviceId;
            final imageUrl = data['image_url'] as String? ?? '';
            debugPrint('[Support] crop doc id=${doc.id} device=$deviceId image_url="$imageUrl"');
            return {
              'device_id':   deviceId,
              'unique_code': uniqueCode,
              'crop_name':   cropName,
              'image_url':   imageUrl,
            };
          })
          .whereType<Map<String, String>>()
          .toList();

      if (mounted) {
        setState(() {
          _devices = devices;
          _loadingDevices = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final description = _descController.text.trim();
    if (subject.isEmpty || description.isEmpty) return;

    final user = _auth.currentUser!;
    final selected = _devices[_selectedIdx];
    setState(() => _submitting = true);

    try {
      final ticketRef = await _firestore.collection('support_tickets').add({
        'farmer_uid':   user.uid,
        'farmer_name':  _farmerName ?? user.displayName ?? 'Farmer',
        'device_id':    selected['device_id'],
        'device_code':  selected['unique_code'],
        'subject':      subject,
        'status':       'open',
        'created_at':   FieldValue.serverTimestamp(),
        'updated_at':   FieldValue.serverTimestamp(),
        'unread_farmer': 0,
        'unread_admin':  1,
      });

      debugPrint('[Support] submitting device_info — image_url="${selected['image_url']}"');
      // First message: auto-attached device details card
      await ticketRef.collection('messages').add({
        'type':        'device_info',
        'sender_role': 'system',
        'device_id':   selected['device_id'],
        'unique_code': selected['unique_code'],
        'crop_name':   selected['crop_name'],
        'image_url':   selected['image_url'],
        'sent_at':     FieldValue.serverTimestamp(),
      });

      // Second message: farmer's description
      await ticketRef.collection('messages').add({
        'sender_uid':  user.uid,
        'sender_name': _farmerName ?? user.displayName ?? 'Farmer',
        'sender_role': 'farmer',
        'text':        description,
        'sent_at':     FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(ticketRef.id, subject);
      }
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Device section: loading / no device / single / multi-picker ──
  Widget _buildDeviceSection() {
    if (_loadingDevices) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading devices...',
              style: TextStyle(
                fontSize: 13,
                color: ThemeColors.textSecondary(context).withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No active device found',
                style: TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    }

    // Single device — just a chip, no picker needed
    if (_devices.length == 1) {
      final d = _devices[0];
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.memory, color: AppColors.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['unique_code']!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (d['crop_name']!.isNotEmpty)
                    Text(
                      d['crop_name']!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Multiple devices — radio-style picker
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Which device are you reporting?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ThemeColors.textSecondary(context).withOpacity(0.55),
            ),
          ),
        ),
        ...List.generate(_devices.length, (i) {
          final d = _devices[i];
          final selected = i == _selectedIdx;
          return GestureDetector(
            onTap: () => setState(() => _selectedIdx = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.1)
                    : ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppColors.primary.withOpacity(0.55)
                      : ThemeColors.border(context),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Radio dot
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : ThemeColors.border(context),
                        width: 2,
                      ),
                      color: selected ? AppColors.primary : Colors.transparent,
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.memory,
                    size: 15,
                    color: selected
                        ? AppColors.primary
                        : ThemeColors.textSecondary(context).withOpacity(0.35),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['unique_code']!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.primary
                                : ThemeColors.textPrimary(context),
                          ),
                        ),
                        if (d['crop_name']!.isNotEmpty)
                          Text(
                            d['crop_name']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: ThemeColors.textSecondary(context).withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_loadingDevices && _devices.isNotEmpty && !_submitting;

    return AlertDialog(
      backgroundColor: ThemeColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'New Support Ticket',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: ThemeColors.textPrimary(context),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceSection(),
            TextField(
              controller: _subjectController,
              maxLength: 100,
              style: TextStyle(color: ThemeColors.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Subject',
                hintText: 'Brief description of the issue',
                labelStyle: TextStyle(color: ThemeColors.textSecondary(context)),
                hintStyle: TextStyle(
                  color: ThemeColors.textSecondary(context).withOpacity(0.4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ThemeColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                counterStyle: TextStyle(
                  color: ThemeColors.textSecondary(context).withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLength: 500,
              maxLines: 4,
              style: TextStyle(color: ThemeColors.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the problem in detail...',
                alignLabelWithHint: true,
                labelStyle: TextStyle(color: ThemeColors.textSecondary(context)),
                hintStyle: TextStyle(
                  color: ThemeColors.textSecondary(context).withOpacity(0.4),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ThemeColors.border(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                counterStyle: TextStyle(
                  color: ThemeColors.textSecondary(context).withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: ThemeColors.textSecondary(context).withOpacity(0.6),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: ThemeColors.bg(context),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _submitting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(ThemeColors.bg(context)),
                  ),
                )
              : const Text('Submit', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
