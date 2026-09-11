import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pai_morn_web/l10n/l10n.dart';
import 'package:pai_morn_web/l10n/locale_provider.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/utils/pwa_install_controller.dart';

/// A dismissible "Install this app" banner shown at the top of Home.
///
/// Android/Desktop Chrome gets a real Install button (backed by the
/// captured `beforeinstallprompt` event). iOS Safari never fires that
/// event — there's no programmatic install API there at all — so it gets
/// step instructions (Share > Add to Home Screen) instead. Hides itself
/// entirely once already installed/launched standalone, or once dismissed
/// (remembered via shared_preferences, same mechanism as theme persistence
/// in main.dart).
class InstallAppBanner extends StatefulWidget {
  const InstallAppBanner({super.key});

  @override
  State<InstallAppBanner> createState() => _InstallAppBannerState();
}

class _InstallAppBannerState extends State<InstallAppBanner> {
  static const _dismissedPrefsKey = 'install_banner_dismissed';

  final PwaInstallController _controller = PwaInstallController();
  bool _dismissed = true; // starts hidden until prefs confirm otherwise

  @override
  void initState() {
    super.initState();
    _controller.init(() {
      if (mounted) setState(() {});
    });
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _dismissed = prefs.getBool(_dismissedPrefsKey) ?? false);
    });
  }

  void _dismiss() {
    setState(() => _dismissed = true);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_dismissedPrefsKey, true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _controller.isStandalone) return const SizedBox.shrink();
    if (!_controller.isIOS && !_controller.canPromptInstall) {
      return const SizedBox.shrink();
    }

    final language = context.watch<LocaleProvider>().currentLanguage;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.mobileScreenButton, color: scheme.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.getText('installAppTitle', language),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                if (_controller.isIOS) ...[
                  const SizedBox(height: 4),
                  Text(
                    AppTranslations.getText(
                      'installAppIosInstructions',
                      language,
                    ),
                    style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
                  ),
                ],
              ],
            ),
          ),
          if (!_controller.isIOS)
            ElevatedButton(
              onPressed: () async {
                await _controller.promptInstall();
                if (mounted) setState(() {});
              },
              child: Text(
                AppTranslations.getText('installButtonLabel', language),
              ),
            ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
            tooltip: AppTranslations.getText('notNowButtonLabel', language),
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}
