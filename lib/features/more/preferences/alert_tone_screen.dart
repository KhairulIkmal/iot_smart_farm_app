import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_localizations.dart';
import '../../../core/theme.dart';

/// ------------------------------------------------------------
/// ALERT TONE SCREEN
///
/// Shows:
/// - Sound toggle
/// - Vibration toggle
/// - Alert tone selection
/// - Volume slider
/// ------------------------------------------------------------
class AlertToneScreen extends StatefulWidget {
  const AlertToneScreen({super.key});

  @override
  State<AlertToneScreen> createState() => _AlertToneScreenState();
}

class _AlertToneScreenState extends State<AlertToneScreen> {
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _selectedTone = 'default';
  double _volume = 0.7;

  final List<_ToneOption> _tones = [
    _ToneOption(id: 'default', name: 'Default', icon: Icons.notifications),
    _ToneOption(id: 'alert', name: 'Alert', icon: Icons.warning_amber),
    _ToneOption(id: 'chime', name: 'Chime', icon: Icons.music_note),
    _ToneOption(id: 'bell', name: 'Bell', icon: Icons.notifications_active),
    _ToneOption(id: 'water', name: 'Water Drop', icon: Icons.water_drop),
    _ToneOption(
      id: 'none',
      name: 'None (Silent)',
      icon: Icons.notifications_off,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _selectedTone = prefs.getString('alert_tone') ?? 'default';
      _volume = prefs.getDouble('alert_volume') ?? 0.7;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setString('alert_tone', _selectedTone);
    await prefs.setDouble('alert_volume', _volume);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      appBar: AppBar(
        backgroundColor: ThemeColors.bg(context),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(context)),
              ),
              child: Icon(
                Icons.arrow_back,
                color: ThemeColors.icon(context),
                size: 24,
              ),
            ),
          ),
        ),
        title: Text(
          l10n.t('Alert Tones'),
          style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sound & Vibration Toggles
            _buildSectionTitle(l10n.t('General')),
            const SizedBox(height: 12),
            _buildToggleCard(
              icon: Icons.volume_up,
              iconColor: AppColors.primary,
              title: l10n.t('Sound'),
              subtitle: l10n.t('Play sound for alerts'),
              value: _soundEnabled,
              onChanged: (v) {
                setState(() => _soundEnabled = v);
                _saveSettings();
              },
            ),
            const SizedBox(height: 12),
            _buildToggleCard(
              icon: Icons.vibration,
              iconColor: AppColors.warning,
              title: l10n.t('Vibration'),
              subtitle: l10n.t('Vibrate on alerts'),
              value: _vibrationEnabled,
              onChanged: (v) {
                setState(() => _vibrationEnabled = v);
                _saveSettings();
              },
            ),
            const SizedBox(height: 24),

            // Volume
            _buildSectionTitle(l10n.t('Volume')),
            const SizedBox(height: 12),
            _buildVolumeCard(l10n),
            const SizedBox(height: 24),

            // Tone Selection
            _buildSectionTitle(l10n.t('Alert Tone')),
            const SizedBox(height: 12),
            _buildToneSelection(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ThemeColors.textSecondary(context).withOpacity(0.5),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: ThemeColors.border(context),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.t('Alert Volume'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
              Text(
                '${(_volume * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.volume_mute,
                color: ThemeColors.textSecondary(context).withOpacity(0.5),
                size: 20,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: ThemeColors.border(context),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withOpacity(0.2),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      _saveSettings();
                    },
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: AppColors.primary, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToneSelection(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        children: _tones.asMap().entries.map((entry) {
          final index = entry.key;
          final tone = entry.value;
          final isSelected = _selectedTone == tone.id;
          final isLast = index == _tones.length - 1;

          return Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() => _selectedTone = tone.id);
                  _saveSettings();
                  // Play preview sound here if needed
                },
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : ThemeColors.bg(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          tone.icon,
                          color: isSelected
                              ? AppColors.primary
                              : ThemeColors.textSecondary(context).withOpacity(0.5),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l10n.t(tone.name),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : ThemeColors.textPrimary(context),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        )
                      else
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ThemeColors.border(context),
                              width: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(height: 1, color: ThemeColors.border(context), indent: 60),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ToneOption {
  final String id;
  final String name;
  final IconData icon;

  _ToneOption({required this.id, required this.name, required this.icon});
}
