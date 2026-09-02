import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'donations.dart';
import 'l10n/app_localizations.dart';

/// One shipped release's "what's new" content, as AppLocalizations keys
/// (not raw strings) so entries come out translated. Add one entry per
/// release that has user-facing notes, in ascending version order — bump
/// [version] to match whatever you set in pubspec.yaml / the platform
/// version fields when you actually ship it. A release with no keys, or a
/// version nobody has updated into yet, never shows a popup.
const List<DevNoteRelease> kDevNoteReleases = [
  DevNoteRelease(
    version: '1.16.2',
    featureKeys: [
      'devNoteFeatureTimestamps',
      'devNoteFeatureStats',
      'devNoteFeatureCalendarSearchTop',
      'devNoteFeatureDonate',
    ],
    fixKeys: [
      'devNoteFixWeekStartOverflow',
      'devNoteFixScrollJump',
      'devNoteFixBeepsPauseMusic',
    ],
  ),
];

class DevNoteRelease {
  final String version;
  final List<String> featureKeys;
  final List<String> fixKeys;

  const DevNoteRelease({
    required this.version,
    this.featureKeys = const [],
    this.fixKeys = const [],
  });

  bool get hasNotes => featureKeys.isNotEmpty || fixKeys.isNotEmpty;
}

const String _lastSeenVersionPrefsKey = 'last_seen_app_version';

/// Compares dotted version strings numerically (so "1.9.0" < "1.10.0",
/// unlike a plain string compare). Missing trailing parts count as 0.
int compareAppVersions(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

/// Shows the "What's New" dialog if, and only if, the app has actually been
/// updated since it last ran (a real prior version is on record and this
/// build's version is newer) and at least one release in between has real
/// feature/fix notes. Records the current version as seen either way, so a
/// fresh install never shows a popup and nothing shows twice for the same
/// version.
Future<void> maybeShowDevNotesDialog(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

  final prefs = await SharedPreferences.getInstance();
  final lastSeen = prefs.getString(_lastSeenVersionPrefsKey);

  if (lastSeen == null) {
    // First launch ever: nothing to compare against, so nothing "updated".
    await prefs.setString(_lastSeenVersionPrefsKey, currentVersion);
    return;
  }

  if (compareAppVersions(currentVersion, lastSeen) <= 0) {
    return;
  }

  final releases =
      kDevNoteReleases.where((r) {
        if (!r.hasNotes) return false;
        return compareAppVersions(r.version, lastSeen) > 0 &&
            compareAppVersions(r.version, currentVersion) <= 0;
      }).toList()
        ..sort((a, b) => compareAppVersions(a.version, b.version));

  await prefs.setString(_lastSeenVersionPrefsKey, currentVersion);

  if (releases.isEmpty || !context.mounted) return;

  final featureKeys = <String>[];
  final fixKeys = <String>[];
  for (final release in releases) {
    featureKeys.addAll(release.featureKeys);
    fixKeys.addAll(release.fixKeys);
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => _DevNotesDialog(
      version: currentVersion,
      featureKeys: featureKeys,
      fixKeys: fixKeys,
    ),
  );
}

class _DevNotesDialog extends StatelessWidget {
  final String version;
  final List<String> featureKeys;
  final List<String> fixKeys;

  const _DevNotesDialog({
    required this.version,
    required this.featureKeys,
    required this.fixKeys,
  });

  Widget _buildSection(
    BuildContext context,
    AppLocalizations l10n,
    String titleKey,
    IconData icon,
    List<String> keys,
  ) {
    if (keys.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                l10n.get(titleKey),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.get(key),
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E2A3A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '${l10n.get('devNotesTitle')} — v$version',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              l10n,
              'devNotesNewFeatures',
              Icons.auto_awesome,
              featureKeys,
            ),
            _buildSection(
              context,
              l10n,
              'devNotesBugFixes',
              Icons.build_circle_outlined,
              fixKeys,
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        IconButton(
          tooltip: l10n.get('devNotesSupportTooltip'),
          icon: Icon(Icons.volunteer_activism, color: colorScheme.primary),
          onPressed: () => showDonationSheet(context),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close, style: const TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
