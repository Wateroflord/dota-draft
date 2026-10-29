import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data.dart';
import '../i18n.dart';
import '../info.dart';
import '../state.dart';
import '../theme.dart';
import '../tools_state.dart';
import '../widgets.dart';
import 'hero_picker.dart';
import 'timer_screen.dart' show mmss;

class _Cd {
  final String label;
  final DateTime readyAt;
  const _Cd(this.label, this.readyAt);
}

/// Перезарядка ультов и байбэков врагов: нажал «использовал» — пошёл отсчёт, голос скажет, когда готово.
class CooldownsScreen extends StatefulWidget {
  final bool embedded; // внутри оверлея: без заголовка
  const CooldownsScreen({super.key, this.embedded = false});

  @override
  State<CooldownsScreen> createState() => _CooldownsScreenState();
}

class _CooldownsScreenState extends State<CooldownsScreen> {
  final FlutterTts tts = FlutterTts();
  Timer? ticker;
  final List<int> heroes = [];
  final Map<int, int> ultLevel = {};
  final Map<int, bool> octarine = {};
  final Map<String, _Cd> running = {}; // ключ: "<id>:ult" / "<id>:bb"
  int buyback = 480;

  @override
  void initState() {
    super.initState();
    tts.setLanguage(isEn ? 'en-US' : 'ru-RU');
    tts.setSpeechRate(0.55);
    ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = StateScope.read(context);
      setState(() => heroes.addAll(s.enemies.whereType<int>()));
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    tts.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final done = running.entries.where((e) => !now.isBefore(e.value.readyAt)).toList();
    for (final e in done) {
      running.remove(e.key);
      HapticFeedback.heavyImpact();
      if (ToolsScope.read(context).voice) tts.speak(e.value.label);
    }
    setState(() {});
  }

  void _start(String key, int seconds, String doneLabel) {
    setState(() => running[key] = _Cd(doneLabel, DateTime.now().add(Duration(seconds: seconds))));
  }

  Future<void> _add() async {
    final id = await pickHero(context, title: L('Добавить героя', 'Add hero'), disabled: heroes.toSet());
    if (id != null) setState(() => heroes.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: C.bg,
              surfaceTintColor: Colors.transparent,
              title: Text(L('Ульты и байбэки врагов', 'Enemy ults & buybacks'), style: T.h2),
              actions: [IconButton(onPressed: _add, icon: const Icon(Icons.person_add_alt))],
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          if (widget.embedded)
            Row(children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  heroes
                    ..clear()
                    ..addAll(StateScope.read(context).enemies.whereType<int>());
                }),
                icon: const Icon(Icons.sync, size: 16),
                label: Text(L('Из драфта', 'From draft'), style: const TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.person_add_alt, size: 16),
                label: Text(L('Добавить', 'Add'), style: const TextStyle(fontSize: 12)),
              ),
            ]),
          if (!widget.embedded)
          Text(
            L('Увидел ульт или выкуп врага — нажми кнопку. Когда перезарядка закончится, телефон скажет и завибрирует. '
                'Экран не гаснет, пока открыт этот экран.',
                'Saw an enemy ult or buyback? Tap the button. When the cooldown ends, the phone will speak and vibrate. '
                'The screen stays on while this page is open.'),
            style: T.small,
          ),
          const SizedBox(height: 8),
          if (heroes.isEmpty)
            AppCard(
              onTap: _add,
              child: Text(L('Добавь героев врага (или заполни противников на вкладке «Драфт»).',
                  'Add enemy heroes (or fill in enemies on the Draft tab).'), style: T.body),
            ),
          for (final id in heroes)
            if (s.data!.byId[id] != null) _heroCard(s, s.data!.byId[id]!, s.info.heroes[id]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(L('Перезарядка выкупа: ${mmss(buyback)}', 'Buyback cooldown: ${mmss(buyback)}'), style: T.small)),
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              onPressed: () => setState(() => buyback = (buyback - 10).clamp(60, 900)),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => setState(() => buyback = (buyback + 10).clamp(60, 900)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _heroCard(AppState s, DHero h, HeroInfo? info) {
    final ult = info?.ultimate;
    final maxLvl = ult == null ? 3 : ult.cd.length.clamp(1, 3);
    final lvl = (ultLevel[h.id] ?? 1).clamp(1, maxLvl);
    final oct = octarine[h.id] ?? false;
    final base = ult?.cdAt(lvl) ?? 0;
    final cd = (base * (oct ? 0.75 : 1)).round();
    final now = DateTime.now();
    final ultLeft = running['${h.id}:ult']?.readyAt.difference(now).inSeconds;
    final bbLeft = running['${h.id}:bb']?.readyAt.difference(now).inSeconds;

    Widget btn(String label, int? left, VoidCallback onTap, VoidCallback onCancel, Color color) => Expanded(
          child: SizedBox(
            height: 52,
            child: left != null
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(side: BorderSide(color: color), foregroundColor: color),
                    onPressed: onCancel,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(mmss(left + 1), style: T.num(18, color: color)),
                      Text(L('нажми — сброс', 'tap to reset'), style: const TextStyle(fontSize: 9.5)),
                    ]),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color.withValues(alpha: 0.85)),
                    onPressed: onTap,
                    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            HeroImg(h, width: 60),
            const SizedBox(width: 8),
            if (ult != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                    imageUrl: ult.image, width: 30, height: 30, errorWidget: (_, __, ___) => const SizedBox(width: 30)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.name, style: T.body.copyWith(fontWeight: FontWeight.w700)),
                Text(ult == null ? L('нет данных об ульте', 'no ult data') : '${ult.name} · ${base}s${oct ? ' → ${cd}s' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: T.small),
              ]),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, size: 18, color: C.muted),
              onPressed: () => setState(() {
                heroes.remove(h.id);
                running.remove('${h.id}:ult');
                running.remove('${h.id}:bb');
              }),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(L('Уровень ульта:', 'Ult level:'), style: T.small),
            for (var l = 1; l <= maxLvl; l++)
              Pill('$l', color: C.accent2, filled: lvl == l, onTap: () => setState(() => ultLevel[h.id] = l)),
            const SizedBox(width: 6),
            Pill(L('Октарин −25%', 'Octarine −25%'), color: C.intel, filled: oct, onTap: () => setState(() => octarine[h.id] = !oct)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            btn(
              L('Ульт использован', 'Ult used'),
              ultLeft,
              cd <= 0
                  ? () {}
                  : () => _start('${h.id}:ult', cd, L('Ульт ${h.name} снова готов', '${h.name} ultimate is ready')),
              () => setState(() => running.remove('${h.id}:ult')),
              C.accent,
            ),
            const SizedBox(width: 8),
            btn(
              L('Выкупился', 'Bought back'),
              bbLeft,
              () => _start('${h.id}:bb', buyback, L('${h.name} снова может выкупиться', '${h.name} can buy back again')),
              () => setState(() => running.remove('${h.id}:bb')),
              C.gold,
            ),
          ]),
        ]),
      ),
    );
  }
}
