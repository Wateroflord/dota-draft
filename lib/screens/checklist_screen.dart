import 'package:flutter/material.dart';

import '../data.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets.dart';

class _Item {
  final String time, ru, en;
  const _Item(this.time, this.ru, this.en);
  String get text => L(ru, en);
}

const _lists = <int, List<_Item>>{
  1: [
    _Item('0:00', 'Старт: танго, ветки, предметы на атрибут. Стой на лёгкой линии, добивай и отказывай.',
        'Start: tango, branches, stat items. Stay in the safe lane, last hit and deny.'),
    _Item('2:00', 'Следи за мини-картой: если пропали враги с линий — отойди к вышке.', 'Watch the minimap: if enemies are missing, back off to your tower.'),
    _Item('3:00–5:00', 'Сапоги и Magic Stick. Не трать деньги на лишнее.', 'Boots and Magic Stick. Do not waste gold.'),
    _Item('7:00', 'Первый фарм-предмет (Battle Fury, Maelstrom и т. п.), если линия выиграна.', 'First farming item (Battle Fury, Maelstrom etc.) if the lane went well.'),
    _Item('10:00', 'Цель — 50–60 добиваний к 10-й минуте.', 'Goal — 50–60 last hits by minute 10.'),
    _Item('10–20', 'Фарми лес между волнами. Без вардов на сторону врага не ходи.', 'Farm the jungle between waves. Do not go into enemy territory without wards.'),
    _Item('15:00', 'BKB, если у врагов много контроля или магии.', 'BKB if enemies have lots of control or magic.'),
    _Item('20+', 'Иди на Рошана и драки с командой, фарми там, где есть варды.', 'Join Roshan and fights, farm where there are wards.'),
    _Item('30+', 'Всегда держи золото на выкуп.', 'Always keep gold for buyback.'),
  ],
  2: [
    _Item('0:00', 'Руны богатства — помоги команде их забрать, потом на мид.', 'Bounty runes — help the team grab them, then go mid.'),
    _Item('2:00', 'Водная руна на миде — забери её.', 'Water rune at mid — take it.'),
    _Item('3:00–5:00', 'Бутылка и сапоги. Свиток телепорта всегда в инвентаре.', 'Bottle and boots. Always carry a TP scroll.'),
    _Item('6:00', 'Руна силы: держи контроль над рекой, с руной — ганк на линию.', 'Power rune: control the river, gank a lane with it.'),
    _Item('6 ур.', 'После 6-го уровня помогай боковым линиям.', 'After level 6 help the side lanes.'),
    _Item('10:00', 'Цель — 40+ добиваний и выигранная линия.', 'Goal — 40+ last hits and a won lane.'),
    _Item('15–20', 'Ключевые предметы и игра на темп вместе с командой.', 'Key items and tempo plays with the team.'),
  ],
  3: [
    _Item('0:00', 'Скорее всего ты один против двух — получай опыт и не умирай.', 'You are likely 1v2 — get experience and do not die.'),
    _Item('2:00', 'Мешай вражескому керри фармить, но без лишнего риска.', 'Annoy the enemy carry, but do not over-risk.'),
    _Item('5–8', 'Инициирующий предмет (Blink и т. п.), если ты инициатор.', 'Initiation item (Blink etc.) if you are the initiator.'),
    _Item('10–15', 'Ставь агрессивные варды с саппортами, дави вышки.', 'Place aggressive wards with supports, pressure towers.'),
    _Item('15+', 'Командные предметы против урона врагов: Pipe, Crimson Guard.', 'Team items against enemy damage: Pipe, Crimson Guard.'),
    _Item('20+', 'Начинай драки первым, когда ульты команды готовы.', 'Start fights when your team\'s ults are ready.'),
  ],
  4: [
    _Item('0:00', 'Обсервер и сентри, руны богатства у реки.', 'Observer and sentry, bounty runes by the river.'),
    _Item('1:30–2:00', 'Помоги хардлайнеру, затем ганк мида после водной руны.', 'Help the offlaner, then gank mid after the water rune.'),
    _Item('3:00', 'Смок-ганк с мидером или саппортом.', 'Smoke gank with the mid or support.'),
    _Item('6:00', 'Помоги мидеру контролировать руну силы.', 'Help mid control the power rune.'),
    _Item('7:00', 'Руна мудрости — заберите её с саппортом.', 'Wisdom rune — take it with the support.'),
    _Item('7–10', 'Агрессивные варды и ганги.', 'Aggressive wards and ganks.'),
    _Item('15:00', 'Blink, Force Staff или Glimmer Cape.', 'Blink, Force Staff or Glimmer Cape.'),
    _Item('всегда', 'Обсы при смене стадии игры, сентри против невидимых. Не умирай без пользы.',
        'Observers on every phase change, sentries vs invisible heroes. Do not die for nothing.'),
  ],
  5: [
    _Item('0:00', 'Обсервер, сентри, танго, кларити. Поставь вард на линии керри.', 'Observer, sentry, tango, clarities. Ward the carry\'s lane.'),
    _Item(':15 / :45', 'Пул малого лагеря в эти секунды — волна уйдёт к вышке керри.', 'Pull the small camp at these seconds — the wave goes to the carry\'s tower.'),
    _Item(':53–:55', 'Стак лагеря рядом с керри.', 'Stack a camp near the carry.'),
    _Item('2:00', 'Водная руна — отдай мидеру или забери себе.', 'Water rune — give it to mid or take it.'),
    _Item('5:00', 'Вард у руны силы, сентри против вражеских обсов.', 'Ward near the power rune, sentry against enemy observers.'),
    _Item('7:00', 'Руна мудрости — опыт для саппорта.', 'Wisdom rune — experience for the support.'),
    _Item('10:00', 'Glimmer Cape, Force Staff или Ghost Scepter.', 'Glimmer Cape, Force Staff or Ghost Scepter.'),
    _Item('15–20', 'Варды для Рошана за 1–2 минуты до попытки.', 'Roshan wards 1–2 minutes before the attempt.'),
    _Item('всегда', 'Пыль и гем против невидимых, смок для команды, стой позади керри в драке.',
        'Dust and gem vs invisible heroes, smoke for the team, stay behind the carry in fights.'),
  ],
};

