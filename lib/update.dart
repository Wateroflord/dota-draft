import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'platform.dart';

/// Номер сборки (передаётся при сборке: --dart-define=BUILD=N).
const buildNumber = int.fromEnvironment('BUILD', defaultValue: 0);

class UpdateInfo {
  final int build;
  final String url; // файл для этой платформы
  final String? setup; // установщик Windows (для автообновления)
  const UpdateInfo(this.build, this.url, [this.setup]);
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
    String? url, setup;
    for (final a in (j['assets'] as List? ?? const [])) {
      final name = '${a['name']}';
      if (name.endsWith(want)) url = '${a['browser_download_url']}';
      if (name.endsWith('Setup.exe')) setup = '${a['browser_download_url']}';
    }
    if (isWindows && setup != null) return UpdateInfo(n, url ?? setup, setup);
    return url == null ? null : UpdateInfo(n, url);
  } catch (_) {
    return null;
  }
}

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Установить обновление. На Windows — скачать установщик и запустить тихо (приложение перезапустится само).
/// Возвращает текст ошибки или null.
Future<String?> installUpdate(UpdateInfo u, {void Function(double)? progress}) async {
  if (!isWindows || u.setup == null) {
    await openUrl(u.url);
    return null;
  }
  try {
    final req = http.Request('GET', Uri.parse(u.setup!));
    final res = await http.Client().send(req);
    if (res.statusCode != 200) return 'HTTP ${res.statusCode}';
    final f = File('${Directory.systemTemp.path}\\Dota-Draft-Setup-${u.build}.exe');
    final sink = f.openWrite();
    final total = res.contentLength ?? 0;
    var got = 0;
    await for (final chunk in res.stream) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) progress?.call(got / total);
    }
    await sink.close();
    await Process.start(f.path, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'], mode: ProcessStartMode.detached);
    exit(0);
  } catch (e) {
    return '$e';
  }
}
