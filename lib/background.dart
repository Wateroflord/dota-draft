import 'i18n.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

const _raw = 'https://raw.githubusercontent.com/Wateroflord/dota-draft/main/data/';
const taskName = 'dota-draft-check';

final _notifications = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  try {
    await _notifications.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
  } catch (_) {}
}

Future<bool> requestNotificationPermission() async {
  try {
    final a = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await a?.requestNotificationsPermission() ?? true;
  } catch (_) {
    return false;
  }
}

Future<void> notify(int id, String title, String body) async {
  try {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails('meta', L('Мета и патчи', 'Meta and patches'), importance: Importance.defaultImportance),
      ),
    );
  } catch (_) {}
}

/// Включить или выключить фоновую проверку (раз в ~12 часов).
Future<void> scheduleBackground(bool on) async {
  try {
    if (on) {
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: const Duration(hours: 12),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } else {
      await Workmanager().cancelByUniqueName(taskName);
    }
  } catch (_) {}
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await initNotifications();
      await backgroundCheck();
    } catch (_) {}
    return true;
  });
}

Future<Map<String, dynamic>> _readJson(String name) async {
  try {
    final d = await getApplicationDocumentsDirectory();
    final f = File('${d.path}/$name');
    if (await f.exists()) return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
  } catch (_) {}
  return {};
}

Future<void> _writeJson(String name, Map<String, dynamic> j) async {
  try {
    final d = await getApplicationDocumentsDirectory();
    await File('${d.path}/$name').writeAsString(jsonEncode(j));
  } catch (_) {}
}

Future<dynamic> _get(String url) async {
  final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
  if (r.statusCode != 200) return null;
  return jsonDecode(utf8.decode(r.bodyBytes));
}

String _tier(double score, List<double> sorted) {
  final rank = sorted.indexOf(score) / sorted.length;
  if (rank < 0.08) return 'S';
  if (rank < 0.25) return 'A';
  if (rank < 0.55) return 'B';
  if (rank < 0.8) return 'C';
  return 'D';
}

/// Проверка в фоне: новый патч, изменения тира «моих героев», обновление виджета.
Future<void> backgroundCheck() async {
  final prefs = await _readJson('draft_state.json');
  final en = prefs['lang'] == 'en';
  String l(String ru, String e) => en ? e : ru;
  final notifyOn = prefs['notify'] == true;
  final state = await _readJson('notify_state.json');
  final pool = ((prefs['pool'] as List?) ?? const []).whereType<num>().map((e) => e.toInt()).toSet();
  final group = ((prefs['group'] as num?)?.toInt() ?? 0).clamp(0, 4);

  // 1) Мета: тиры героев.
  final draft = await _get('${_raw}draft.json');
  final names = <int, String>{};
  final tiers = <String, String>{};
  final top = <String>[];
  if (draft is Map && draft['heroes'] is List) {
    final hs = (draft['heroes'] as List).whereType<Map>().toList();
    double at(Map h, String k) {
      final l = (h[k] as List?) ?? const [];
      return l.isEmpty ? 0.5 : ((group < l.length ? l[group] : l[0]) as num).toDouble();
    }

    final scores = <int, double>{};
    for (final h in hs) {
      final id = (h['id'] as num).toInt();
      names[id] = h['n']?.toString() ?? '#$id';
      scores[id] = (at(h, 'wr') - 0.5) * 100 + 1.2 * math.log(1 + at(h, 'pr') * 100);
    }
    final sorted = scores.values.toList()..sort((a, b) => b.compareTo(a));
    scores.forEach((id, sc) => tiers['$id'] = _tier(sc, sorted));
    final best = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    top.addAll(best.take(3).map((e) => names[e.key]!));

    final old = (state['tiers'] as Map?) ?? const {};
    if (notifyOn && old.isNotEmpty) {
      const order = 'SABCD';
      final ups = <String>[], downs = <String>[];
      for (final id in pool) {
        final a = old['$id']?.toString(), b = tiers['$id'];
        if (a == null || b == null || a == b) continue;
        (order.indexOf(b) < order.indexOf(a) ? ups : downs).add('${names[id]} $a→$b');
      }
      if (ups.isNotEmpty || downs.isNotEmpty) {
        await notify(
          1,
          l('Твои герои в мете', 'Your heroes in the meta'),
          [
            if (ups.isNotEmpty) l('Сильнее: ${ups.join(', ')}', 'Stronger: ${ups.join(', ')}'),
            if (downs.isNotEmpty) l('Слабее: ${downs.join(', ')}', 'Weaker: ${downs.join(', ')}'),
          ].join(' · '),
        );
      }
    }
    state['tiers'] = tiers;
  }

  // 2) Новый патч.
  final patch = await _get('${_raw}patch.json');
  if (patch is Map && patch['patches'] is List && (patch['patches'] as List).isNotEmpty) {
    final p = (patch['patches'] as List).first as Map;
    final ver = p['version']?.toString() ?? '';
    final old = state['patch']?.toString();
    if (notifyOn && old != null && old != ver) {
      final changed = ((p['heroes'] as Map?) ?? const {}).keys.map((k) => int.tryParse('$k')).whereType<int>().toSet();
      final mine = pool.where(changed.contains).map((id) => names[id] ?? '#$id').toList();
      await notify(
        2,
        l('Вышел патч $ver', 'Patch $ver is out'),
        mine.isEmpty
            ? l('Открой «Мета → Патч», чтобы посмотреть изменения.', 'Open Meta → Patch to see the changes.')
            : l('Изменены твои герои: ${mine.join(', ')}', 'Your heroes changed: ${mine.join(', ')}'),
      );
    }
    state['patch'] = ver;
  }

  // 3) Виджет: винрейт за неделю и топ меты.
  final acc = (prefs['accountId'] as num?)?.toInt();
  final line1 = l('Топ меты: ${top.join(', ')}', 'Top meta: ${top.join(', ')}');
  var line2 = '';
  if (acc != null) {
    try {
      final wl = await _get('https://api.opendota.com/api/players/$acc/wl?date=7');
      if (wl is Map) {
        final w = (wl['win'] as num?)?.toInt() ?? 0, lo = (wl['lose'] as num?)?.toInt() ?? 0;
        line2 = w + lo == 0
            ? l('За неделю игр нет', 'No games this week')
            : l('Неделя: ${w + lo} игр, винрейт ${(w / (w + lo) * 100).round()}%',
                'Week: ${w + lo} games, win rate ${(w / (w + lo) * 100).round()}%');
      }
    } catch (_) {}
  }
  await updateWidget(line1, line2);
  await _writeJson('notify_state.json', state);
}

Future<void> updateWidget(String line1, String line2) async {
  try {
    await HomeWidget.saveWidgetData<String>('title', 'Dota Draft');
    await HomeWidget.saveWidgetData<String>('line1', line1);
    await HomeWidget.saveWidgetData<String>('line2', line2);
    await HomeWidget.updateWidget(androidName: 'DotaWidgetProvider');
  } catch (_) {}
}