/// Чек-листы по позициям: что делать по минутам.
class ChecklistScreen extends StatefulWidget {
  final int position;
  const ChecklistScreen({super.key, this.position = 1});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late int pos = widget.position.clamp(1, 5);
  final Set<String> done = {};

  @override
  Widget build(BuildContext context) {
    final items = _lists[pos]!;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(L('Чек-листы по позициям', 'Position checklists'), style: T.h2),
        actions: [
          IconButton(tooltip: L('Сбросить отметки', 'Clear checks'), icon: const Icon(Icons.restart_alt), onPressed: () => setState(done.clear)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var p = 1; p <= 5; p++)
              Pill('$p · ${positionNames[p]}', color: C.accent, filled: pos == p, onTap: () => setState(() => pos = p)),
          ]),
          const SizedBox(height: 10),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                onTap: () => setState(() => done.contains('$pos${it.time}') ? done.remove('$pos${it.time}') : done.add('$pos${it.time}')),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(done.contains('$pos${it.time}') ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20, color: done.contains('$pos${it.time}') ? C.ally : C.muted),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    child: Text(it.time == 'всегда' ? L('всегда', 'always') : it.time, style: T.num(13, color: C.gold)),
                  ),
                  Expanded(
                    child: Text(it.text,
                        style: T.body.copyWith(fontSize: 13.5, color: done.contains('$pos${it.time}') ? C.muted : C.text)),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 6),
          Text(L('Отмечай пункты во время матча. Тайминги рун — для текущего патча, они могут меняться.',
              'Tick items during the match. Rune timings are for the current patch and may change.'), style: T.small),
        ],
      ),
    );
  }
}
