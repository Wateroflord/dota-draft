// Проверки разбора лобби, банов и данных STRATZ. Запускаются на GitHub перед сборкой.

import 'package:dota_draft/lobby.dart';
import 'package:dota_draft/stratz.dart';
import 'package:flutter_test/flutter_test.dart';

const _log = '''
11/01/2026 - 20:10:01: 155.133.1.2:27015 (Lobby 27100000000000001 DOTA_GAMEMODE_ALL_DRAFT 0:[U:1:11] 1:[U:1:12] 2:[U:1:13] 3:[U:1:14] 4:[U:1:15] 5:[U:1:16] 6:[U:1:17] 7:[U:1:18] 8:[U:1:19] 9:[U:1:20])
11/02/2026 - 18:00:00: 155.133.1.3:27016 (Lobby 27100000000000002 DOTA_GAMEMODE_ALL_DRAFT 0:[U:1:101] 1:[U:1:102] 2:[U:1:103] 3:[U:1:104] 4:[U:1:105] 5:[U:1:106] 6:[U:1:107] 7:[U:1:108] 8:[U:1:109] 9:[U:1:110] 10:[U:1:999]) (Party 555 0:[U:1:101] 1:[U:1:102]) (Party 556 0:[U:1:108] 1:[U:1:109] 2:[U:1:110])
''';

void main() {
  group('Лобби из server_log', () {
    test('берётся последнее лобби', () {
      final l = LobbyReader.parse(_log)!;
      expect(l.id, '27100000000000002');
      expect(l.mode, 'DOTA_GAMEMODE_ALL_DRAFT');
      expect(l.slots.length, 10); // слот 10 (зритель/тренер) не считается
      expect(l.side(true).map((s) => s.accountId), [101, 102, 103, 104, 105]);
      expect(l.side(false).first.accountId, 106);
    });

    test('пати распознаются', () {
      final l = LobbyReader.parse(_log)!;
      final p = {for (final s in l.slots) s.accountId: s.party};
      expect(p[101], p[102]);
      expect(p[101], isNot(0));
      expect(p[108], p[110]);
      expect(p[108], isNot(p[101]));
      expect(p[103], 0);
    });

    test('без лобби — null', () {
      expect(LobbyReader.parse('nothing here'), isNull);
    });

    test('ID вручную: числа и ссылки', () {
      expect(LobbyReader.parseIds('123, 456 https://www.opendota.com/players/789'), [123, 456, 789]);
    });
  });

  group('Кого банить', () {
    test('сигнатурный герой с высоким винрейтом выше случайного', () {
      const a = LobbyPlayer(1, 'A', 50, false, {
        10: [40, 28],
        20: [3, 1],
      });
      const b = LobbyPlayer(2, 'B', 50, false, {
        30: [10, 4],
        10: [5, 4],
      });
      final ideas = banIdeas([a, b]);
      expect(ideas.first.heroId, 10);
      expect(ideas.first.who.length, 2);
      expect(ideas.any((i) => i.heroId == 20), isFalse); // 3 игры, 33% — не бан
    });

    test('уже выбранные герои не предлагаются', () {
      const a = LobbyPlayer(1, 'A', 50, false, {
        10: [40, 28],
      });
      expect(banIdeas([a], skip: {10}), isEmpty);
    });
  });

  group('STRATZ', () {
    test('линия: ничьи считаются половиной', () {
      final d = LaneData.parse({
        'updated': '2026-11-02',
        'vs': {
          '1': {'2': [100, 50, 30]}
        },
        'with': {},
      });
      expect(d.laneVs(1, 2), closeTo(0.6, 0.001));
      expect(d.laneVs(2, 1), isNull);
      expect(d.has(1), isTrue);
    });
  });
}
