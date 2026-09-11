import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pai_morn_web/widget/admin_artists_screen.dart';
import 'package:pai_morn_web/widget/admin_dashboard_screen.dart';
import 'package:pai_morn_web/widget/admin_screen.dart';
import 'package:pai_morn_web/widget/admin_song_issue_reports_screen.dart';
import 'package:pai_morn_web/widget/admin_song_requests_screen.dart';
import 'package:pai_morn_web/theme/app_theme.dart';

enum _AdminSection {
  dashboard,
  reviewQueue,
  songRequests,
  issueReports,
  artists,
}

/// Wraps the admin-only screens (Dashboard, the Review Queue) with a
/// persistent left-hand nav — unlike the account Drawer (which slides in
/// on demand for a handful of everyday items), admin work involves
/// switching between sections often enough that pinning the nav earns its
/// screen space. Only ever shown when `AuthProvider.isAdmin`, gated at the
/// routing level in home_page.dart same as the individual screens used to
/// be.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  _AdminSection _section = _AdminSection.dashboard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSidebar(context),
              Expanded(child: _buildContent()),
            ],
          );
        }
        return Column(
          children: [
            _buildNarrowNav(context),
            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: scheme.onSurface.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'ADMIN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: scheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _navItem(
            scheme,
            FontAwesomeIcons.gaugeHigh,
            'Dashboard',
            _AdminSection.dashboard,
          ),
          _navItem(
            scheme,
            FontAwesomeIcons.clipboardCheck,
            'Review Queue',
            _AdminSection.reviewQueue,
          ),
          _navItem(
            scheme,
            FontAwesomeIcons.envelope,
            'Song Requests',
            _AdminSection.songRequests,
          ),
          _navItem(
            scheme,
            FontAwesomeIcons.triangleExclamation,
            'Issue Reports',
            _AdminSection.issueReports,
          ),
          _navItem(
            scheme,
            FontAwesomeIcons.recordVinyl,
            'Artists',
            _AdminSection.artists,
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowNav(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.onSurface.withOpacity(0.1)),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _narrowNavButton(
                scheme,
                'Dashboard',
                _AdminSection.dashboard,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _narrowNavButton(
                scheme,
                'Review Queue',
                _AdminSection.reviewQueue,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _narrowNavButton(
                scheme,
                'Requests',
                _AdminSection.songRequests,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _narrowNavButton(
                scheme,
                'Issues',
                _AdminSection.issueReports,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _narrowNavButton(
                scheme,
                'Artists',
                _AdminSection.artists,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _narrowNavButton(
    ColorScheme scheme,
    String label,
    _AdminSection section,
  ) {
    final selected = _section == section;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? scheme.onSurface : Colors.transparent,
        foregroundColor: selected ? scheme.surface : scheme.onSurface,
        side: BorderSide(color: scheme.onSurface.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: () => setState(() => _section = section),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _navItem(
    ColorScheme scheme,
    IconData icon,
    String label,
    _AdminSection section,
  ) {
    final selected = _section == section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color:
            selected ? scheme.onSurface.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _section = section),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      selected
                          ? scheme.onSurface
                          : scheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color:
                        selected
                            ? scheme.onSurface
                            : scheme.onSurface.withOpacity(0.7),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_section) {
      case _AdminSection.dashboard:
        return const AdminDashboardScreen();
      case _AdminSection.reviewQueue:
        return const AdminScreen();
      case _AdminSection.songRequests:
        return const AdminSongRequestsScreen();
      case _AdminSection.issueReports:
        return const AdminSongIssueReportsScreen();
      case _AdminSection.artists:
        return const AdminArtistsScreen();
    }
  }
}
