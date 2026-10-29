import 'tools_state.dart';

// Схема карты (координаты 0–100, x вправо, y вниз). База Света — слева внизу, Тьмы — справа вверху.
// Река идёт из левого верхнего угла в правый нижний, мид — из левого нижнего в правый верхний.
// Позиции примерные: карта меняется в больших патчах — точки можно двигать и добавлять в приложении.
// Точки заданы для Света; для Тьмы они поворачиваются на 180°.

const campKinds = {'small', 'medium', 'large', 'ancient'};

const radiantPoints = <MapPoint>[
  // Лес Света у лёгкой линии (низ)
  MapPoint('r_safe_small', 'small', 60, 83, 'Малый лагерь'),
  MapPoint('r_safe_medium', 'medium', 48, 76, 'Средний лагерь'),
  MapPoint('r_safe_large1', 'large', 62, 73, 'Большой лагерь'),
  MapPoint('r_safe_large2', 'large', 40, 68, 'Большой лагерь у мида'),
  MapPoint('r_safe_medium2', 'medium', 73, 80, 'Средний лагерь у вышки'),
  MapPoint('r_ancient', 'ancient', 52, 63, 'Древние'),
  // Лес Света у сложной линии (верх)
  MapPoint('r_off_large', 'large', 20, 50, 'Большой лагерь (верх)'),
  MapPoint('r_off_medium', 'medium', 27, 60, 'Средний лагерь (верх)'),
  MapPoint('r_off_small', 'small', 14, 42, 'Малый лагерь (верх)'),
  // Объекты
  MapPoint('r_bounty', 'rune', 33, 72, 'Руна богатства'),
  MapPoint('r_wisdom', 'rune', 8, 66, 'Руна мудрости'),
  MapPoint('r_tormentor', 'tormentor', 80, 88, 'Торментор'),
];

/// Общие точки в реке (не зеркалятся по сторонам).
const riverPoints = <MapPoint>[
  MapPoint('rune_top', 'rune', 36, 37, 'Руна силы (верх)'),
  MapPoint('rune_bot', 'rune', 64, 63, 'Руна силы (низ)'),
  MapPoint('rosh_top', 'roshan', 27, 29, 'Рошан (днём — сверху)'),
  MapPoint('rosh_bot', 'roshan', 73, 71, 'Рошан (ночью — снизу)'),
];

/// Варды для Света. phase: 0 — ранняя игра, 1 — середина, 2 — Рошан и торментор, 3 — поздняя игра.
const radiantWards = <MapPoint>[
  MapPoint('w_r_mid_high', 'obs', 46, 56, 'Холм у мида', note: 'Видно руну силы и подходы к миду.', phase: 0),
  MapPoint('w_r_safe_pull', 'obs', 66, 80, 'Пул на лёгкой', note: 'Защищает керри на линии от ганков из реки.', phase: 0),
  MapPoint('w_r_off_jungle', 'obs', 29, 46, 'Вход в лес у сложной', note: 'Видно, кто идёт на твою сложную линию.', phase: 0),
  MapPoint('w_r_rune_bot', 'sen', 63, 66, 'Сентри у нижней руны', note: 'Против невидимых героев и вражеских обсов у руны.', phase: 0),
  MapPoint('w_r_enemy_safe', 'obs', 30, 18, 'Лес врага (их лёгкая)', note: 'Агрессивный вард: видно фарм вражеского керри.', phase: 1),
  MapPoint('w_r_enemy_off', 'obs', 74, 40, 'Лес врага у их сложной', note: 'Ловить их хардлайнера и саппорта.', phase: 1),
  MapPoint('w_r_mid_river', 'obs', 54, 46, 'Мид-река', note: 'Контроль центра карты и обеих рун.', phase: 1),
  MapPoint('w_r_rosh_top', 'obs', 22, 33, 'Над верхним Рошаном', note: 'Ставь заранее, за 1–2 минуты до попытки.', phase: 2),
  MapPoint('w_r_rosh_bot', 'obs', 78, 67, 'Над нижним Рошаном', note: 'Ночью Рошан внизу.', phase: 2),
  MapPoint('w_r_rosh_sen', 'sen', 30, 32, 'Сентри в яме Рошана', note: 'Убирает вражеские варды перед боем.', phase: 2),
  MapPoint('w_r_torm', 'obs', 84, 82, 'У торментора', note: 'Видно, кто идёт бить торментора.', phase: 2),
  MapPoint('w_r_hg_top', 'obs', 62, 20, 'Перед вражеской базой (верх)', note: 'Для осады: видно телепорты и выходы с базы.', phase: 3),
  MapPoint('w_r_hg_mid', 'obs', 70, 30, 'У вражеских вышек мида', note: 'Безопасный подход к хай-граунду.', phase: 3),
  MapPoint('w_r_def', 'sen', 25, 75, 'Защита своей базы', note: 'Сентри против невидимых пушеров.', phase: 3),
];

const wardPhases = ['Ранняя', 'Середина', 'Рошан', 'Поздняя'];

/// Готовые маршруты фарма для Света (по точкам лагерей).
const radiantRoutes = <FarmRoute>[
  FarmRoute('rt_lane_jungle', 'Линия + лес (0–10 мин)',
      'Добил волну на линии → малый и большой лагерь рядом → обратно к следующей волне. '
          'Не уходи далеко от вышки, пока нет Battle Fury или аналога.',
      [
        [74, 92],
        [60, 83],
        [62, 73],
        [74, 92],
      ]),
  FarmRoute('rt_full_jungle', 'Полный круг по лесу (10–20 мин)',
      'Волна на лёгкой → средний у вышки → большой → средний → большой у мида → волна на миде. '
          'Каждая минута без фарма — потерянное золото.',
      [
        [80, 92],
        [73, 80],
        [62, 73],
        [48, 76],
        [40, 68],
        [45, 55],
      ]),
  FarmRoute('rt_ancients', 'Лес + древние (20+ мин)',
      'Стакнутые древние → большой у мида → волна на миде → лес сложной линии → волна сверху. '
          'Попроси саппорта стакать древних в :53–:55.',
      [
        [52, 63],
        [40, 68],
        [45, 55],
        [27, 60],
        [20, 50],
        [8, 40],
      ]),
  FarmRoute('rt_stack', 'Стаки для керри (саппорт)',
      'В :53–:55 ударь лагерь и уведи крипов из зоны — появится второй отряд. '
          'Лучше всего стакать большие лагеря и древних рядом с керри.',
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
