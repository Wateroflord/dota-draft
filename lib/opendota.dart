import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class OdException implements Exception {
  final String message;
  OdException(this.message);
  @override
  String toString() => message;
}

class PlayerProfile {
  final int accountId;
  final String name;
  final String avatar;
  final int? rankTier;
  const PlayerProfile(this.accountId, this.name, this.avatar, this.rankTier);
}

class RecentMatch {
  final int matchId;
  final int heroId;
  final bool radiant;
  final bool win;
  final int kills, deaths, assists;
  final int duration;
  final int startTime;
  const RecentMatch(this.matchId, this.heroId, this.radiant, this.win, this.kills, this.deaths, this.assists,
      this.duration, this.startTime);
}

class MatchInfo {
  final int matchId;
  final bool radiantWin;
  final List<int> radiant;
  final List<int> dire;
  final int duration;
  const MatchInfo(this.matchId, this.radiantWin, this.radiant, this.dire, this.duration);
}

/// Данные игрока с OpenDota (бесплатно, без ключа). Профиль Dota 2 должен открывать данные матчей.
class OpenDota {
  static const _base = 'https://api.opendota.com/api';
  static const _steam64 = 76561197960265728;

  /// Из ссылки или числа достаёт account_id (Friend ID). null — не получилось.
  static int? parseAccountId(String input) {
    final t = input.trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'(?:profiles|players|matches/player)/(\d+)').firstMatch(t);
    final digits = m?.group(1) ?? (RegExp(r'^\d+$').hasMatch(t) ? t : null);
    if (digits == null) return null;
    final v = int.tryParse(digits);
    if (v == null || v <= 0) return null;
    return v >= _steam64 ? v - _steam64 : v;
  }

  static Future<dynamic> _get(String path) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse('$_base$path')).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw OdException('OpenDota не ответил. Попробуй ещё раз.');
    } catch (_) {
      throw OdException('Нет соединения с интернетом.');
    }
    if (res.statusCode == 429) throw OdException('Слишком много запросов к OpenDota. Подожди минуту.');
    if (res.statusCode == 404) throw OdException('Не найдено.');
    if (res.statusCode != 200) throw OdException('Ошибка OpenDota (${res.statusCode}).');
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  static Future<PlayerProfile> profile(int id) async {
    final j = await _get('/players/$id');
    final p = j is Map ? j['profile'] : null;
    if (p is! Map) {
      throw OdException('Профиль не найден или скрыт. В Dota 2: Настройки → Общение → «Открыть общий доступ к данным матчей».');
    }
    return PlayerProfile(
      id,
      p['personaname']?.toString() ?? 'Игрок $id',
      p['avatarmedium']?.toString() ?? '',
      j['rank_tier'] is num ? (j['rank_tier'] as num).toInt() : null,
    );
  }

  /// hero_id -> [игр, побед]
  static Future<Map<int, List<int>>> heroes(int id) async {
    final j = await _get('/players/$id/heroes');
    final out = <int, List<int>>{};
    if (j is List) {
      for (final r in j.whereType<Map>()) {
        final hid = _i(r['hero_id']);
        final g = _i(r['games']);
        if (hid > 0 && g > 0) out[hid] = [g, _i(r['win'])];
      }
    }
    return out;
  }

  static Future<List<RecentMatch>> recent(int id) async {
    final j = await _get('/players/$id/recentMatches');
    final out = <RecentMatch>[];
    if (j is List) {
      for (final r in j.whereType<Map>()) {
        final slot = _i(r['player_slot']);
        final radiant = slot < 128;
        final rw = r['radiant_win'] == true;
        out.add(RecentMatch(_i(r['match_id']), _i(r['hero_id']), radiant, radiant == rw, _i(r['kills']),
            _i(r['deaths']), _i(r['assists']), _i(r['duration']), _i(r['start_time'])));
      }
    }
    return out;
  }

  static Future<MatchInfo> match(int matchId) async {
    final j = await _get('/matches/$matchId');
    if (j is! Map || j['players'] is! List) throw OdException('Матч не найден.');
    final r = <int>[], d = <int>[];
    for (final p in (j['players'] as List).whereType<Map>()) {
      final hid = _i(p['hero_id']);
      final isRad = p['isRadiant'] is bool ? p['isRadiant'] as bool : _i(p['player_slot']) < 128;
      (isRad ? r : d).add(hid);
    }
    return MatchInfo(matchId, j['radiant_win'] == true, r, d, _i(j['duration']));
  }
}

/// Название ранга по rank_tier (например, 54 → Легенда 4).
String rankName(int? tier) {
  if (tier == null || tier <= 0) return 'ранг скрыт';
  const names = ['', 'Рекрут', 'Страж', 'Рыцарь', 'Герой', 'Легенда', 'Властелин', 'Божество', 'Титан'];
  final t = tier ~/ 10, s = tier % 10;
  if (t < 1 || t > 8) return 'ранг скрыт';
  return t == 8 || s == 0 ? names[t] : '${names[t]} $s';
}
