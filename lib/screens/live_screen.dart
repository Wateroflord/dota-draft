import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../advice.dart';
import '../coach.dart';
import '../gsi.dart';
import '../i18n.dart';
import '../platform.dart';
import '../state.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';
import 'live_coach.dart';
import 'timer_screen.dart' show mmss;

/// Отметки Рошана/Торментора для живого режима (общие для экрана и оверлея).
class LiveMarks extends ChangeNotifier {
  int? roshanAt; // игровое время убийства Рошана
  int? tormentorAt;

  void roshan(int clock) {
    roshanAt = clock;
    notifyListeners();
  }

  void tormentor(int clock) {
    tormentorAt = clock;
    notifyListeners();
  }

  void reset() {
    roshanAt = null;
    tormentorAt = null;
    notifyListeners();
  }
}

final liveMarks = LiveMarks();

/// Экран «Живой матч»: данные из Dota 2 в реальном времени.
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Живой матч', 'Live match'), style: T.h2),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(14, 0, 14, 32),
        child: LivePanel(),
      ),
    );
  }
}

/// Содержимое живого режима. [compact] — для оверлея на Windows.
class LivePanel extends StatefulWidget {
  final bool compact;
  const LivePanel({super.key, this.compact = false});

  @override
  State<LivePanel> createState() => _LivePanelState();
}

