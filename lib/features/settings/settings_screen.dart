import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/score_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _sound;
  late bool _vibration;

  @override
  void initState() {
    super.initState();
    _sound = ScoreService().isSoundEnabled();
    _vibration = ScoreService().isVibrationEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      AppStrings.settings,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Profile name
                _sectionTitle(context, 'Profile'),
                const SizedBox(height: 10),
                _tile(
                  context,
                  icon: Icons.person_rounded,
                  title: 'Display Name',
                  subtitle: ScoreService().getDisplayName(),
                  onTap: () => _editName(context),
                ),

                const SizedBox(height: 24),
                _sectionTitle(context, 'Preferences'),
                const SizedBox(height: 10),
                _switchTile(
                  context,
                  icon: Icons.volume_up_rounded,
                  title: AppStrings.sound,
                  value: _sound,
                  onChanged: (v) {
                    setState(() => _sound = v);
                    ScoreService().setSoundEnabled(v);
                  },
                ),
                const SizedBox(height: 8),
                _switchTile(
                  context,
                  icon: Icons.vibration_rounded,
                  title: AppStrings.vibration,
                  value: _vibration,
                  onChanged: (v) {
                    setState(() => _vibration = v);
                    ScoreService().setVibrationEnabled(v);
                  },
                ),

                const SizedBox(height: 24),
                _sectionTitle(context, 'About'),
                const SizedBox(height: 10),
                _tile(
                  context,
                  icon: Icons.star_rounded,
                  title: AppStrings.rateApp,
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _tile(
                  context,
                  icon: Icons.share_rounded,
                  title: AppStrings.shareApp,
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                _tile(
                  context,
                  icon: Icons.privacy_tip_rounded,
                  title: AppStrings.privacyPolicy,
                  onTap: () => launchUrl(
                    Uri.parse('https://kalpesh-panchbhai.github.io/puzzloragames/minivo/privacy.html'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const SizedBox(height: 8),
                _tile(
                  context,
                  icon: Icons.description_rounded,
                  title: AppStrings.termsOfService,
                  onTap: () {},
                ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Minivo v1.0.0',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
            letterSpacing: 0.5,
          ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (subtitle != null)
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
            thumbColor: WidgetStateProperty.all(Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller =
        TextEditingController(text: ScoreService().getDisplayName());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ScoreService().setDisplayName(result);
      setState(() {});
    }
  }
}
