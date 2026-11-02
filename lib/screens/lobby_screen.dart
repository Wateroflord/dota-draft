import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data.dart';
import '../i18n.dart';
import '../lobby.dart';
import '../opendota.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Соперники в лобби и кого банить.
/// На ПК лобби читается из server_log.txt Dota сразу после загрузки матча; на телефоне — ID вручную.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final idsCtrl = TextEditingController();
  Lobby? lobby;
  String lobbyId = '';
  final Map<int, LobbyPlayer> players = {};
  bool loading = false;
  String? status;
  Timer? _poll;
  DateTime? _logTime;

  bool get _pc => Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_pc) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _readLog());
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _readLog(auto: true));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    idsCtrl.dispose();
    super.dispose();
  }

  Future<void> _readLog({bool auto = false}) async {
    final f = await LobbyReader.logFile();
    if (f == null) {
      if (!auto && mounted) setState(() => status = L('Папка Dota 2 не найдена', 'Dota 2 folder not found'));
      return;
    }
    if (!await f.exists()) {
      if (!auto && mounted) setState(() => status = L('Лог появится после первого матча', 'The log appears after your first match'));
      return;
    }
    final t = await f.lastModified();
    if (auto && _logTime != null && !t.isAfter(_logTime!)) return;
    _logTime = t;
    final l = await LobbyReader.read();
    if (!mounted) return;
    if (l == null) {
      setState(() => status = L('В логе пока нет лобби. Найди матч — данные появятся, как только он загрузится.',
          'No lobby in the log yet. Find a match — data appears as soon as it loads.'));
      return;
    }
    if (l.id == lobbyId && players.isNotEmpty) return;
    final age = DateTime.now().difference(t);
    setState(() {
      lobby = l;
      lobbyId = l.id;
      status = age.inMinutes > 90
          ? L('Это прошлый матч (${age.inHours} ч назад). Новый появится сам, когда загрузится игра.',
              'This is an older match (${age.inHours} h ago). A new one appears automatically when the game loads.')
          : null;
    });
    await _loadPlayers(l.slots.map((s) => s.accountId).toList());
  }

  Future<void> _manual() async {
    final ids = LobbyReader.parseIds(idsCtrl.text);
    if (ids.isEmpty) {
      showToast(context, L('Введи Friend ID соперников через запятую', 'Enter opponents’ Friend IDs separated by commas'));
      return;
    }
    FocusScope.of(context).unfocus();
    // Введённые вручную — соперники (слоты Тьмы).
    final l = Lobby('manual', '', [for (var i = 0; i < ids.length && i < 5; i++) LobbySlot(5 + i, ids[i], 0)]);
    setState(() {
      lobby = l;
      lobbyId = 'manual';
      status = null;
    });
    await _loadPlayers(l.slots.map((s) => s.accountId).toList());
  }

  Future<void> _loadPlayers(List<int> ids) async {
    setState(() {
      loading = true;
      players.clear();
    });
    // По два игрока за раз — OpenDota ограничивает частоту запросов.
    for (var i = 0; i < ids.length; i += 2) {
      final part = ids.skip(i).take(2).toList();
      final res = await Future.wait(part.map(LobbyPlayer.load));
      if (!mounted) return;
      setState(() {
        for (final p in res) {
          players[p.accountId] = p;
        }
      });
    }
    if (mounted) setState(() => loading = false);
  }

  /// Моя сторона: по моему профилю; если меня нет в лобби — Свет.
  bool _iAmRadiant(Lobby l, AppState s) {
    final me = l.slots.where((x) => x.accountId == s.accountId).firstOrNull;
    if (lobbyId == 'manual') return true;
    return me?.radiant ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final d = s.data;
    final l = lobby;
    final radiant = l == null ? true : _iAmRadiant(l, s);
    final enemySlots = l?.side(!radiant) ?? const <LobbySlot>[];
    final allySlots = l?.side(radiant) ?? const <LobbySlot>[];
    final enemies = [for (final x in enemySlots) if (players[x.accountId] != null) players[x.accountId]!];
    final taken = {...s.allies.whereType<int>(), ...s.enemies.whereType<int>()};
    final bans = banIdeas(enemies, skip: taken);
    final meFound = l != null && l.slots.any((x) => x.accountId == s.accountId);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Соперники и баны', 'Opponents & bans'), style: T.h2),
        actions: [
          if (_pc)
            IconButton(
              tooltip: L('Прочитать лобби', 'Read lobby'),
              icon: const Icon(Icons.refresh),
              onPressed: () {
                lobbyId = '';
                _readLog();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
        children: [
          Text(
            _pc
                ? L('Как только матч загрузится, приложение само прочитает из Dota, кто с тобой в игре, и покажет любимых героев соперников за 3 месяца — их стоит забанить. Держи экран открытым во время поиска.',
                    'As soon as the match loads, the app reads from Dota who is in the game and shows the opponents’ favourite heroes for the last 3 months — worth banning. Keep this screen open while searching.')
                : L('На телефоне впиши Friend ID соперников (видно в их профиле Dota). Автоматически лобби читается в версии для ПК.',
                    'On the phone, enter opponents’ Friend IDs (shown in their Dota profile). The PC version reads the lobby automatically.'),
            style: T.small,
          ),
          if (!_pc) ...[
            const SizedBox(height: 8),
            TextField(
              controller: idsCtrl,
              style: T.body,
              decoration: fieldDeco(L('ID соперников через запятую', 'Opponent IDs, comma separated'), icon: Icons.groups_outlined),
              onSubmitted: (_) => _manual(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: loading ? null : _manual,
              child: Text(L('Показать', 'Show')),
            ),
          ],
          if (status != null) ...[
            const SizedBox(height: 10),
            AppCard(child: Text(status!, style: T.small)),
          ],
          if (l != null && d != null) ...[
            if (_pc && !meFound && s.accountId != null) ...[
              const SizedBox(height: 8),
              Text(L('Тебя нет в этом лобби — считаю, что ты за Свет.', 'You are not in this lobby — assuming you are Radiant.'),
                  style: T.small.copyWith(color: C.gold)),
            ],
            if (_pc && s.accountId == null) ...[
              const SizedBox(height: 8),
              Text(L('Загрузи свой профиль Steam во вкладке «Мои герои», чтобы приложение знало твою команду.',
                  'Load your Steam profile on the My heroes tab so the app knows your team.'), style: T.small.copyWith(color: C.gold)),
            ],
            SectionLabel(L('Кого банить', 'Who to ban'), trailing: loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : null),
            if (bans.isEmpty)
              AppCard(
                child: Text(
                  loading
                      ? L('Загружаю игроков…', 'Loading players…')
                      : L('У соперников нет явных любимых героев (или профили скрыты).', 'Opponents have no clear favourite heroes (or profiles are hidden).'),
                  style: T.small,
                ),
              ),
            for (final b in bans)
              if (d.byId[b.heroId] != null) _banTile(s, d.byId[b.heroId]!, b),
            SectionLabel(lobbyId == 'manual' ? L('Соперники', 'Opponents') : L('Соперники · ${radiant ? 'Тьма' : 'Свет'}', 'Opponents · ${radiant ? 'Dire' : 'Radiant'}')),
            for (final x in enemySlots) _player(d, x, players[x.accountId], C.enemy),
            if (allySlots.isNotEmpty) ...[
              SectionLabel(L('Твоя команда · ${radiant ? 'Свет' : 'Тьма'}', 'Your team · ${radiant ? 'Radiant' : 'Dire'}')),
              for (final x in allySlots) _player(d, x, players[x.accountId], C.ally),
            ],
          ],
        ],
      ),
    );
  }

  Widget _banTile(AppState s, DHero h, BanIdea b) {
    final banned = s.bans.contains(h.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          HeroImg(h, width: 64),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.name, style: T.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                b.who.map((w) => L('${w.$1}: ${w.$2} игр, ${pct(w.$3 / w.$2, digits: 0)}', '${w.$1}: ${w.$2} games, ${pct(w.$3 / w.$2, digits: 0)}')).join(' · '),
                style: T.small,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Pill(banned ? L('В банах', 'Banned') : L('Бан', 'Ban'), color: C.enemy, filled: banned, onTap: () => s.toggleBan(h.id)),
        ]),
      ),
    );
  }

  Widget _player(StatsData d, LobbySlot x, LobbyPlayer? p, Color side) {
    final top = p?.top() ?? const <(int, int, int)>[];
    final partyColors = [C.gold, C.intel, C.uni, C.agi];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        borderColor: x.party > 0 ? partyColors[(x.party - 1) % partyColors.length].withValues(alpha: 0.6) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(color: side, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p == null ? '${x.accountId}' : (p.hidden ? L('Скрытый профиль', 'Hidden profile') : p.name),
                style: T.body.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (x.party > 0) ...[
              Pill(L('пати ${x.party}', 'party ${x.party}'), color: partyColors[(x.party - 1) % partyColors.length]),
              const SizedBox(width: 6),
            ],
            if (p != null && !p.hidden) Text(rankName(p.rankTier), style: T.small),
          ]),
          if (p != null && !p.hidden) ...[
            const SizedBox(height: 4),
            Text(
              p.games == 0
                  ? L('Нет игр за 3 месяца', 'No games in 3 months')
                  : L('${p.games} игр за 3 месяца · ${pct(p.wins / p.games, digits: 0)} побед', '${p.games} games in 3 months · ${pct(p.wins / p.games, digits: 0)} wins'),
              style: T.small.copyWith(color: p.games > 0 && p.games < 25 ? C.gold : null),
            ),
            if (p.games > 0 && p.games < 25 && p.wins / p.games > 0.6)
              Text(L('Мало игр и много побед — возможно, смурф', 'Few games and many wins — possibly a smurf'),
                  style: T.small.copyWith(color: C.gold)),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                for (final t in top)
                  if (d.byId[t.$1] != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(children: [
                          LayoutBuilder(builder: (_, c) => HeroImg(d.byId[t.$1]!, width: c.maxWidth)),
                          const SizedBox(height: 2),
                          Text('${t.$2} · ${pct(t.$3 / t.$2, digits: 0)}', style: T.small.copyWith(fontSize: 10.5)),
                        ]),
                      ),
                    ),
                for (var i = top.length; i < 4; i++) const Expanded(child: SizedBox()),
              ]),
            ],
          ],
        ]),
      ),
    );
  }
}