class _LivePanelState extends State<LivePanel> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gsi, liveMarks, coach]),
      builder: (context, _) {
        final g = gsi.last;
        if (!gsi.live || g == null) {
          return widget.compact ? _waitingCompact() : const GsiSetup();
        }
        return _live(context, g);
      },
    );
  }

  Widget _waitingCompact() => AppCard(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              gsi.running
                  ? L('Жду данные из Dota 2…', 'Waiting for Dota 2…')
                  : L('Связь с Dota выключена — включи на экране «Живой матч»', 'Dota link is off — enable it on the Live match page'),
              style: T.small,
            ),
          ),
        ]),
      );

  Widget _live(BuildContext context, GsiState g) {
    final s = StateScope.of(context);
    final tools = ToolsScope.of(context);
    final d = s.data!;
    final hero = d.byId[g.heroId] ?? d.heroes.where((h) => h.key == g.heroName).firstOrNull;
    final clock = g.clock ?? 0;
    final c = widget.compact;
    // В оверлее блоки можно прятать в настройках.
    bool show(String block) => !c || !tools.overlayHidden.contains(block);

    // Ближайшие события.
    final upcoming = <(String, int)>[];
    for (final e in tools.timerEvents.where((e) => e.enabled)) {
      final n = e.nextAt(clock);
      if (n != null) upcoming.add((e.title, n));
    }
    if (liveMarks.roshanAt != null) {
      final r = liveMarks.roshanAt!;
      if (r + 300 >= clock) upcoming.add((L('Аегис пропадает', 'Aegis expires'), r + 300));
      if (r + 480 >= clock) upcoming.add((L('Рошан может возродиться', 'Roshan may respawn'), r + 480));
      if (r + 660 >= clock) upcoming.add((L('Рошан точно возродился', 'Roshan has respawned'), r + 660));
    }
    if (liveMarks.tormentorAt != null && liveMarks.tormentorAt! + 600 >= clock) {
      upcoming.add((L('Торментор возродится', 'Tormentor respawns'), liveMarks.tormentorAt! + 600));
    }
    upcoming.sort((a, b) => a.$2.compareTo(b.$2));

    final advice = hero == null
        ? <ItemAdvice>[]
        : nextItems(
            data: d,
            hero: hero,
            enemies: s.enemyHeroes,
            owned: g.items.toSet(),
            gold: g.gold,
            clock: clock,
          );

    // Добивания против среднего игрока твоего ранга на этом герое.
    final ref = hero == null ? null : s.bench.row(hero.id, s.myRankGroup);
    final expLh = ref == null || clock <= 0 ? null : ref.lh10 * clock / 600;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppCard(
        padding: EdgeInsets.all(c ? 8 : 12),
        child: Row(children: [
          if (hero != null) ...[HeroImg(hero, width: c ? 52 : 72), const SizedBox(width: 10)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${hero?.name ?? g.heroName} · ${L('ур.', 'lvl')} ${g.level}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.body.copyWith(fontWeight: FontWeight.w700, fontSize: c ? 13 : 14),
              ),
              Text(
                g.alive
                    ? '${g.kills}/${g.deaths}/${g.assists} · ${g.lastHits}/${g.denies} · ${g.gpm} GPM'
                    : L('Мёртв: ${g.respawn} с · выкуп ${g.buybackCost}', 'Dead: ${g.respawn}s · buyback ${g.buybackCost}'),
                style: T.small.copyWith(color: g.alive ? C.muted : C.enemy, fontSize: c ? 11 : 12),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(mmss(clock), style: T.num(c ? 18 : 24)),
            Text('${g.gold} 🪙', style: T.num(c ? 12 : 14, color: C.gold)),
          ]),
        ]),
      ),
      if (expLh != null && clock > 120) ...[
        const SizedBox(height: 6),
        Text(
          g.lastHits >= expLh
              ? L('Добивания: +${(g.lastHits - expLh).round()} к среднему игроку твоего ранга', 'Last hits: +${(g.lastHits - expLh).round()} vs an average player of your rank')
              : L('Добивания: −${(expLh - g.lastHits).round()} от среднего игрока твоего ранга', 'Last hits: −${(expLh - g.lastHits).round()} vs an average player of your rank'),
          style: T.small.copyWith(color: g.lastHits >= expLh ? C.ally : C.enemy, fontSize: c ? 11 : 12),
        ),
      ],
      if (show('alerts')) CoachAlertsCard(compact: c),
      if (hero != null && clock < 240 && show('hero')) LiveHeroCard(hero: hero, compact: c),
      if (show('farm') && (s.myPos <= 3)) LiveFarmCard(g: g, compact: c),
      if (advice.isNotEmpty && show('items')) ...[
        SectionLabel(L('Что купить дальше', 'What to buy next')),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            for (final a in advice)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  ItemImg(a.item.key, width: c ? 34 : 42),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.item.name, style: T.body.copyWith(fontSize: c ? 12 : 13.5, fontWeight: FontWeight.w600)),
                      Text(a.reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small.copyWith(fontSize: c ? 10.5 : 11.5)),
                    ]),
                  ),
                  Text(a.need == 0 ? L('хватает', 'can buy') : '−${a.need}',
                      style: T.num(c ? 11.5 : 13, color: a.need == 0 ? C.ally : C.muted)),
                ]),
              ),
          ]),
        ),
      ],
      if (show('gpm')) LiveGpmCard(hero: hero, compact: c),
      if (show('deaths')) DeathLogCard(compact: c),
      if (show('events')) ...[
      SectionLabel(L('Ближайшие события', 'Upcoming events')),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(children: [
          for (final u in upcoming.take(c ? 4 : 6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(u.$1, style: T.body.copyWith(fontSize: c ? 12 : 13.5))),
                Text(mmss(u.$2 - clock), style: T.num(c ? 12 : 13.5, color: u.$2 - clock <= 30 ? C.gold : C.text)),
              ]),
            ),
        ]),
      ),
      ],
      if (show('buttons')) ...[
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
            onPressed: () => liveMarks.roshan(clock),
            child: Text(L('Рошан убит', 'Roshan killed'), style: TextStyle(fontSize: c ? 12 : 14)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: BorderSide(color: C.border)),
            onPressed: () => liveMarks.tormentor(clock),
            child: Text(L('Торментор убит', 'Tormentor killed'), style: TextStyle(fontSize: c ? 12 : 14)),
          ),
        ),
      ]),
      ],
      if (!c) ...[
        const SizedBox(height: 10),
        Text(
          L('Данные идут из Dota 2 в реальном времени. Таймеры на экране «Таймеры матча» тоже идут сами.',
              'Data comes from Dota 2 in real time. The Match timers page syncs automatically too.'),
          style: T.small,
        ),
      ],
    ]);
  }
}

/// Инструкция по подключению Dota 2 (Game State Integration).
class GsiSetup extends StatefulWidget {
  const GsiSetup({super.key});

  @override
  State<GsiSetup> createState() => _GsiSetupState();
}

class _GsiSetupState extends State<GsiSetup> {
  List<String> ips = const [];
  String? installed;

  @override
  void initState() {
    super.initState();
    GsiService.addresses().then((v) {
      if (mounted) setState(() => ips = v);
    });
  }

