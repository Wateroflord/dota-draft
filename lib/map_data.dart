import 'i18n.dart';
import 'tools_state.dart';

// Схема карты (координаты 0–100, x вправо, y вниз). База Света — слева внизу, Тьмы — справа вверху.
// Река идёт из левого верхнего угла в правый нижний, мид — из левого нижнего в правый верхний.
// Позиции примерные: карта меняется в больших патчах — точки можно двигать и добавлять в приложении.
// Точки заданы для Света; для Тьмы они поворачиваются на 180°.

const campKinds = {'small', 'medium', 'large', 'ancient'};

List<MapPoint> get radiantPoints => [
  // Лес Света у лёгкой линии (низ)
  MapPoint('r_safe_small', 'small', 60, 83, L('Малый лагерь', 'Small camp')),
  MapPoint('r_safe_medium', 'medium', 48, 76, L('Средний лагерь', 'Medium camp')),
  MapPoint('r_safe_large1', 'large', 62, 73, L('Большой лагерь', 'Large camp')),
  MapPoint('r_safe_large2', 'large', 40, 68, L('Большой лагерь у мида', 'Large camp near mid')),
  MapPoint('r_safe_medium2', 'medium', 73, 80, L('Средний лагерь у вышки', 'Medium camp near the tower')),
  MapPoint('r_ancient', 'ancient', 52, 63, L('Древние', 'Ancients')),
  // Лес Света у сложной линии (верх)
  MapPoint('r_off_large', 'large', 20, 50, L('Большой лагерь (верх)', 'Large camp (top)')),
  MapPoint('r_off_medium', 'medium', 27, 60, L('Средний лагерь (верх)', 'Medium camp (top)')),
  MapPoint('r_off_small', 'small', 14, 42, L('Малый лагерь (верх)', 'Small camp (top)')),
  // Объекты
  MapPoint('r_bounty', 'rune', 33, 72, L('Руна богатства', 'Bounty rune')),
  MapPoint('r_wisdom', 'rune', 8, 66, L('Руна мудрости', 'Wisdom rune')),
  MapPoint('r_tormentor', 'tormentor', 80, 88, L('Торментор', 'Tormentor')),
];

/// Общие точки в реке (не зеркалятся по сторонам).
List<MapPoint> get riverPoints => [
  MapPoint('rune_top', 'rune', 36, 37, L('Руна силы (верх)', 'Power rune (top)')),
  MapPoint('rune_bot', 'rune', 64, 63, L('Руна силы (низ)', 'Power rune (bottom)')),
  MapPoint('rosh_top', 'roshan', 27, 29, L('Рошан (днём — сверху)', 'Roshan (top during the day)')),
  MapPoint('rosh_bot', 'roshan', 73, 71, L('Рошан (ночью — снизу)', 'Roshan (bottom at night)')),
];

/// Варды для Света. phase: 0 — ранняя игра, 1 — середина, 2 — Рошан и торментор, 3 — поздняя игра.
List<MapPoint> get radiantWards => [
  MapPoint('w_r_mid_high', 'obs', 46, 56, L('Холм у мида', 'Mid high ground'), note: L('Видно руну силы и подходы к миду.', 'Sees the power rune and mid approaches.'), phase: 0),
  MapPoint('w_r_safe_pull', 'obs', 66, 80, L('Пул на лёгкой', 'Safe lane pull'), note: L('Защищает керри на линии от ганков из реки.', 'Protects the carry from river ganks.'), phase: 0),
  MapPoint('w_r_off_jungle', 'obs', 29, 46, L('Вход в лес у сложной', 'Off lane jungle entrance'), note: L('Видно, кто идёт на твою сложную линию.', 'Shows who is going to your off lane.'), phase: 0),
  MapPoint('w_r_rune_bot', 'sen', 63, 66, L('Сентри у нижней руны', 'Sentry at the bottom rune'), note: L('Против невидимых героев и вражеских обсов у руны.', 'Against invisible heroes and enemy observers at the rune.'), phase: 0),
  MapPoint('w_r_enemy_safe', 'obs', 30, 18, L('Лес врага (их лёгкая)', 'Enemy jungle (their safe lane)'), note: L('Агрессивный вард: видно фарм вражеского керри.', 'Aggressive ward: shows the enemy carry farming.'), phase: 1),
  MapPoint('w_r_enemy_off', 'obs', 74, 40, L('Лес врага у их сложной', 'Enemy jungle near their off lane'), note: L('Ловить их хардлайнера и саппорта.', 'Catch their offlaner and support.'), phase: 1),
  MapPoint('w_r_mid_river', 'obs', 54, 46, L('Мид-река', 'Mid river'), note: L('Контроль центра карты и обеих рун.', 'Controls the map centre and both runes.'), phase: 1),
  MapPoint('w_r_rosh_top', 'obs', 22, 33, L('Над верхним Рошаном', 'Above top Roshan'), note: L('Ставь заранее, за 1–2 минуты до попытки.', 'Place it 1–2 minutes before the attempt.'), phase: 2),
  MapPoint('w_r_rosh_bot', 'obs', 78, 67, L('Над нижним Рошаном', 'Above bottom Roshan'), note: L('Ночью Рошан внизу.', 'Roshan is at the bottom at night.'), phase: 2),
  MapPoint('w_r_rosh_sen', 'sen', 30, 32, L('Сентри в яме Рошана', 'Sentry in Roshan pit'), note: L('Убирает вражеские варды перед боем.', 'Clears enemy wards before the fight.'), phase: 2),
  MapPoint('w_r_torm', 'obs', 84, 82, L('У торментора', 'Near Tormentor'), note: L('Видно, кто идёт бить торментора.', 'Shows who goes to Tormentor.'), phase: 2),
  MapPoint('w_r_hg_top', 'obs', 62, 20, L('Перед вражеской базой (верх)', 'In front of enemy base (top)'), note: L('Для осады: видно телепорты и выходы с базы.', 'For sieges: shows teleports and base exits.'), phase: 3),
  MapPoint('w_r_hg_mid', 'obs', 70, 30, L('У вражеских вышек мида', 'Near enemy mid towers'), note: L('Безопасный подход к хай-граунду.', 'Safe approach to high ground.'), phase: 3),
  MapPoint('w_r_def', 'sen', 25, 75, L('Защита своей базы', 'Base defence'), note: L('Сентри против невидимых пушеров.', 'Sentry against invisible pushers.'), phase: 3),
];

