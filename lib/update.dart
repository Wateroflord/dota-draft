import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'platform.dart';

/// Номер сборки (передаётся при сборке: --dart-define=BUILD=N).
const buildNumber = int.fromEnvironment('BUILD', defaultValue: 0);

class UpdateInfo {
  final int build;
  final String url; // файл для этой платформы
  const UpdateInfo(this.build, this.url);
}

/// Есть ли версия новее на GitHub. null — нет или не удалось проверить.
Future<UpdateInfo?> checkUpdate() async {
  if (buildNumber == 0) return null;
  try {
    final r = await http
        .get(Uri.parse('https://api.github.com/repos/Wateroflord/dota-draft/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final tag = '${j['tag_name'] ?? ''}';
    final n = int.tryParse(tag.replaceFirst('build-', '')) ?? 0;
    if (n <= buildNumber) return null;
    final want = isWindows ? 'Windows.zip' : '.apk';
    for (final a in (j['assets'] as List? ?? const [])) {
      final name = '${a['name']}';
      if (name.endsWith(want)) return UpdateInfo(n, '${a['browser_download_url']}');
    }
    return null;
  } catch (_) {
    return null;
  }
}

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}
