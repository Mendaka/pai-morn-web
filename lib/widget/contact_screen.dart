import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pai_morn_web/theme/app_theme.dart';
import 'package:pai_morn_web/widget/hover_scale.dart';

/// Replaces the old page, which was entirely placeholder-template content:
/// a fake email/phone/address, three social icons wired to nothing (a
/// "TODO: use url_launcher" comment instead of an actual link), and a
/// site-satisfaction poll that only lived in local widget state — votes
/// vanished on refresh, nothing was ever persisted or shown to anyone. None
/// of it was real, so it's gone rather than reskinned. This page lists the
/// two real channels the maintainer gave: email and the Facebook page —
/// both actually open on tap.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const String _email = 'hseng2018@gmail.com';
  static const String _facebookUrl =
      'https://www.facebook.com/taidevIT/?locale=th_TH';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= AppBreakpoints.desktop;
            final isTablet = constraints.maxWidth >= AppBreakpoints.tablet;
            final titleSize = isDesktop ? 40.0 : (isTablet ? 32.0 : 26.0);
            final topGap = isDesktop ? 120.0 : (isTablet ? 90.0 : 64.0);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    topGap,
                    AppSpacing.lg,
                    AppSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ติดต่อเรา',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: scheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Get in touch',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'มีคำถาม ข้อเสนอแนะ หรืออยากรายงานปัญหา ทักมาได้เลยครับ',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: scheme.onSurface.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _ContactChannel(
                        icon: FontAwesomeIcons.envelope,
                        label: 'Email',
                        value: _email,
                        uri: Uri(scheme: 'mailto', path: _email),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ContactChannel(
                        icon: FontAwesomeIcons.facebook,
                        label: 'Facebook',
                        value: 'facebook.com/taidevIT',
                        uri: Uri.parse(_facebookUrl),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ContactChannel extends StatelessWidget {
  const _ContactChannel({
    required this.icon,
    required this.label,
    required this.value,
    required this.uri,
  });

  final IconData icon;
  final String label;
  final String value;
  final Uri uri;

  // No mail client / Facebook app registered to handle the link (e.g. a
  // bare browser profile, or the target blocked as a popup) shouldn't leave
  // the tap looking like it did nothing — fall back to copying the address
  // so the user still walks away with something useful.
  Future<void> _handleTap(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Copied "$value" to clipboard')));
    } catch (_) {
      // Clipboard access can be denied (e.g. no document focus / missing
      // permission) — nothing more we can usefully do here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HoverScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 24, color: scheme.onSurface),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                FaIcon(
                  FontAwesomeIcons.arrowUpRightFromSquare,
                  size: 18,
                  color: scheme.onSurface.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