List<String> get wardPhases => [L('Ранняя', 'Early'), L('Середина', 'Mid game'), L('Рошан', 'Roshan'), L('Поздняя', 'Late')];

/// Готовые маршруты фарма для Света (по точкам лагерей).
List<FarmRoute> get radiantRoutes => [
  FarmRoute('rt_lane_jungle', L('Линия + лес (0–10 мин)', 'Lane + jungle (0–10 min)'),
      L('Добил волну на линии → малый и большой лагерь рядом → обратно к следующей волне. '
          'Не уходи далеко от вышки, пока нет Battle Fury или аналога.', 'Clear the lane wave → nearby small and large camp → back for the next wave. '
          'Stay close to your tower until you have Battle Fury or similar.'),
      [
        [74, 92],
        [60, 83],
        [62, 73],
        [74, 92],
      ]),
  FarmRoute('rt_full_jungle', L('Полный круг по лесу (10–20 мин)', 'Full jungle loop (10–20 min)'),
      L('Волна на лёгкой → средний у вышки → большой → средний → большой у мида → волна на миде. '
          'Каждая минута без фарма — потерянное золото.', 'Safe lane wave → medium near tower → large → medium → large near mid → mid wave. '
          'Every minute without farming is lost gold.'),
      [
        [80, 92],
        [73, 80],
        [62, 73],
        [48, 76],
        [40, 68],
        [45, 55],
      ]),
  FarmRoute('rt_ancients', L('Лес + древние (20+ мин)', 'Jungle + ancients (20+ min)'),
      L('Стакнутые древние → большой у мида → волна на миде → лес сложной линии → волна сверху. '
          'Попроси саппорта стакать древних в :53–:55.', 'Stacked ancients → large near mid → mid wave → off lane jungle → top wave. '
          'Ask your support to stack ancients at :53–:55.'),
      [
        [52, 63],
        [40, 68],
        [45, 55],
        [27, 60],
        [20, 50],
        [8, 40],
      ]),
  FarmRoute('rt_stack', L('Стаки для керри (саппорт)', 'Stacks for the carry (support)'),
      L('В :53–:55 ударь лагерь и уведи крипов из зоны — появится второй отряд. '
          'Лучше всего стакать большие лагеря и древних рядом с керри.', 'At :53–:55 hit the camp and pull the creeps out — a second group spawns. '
          'Best to stack large camps and ancients near the carry.'),
      [
        [62, 73],
        [66, 66],
        [52, 63],
        [56, 56],
      ]),
];

MapPoint _rot(MapPoint p, String prefix) =>
    MapPoint('$prefix${p.id}', p.kind, 100 - p.x, 100 - p.y, p.title, note: p.note, phase: p.phase, custom: p.custom);

FarmRoute _rotRoute(FarmRoute r) =>
    FarmRoute('d_${r.id}', r.title, r.desc, [for (final p in r.points) [100 - p[0], 100 - p[1]]]);

/// Лагеря и объекты для стороны.
List<MapPoint> mapObjects(bool radiant) => [
      ...riverPoints,
      for (final p in radiantPoints) radiant ? p : _rot(p, 'd_'),
      // Лагеря противника тоже показываем (бледнее) — для маршрутов в чужой лес.
      for (final p in radiantPoints.where((p) => campKinds.contains(p.kind))) radiant ? _rot(p, 'e_') : p,
    ];

List<MapPoint> wardSpots(bool radiant) => [for (final p in radiantWards) radiant ? p : _rot(p, 'd_')];

List<FarmRoute> farmRoutes(bool radiant) => [for (final r in radiantRoutes) radiant ? r : _rotRoute(r)];