  Future<void> _toggle(bool on) async {
    final tools = ToolsScope.read(context);
    tools.setGsi(on);
    if (on) {
      await gsi.start(onPort: tools.gsiPort);
    } else {
      await gsi.stop();
    }
    if (mounted) setState(() {});
  }

  Future<void> _autoInstall() async {
    try {
      final p = await gsi.installCfgOnWindows();
      if (mounted) setState(() => installed = p);
    } catch (e) {
      if (mounted) showToast(context, '$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tools = ToolsScope.of(context);
    final host = isWindows ? '127.0.0.1' : (ips.isEmpty ? 'IP_ТЕЛЕФОНА' : ips.first);
    final cfg = gsi.cfgText(host);
    Widget step(String n, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: C.accent, shape: BoxShape.circle),
              child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: T.body.copyWith(fontSize: 13.5))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(L('Связь с Dota 2', 'Link with Dota 2'), style: T.body.copyWith(fontWeight: FontWeight.w700)),
              Text(
                !tools.gsiOn
                    ? L('выключено', 'off')
                    : gsi.error != null
                        ? L('ошибка: ${gsi.error}', 'error: ${gsi.error}')
                        : L('жду данные на порту ${gsi.port}…', 'waiting on port ${gsi.port}…'),
                style: T.small,
              ),
            ]),
          ),
          Switch(value: tools.gsiOn, activeTrackColor: C.accent, onChanged: _toggle),
        ]),
      ),
      const SizedBox(height: 8),
      Text(
        L('Dota 2 умеет сама отправлять данные матча (время, золото, предметы) — это официальная функция Valve '
            '(Game State Integration), за неё не банят. Настраивается один раз:',
            'Dota 2 can send match data (time, gold, items) by itself — it is an official Valve feature '
            '(Game State Integration), safe to use. One-time setup:'),
        style: T.small,
      ),
      const SizedBox(height: 6),
      step('1', L('Steam → Библиотека → Dota 2 → Свойства → Параметры запуска: допиши  -gamestateintegration',
          'Steam → Library → Dota 2 → Properties → Launch options: add  -gamestateintegration')),
      if (isWindows) ...[
        step('2', L('Нажми кнопку ниже — приложение само создаст файл настройки в папке Dota 2.',
            'Tap the button below — the app will create the config file in the Dota 2 folder.')),
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: 6),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.accent),
            onPressed: _autoInstall,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text(L('Настроить автоматически', 'Set up automatically')),
          ),
        ),
        if (installed != null)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 6),
            child: Text(L('Готово: $installed', 'Done: $installed'), style: T.small.copyWith(color: C.ally)),
          ),
      ] else
        step(
            '2',
            L('На ПК создай файл\n…\\steamapps\\common\\dota 2 beta\\game\\dota\\cfg\\gamestate_integration\\${GsiService.cfgFileName}\n'
                'и вставь в него текст ниже (кнопка «Копировать»). Перешли себе текст, например, в Telegram.',
                'On the PC create the file\n…\\steamapps\\common\\dota 2 beta\\game\\dota\\cfg\\gamestate_integration\\${GsiService.cfgFileName}\n'
                'and paste the text below (Copy button). Send the text to yourself, e.g. via Telegram.')),
      if (!isWindows) ...[
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: SelectableText(cfg, style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: C.text))),
            IconButton(
              icon: const Icon(Icons.copy, color: C.accent),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cfg));
                showToast(context, L('Скопировано', 'Copied'));
              },
            ),
          ]),
        ),
        const SizedBox(height: 4),
        if (ips.length > 1)
          Text(L('Адреса телефона: ${ips.join(', ')} — если первый не подойдёт, попробуй другой.',
              'Phone addresses: ${ips.join(', ')} — if the first does not work, try another.'), style: T.small),
        step('3', L('Телефон и ПК должны быть в одной сети Wi-Fi, а этот экран — открыт во время игры.',
            'The phone and PC must be on the same Wi-Fi, and this page open during the game.')),
      ] else
        step('3', L('Перезапусти Dota 2. Во время матча данные появятся здесь и в оверлее.',
            'Restart Dota 2. During a match the data will appear here and in the overlay.')),
      step('4', L('Включи переключатель «Связь с Dota 2» выше.', 'Turn on the "Link with Dota 2" switch above.')),
    ]);
  }
}
