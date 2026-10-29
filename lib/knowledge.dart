// Знания о героях, которых нет в статистике: русские названия и сленг для поиска,
// кто даёт сейвы, лечение, невидимость, иллюзии и т. п. Ключ — внутреннее имя героя (antimage).

const ruNames = <String, List<String>>{
  'antimage': ['Антимаг', 'АМ'],
  'axe': ['Акс'],
  'bane': ['Бейн'],
  'bloodseeker': ['Бладсикер', 'Блад'],
  'crystal_maiden': ['Кристал Мейден', 'ЦМ', 'Цмка', 'Рылай'],
  'drow_ranger': ['Дроу', 'Дровка', 'Траксекс'],
  'earthshaker': ['Шейкер', 'ЕС', 'Эртшейкер'],
  'juggernaut': ['Джаггернаут', 'Джагер', 'Джаг'],
  'mirana': ['Мирана', 'Пота'],
  'morphling': ['Морфлинг', 'Морф'],
  'nevermore': ['Шадоу Финд', 'СФ', 'Невермор', 'Сф'],
  'phantom_lancer': ['Фантом Лансер', 'ПЛ', 'Лансер'],
  'puck': ['Пак'],
  'pudge': ['Пудж', 'Пудге'],
  'razor': ['Разор'],
  'sand_king': ['Сенд Кинг', 'СК', 'Краб'],
  'storm_spirit': ['Шторм', 'Шторм Спирит'],
  'sven': ['Свен'],
  'tiny': ['Тини', 'Тайни'],
  'vengefulspirit': ['Венга', 'Вендж', 'Вэнджа'],
  'windrunner': ['Виндраннер', 'Винда', 'Виндрейнджер'],
  'zuus': ['Зевс'],
  'kunkka': ['Кунка', 'Адмирал'],
  'lina': ['Лина'],
  'lion': ['Лион', 'Лайон'],
  'shadow_shaman': ['Шаман', 'Раста', 'Шадоу Шаман'],
  'slardar': ['Сларда', 'Слардар'],
  'tidehunter': ['Тайд', 'Тайдхантер'],
  'witch_doctor': ['Вич Доктор', 'ВД', 'Витч'],
  'lich': ['Лич'],
  'riki': ['Рики'],
  'enigma': ['Энигма'],
  'tinker': ['Тинкер'],
  'sniper': ['Снайпер', 'Снайп'],
  'necrolyte': ['Некрофос', 'Некр'],
  'warlock': ['Варлок'],
  'beastmaster': ['Бистмастер', 'Бист'],
  'queenofpain': ['Квопа', 'Королева боли', 'КОП', 'Акаша'],
  'venomancer': ['Веномансер', 'Веном'],
  'faceless_void': ['Войд', 'Фейслес Войд', 'Фв'],
  'skeleton_king': ['Врейс Кинг', 'Скелет', 'ВК', 'Король'],
  'death_prophet': ['Дез Профет', 'ДП', 'Дпшка'],
  'phantom_assassin': ['Фантомка', 'ПА', 'Мортред'],
  'pugna': ['Пугна'],
  'templar_assassin': ['Темпларка', 'ТА', 'Ланая'],
  'viper': ['Вайпер'],
  'luna': ['Луна'],
  'dragon_knight': ['Драгон Кнайт', 'ДК', 'Дракон'],
  'dazzle': ['Дазл'],
  'rattletrap': ['Клокверк', 'Клок'],
  'leshrac': ['Лешрак', 'Леш'],
  'furion': ['Профет', 'Фура', 'НП', 'Натурс Профет'],
  'life_stealer': ['Гуля', 'Лайфстилер', 'Найкс'],
  'dark_seer': ['Дарк Сир', 'Сир'],
  'clinkz': ['Клинкз', 'Клинкс'],
  'omniknight': ['Омник', 'Омнинайт'],
  'enchantress': ['Энча', 'Энчантресс'],
  'huskar': ['Хускар', 'Хуск'],
  'night_stalker': ['Найт Сталкер', 'Балануар', 'НС'],
  'broodmother': ['Бруда', 'Паучиха', 'Бруд'],
  'bounty_hunter': ['Баунти', 'БХ'],
  'weaver': ['Вивер'],
  'jakiro': ['Джакиро', 'Джак'],
  'batrider': ['Батрайдер', 'Бэт', 'Бат'],
  'chen': ['Чен'],
  'spectre': ['Спектра', 'Спектр'],
  'ancient_apparition': ['Апарат', 'АА', 'Эншент'],
  'doom_bringer': ['Дум'],
  'ursa': ['Урса'],
  'spirit_breaker': ['Бара', 'Спирит Брейкер', 'СБ'],
  'gyrocopter': ['Гиро', 'Гирокоптер'],
  'alchemist': ['Алхимик', 'Алх'],
  'invoker': ['Инвокер', 'Инвок', 'Карл'],
  'silencer': ['Сайленсер', 'Сало'],
  'obsidian_destroyer': ['ОД', 'Аутворлд', 'Харбор'],
  'lycan': ['Ликан'],
  'brewmaster': ['Брюмастер', 'Панда', 'Брю'],
  'shadow_demon': ['Шадоу Демон', 'ШД'],
  'lone_druid': ['Друид', 'ЛД', 'Медведь'],
  'chaos_knight': ['Хаос', 'ЦК', 'Хаос Кнайт'],
  'meepo': ['Мипо'],
  'treant': ['Трент', 'Дерево'],
  'ogre_magi': ['Огр', 'Огр Маг'],
  'undying': ['Андаинг', 'Зомби', 'Андайинг'],
  'rubick': ['Рубик'],
  'disruptor': ['Дизраптор'],
  'nyx_assassin': ['Никс'],
  'naga_siren': ['Нага'],
  'keeper_of_the_light': ['Котл', 'КОТЛ', 'Кипер'],
  'wisp': ['Ио', 'Висп'],
  'visage': ['Визаж'],
  'slark': ['Сларк'],
  'medusa': ['Медуза', 'Дуза'],
  'troll_warlord': ['Тролль', 'Трол'],
  'centaur': ['Кентавр', 'Цент'],
  'magnataur': ['Магнус', 'Маг'],
  'shredder': ['Тимбер', 'Тимберсо'],
  'bristleback': ['Бристл', 'Бристлбек', 'Ёж'],
  'tusk': ['Туск'],
  'skywrath_mage': ['Скай', 'Скайрэт'],
  'abaddon': ['Абаддон', 'Аба'],
  'elder_titan': ['Элдер Титан', 'ЕТ', 'Титан'],
  'legion_commander': ['Легионка', 'ЛК', 'Легион'],
  'techies': ['Техники', 'Минёр', 'Течис'],
  'ember_spirit': ['Эмбер', 'Эмбер Спирит'],
  'earth_spirit': ['Ерс Спирит', 'Земля', 'Кабан'],
  'abyssal_underlord': ['Андерлорд', 'Питлорд'],
  'terrorblade': ['Терроблейд', 'ТБ'],
  'phoenix': ['Феникс'],
  'oracle': ['Оракл', 'Оракул'],
  'winter_wyvern': ['Виверна', 'ВВ'],
  'arc_warden': ['Арк', 'Арк Варден', 'Зет'],
  'monkey_king': ['Манки Кинг', 'МК', 'Обезьяна'],
  'dark_willow': ['Дарк Вилоу', 'Вилоу'],
  'pangolier': ['Панголиер', 'Панго'],
  'grimstroke': ['Гримстрок', 'Грим'],
  'hoodwink': ['Худвинк', 'Белка'],
  'void_spirit': ['Войд Спирит', 'Войд спирит'],
  'snapfire': ['Снэпфаер', 'Бабка'],
  'mars': ['Марс'],
  'dawnbreaker': ['Даунбрейкер', 'Даун'],
  'marci': ['Марси'],
  'primal_beast': ['Праймал Бист', 'Праймал'],
  'muerta': ['Муэрта'],
  'kez': ['Кез'],
  'ringmaster': ['Рингмастер'],
  'largo': ['Ларго'],
};

/// Могут спасти союзника: щит, неуязвимость, лечение в момент опасности, телепорт.
const savers = {
  'oracle', 'dazzle', 'omniknight', 'abaddon', 'wisp', 'winter_wyvern', 'shadow_demon', 'vengefulspirit',
  'earth_spirit', 'chen', 'treant', 'marci', 'snapfire', 'grimstroke', 'bane', 'pugna', 'silencer',
  'dark_willow', 'pangolier', 'ringmaster', 'keeper_of_the_light',
};

/// Заметное лечение команды или себя.
const healers = {
  'oracle', 'dazzle', 'omniknight', 'wisp', 'chen', 'witch_doctor', 'treant', 'necrolyte', 'warlock',
  'undying', 'abaddon', 'huskar', 'life_stealer', 'alchemist', 'morphling', 'enchantress', 'largo',
  'winter_wyvern', 'phoenix', 'dawnbreaker',
};

/// Невидимость (нужны пыль, сентри, гем).
const invisible = {
  'riki', 'clinkz', 'bounty_hunter', 'weaver', 'nyx_assassin', 'invoker', 'mirana', 'sand_king', 'treant',
  'templar_assassin', 'void_spirit', 'hoodwink',
};

/// Иллюзии и призванные существа (нужен урон по области).
const illusions = {
  'phantom_lancer', 'naga_siren', 'chaos_knight', 'terrorblade', 'meepo', 'arc_warden', 'lone_druid',
  'broodmother', 'furion', 'beastmaster', 'visage', 'lycan', 'warlock', 'undying', 'venomancer',
  'shadow_shaman', 'monkey_king', 'spectre',
};

/// Уклонение (нужны MKB, Bloodthorn).
const evasion = {'phantom_assassin', 'windrunner', 'brewmaster', 'troll_warlord'};

/// Сильные пассивки, которые выключает Silver Edge.
const breakTargets = {
  'bristleback', 'spectre', 'phantom_assassin', 'huskar', 'medusa', 'tidehunter', 'axe', 'viper', 'mars',
  'slark', 'troll_warlord', 'ursa', 'legion_commander', 'faceless_void', 'monkey_king', 'pangolier',
};

/// Мощные заклинания в одну цель (Linken's Sphere, Lotus Orb).
const singleTarget = {
  'lion', 'lina', 'doom_bringer', 'legion_commander', 'batrider', 'bane', 'shadow_demon', 'rubick',
  'beastmaster', 'night_stalker', 'skeleton_king', 'shadow_shaman', 'grimstroke', 'nyx_assassin',
  'ancient_apparition', 'winter_wyvern', 'pudge', 'lycan',
};

/// Сайленсы (Manta, Eul's, Lotus).
const silencers = {
  'silencer', 'skywrath_mage', 'drow_ranger', 'night_stalker', 'death_prophet', 'riki', 'doom_bringer',
  'bloodseeker', 'puck', 'grimstroke', 'earth_spirit', 'templar_assassin',
};

/// Наносят в основном магический урон.
const magicDamage = {
  'zuus', 'lina', 'lion', 'leshrac', 'storm_spirit', 'puck', 'queenofpain', 'skywrath_mage', 'tinker',
  'invoker', 'death_prophet', 'necrolyte', 'pugna', 'ancient_apparition', 'jakiro', 'crystal_maiden',
  'lich', 'witch_doctor', 'shadow_shaman', 'earthshaker', 'sand_king', 'nyx_assassin', 'keeper_of_the_light',
  'ogre_magi', 'disruptor', 'dark_willow', 'grimstroke', 'oracle', 'venomancer', 'enigma', 'warlock',
  'batrider', 'phoenix', 'void_spirit', 'shredder', 'huskar', 'undying', 'techies', 'obsidian_destroyer',
  'winter_wyvern', 'rubick', 'dazzle', 'earth_spirit', 'elder_titan', 'largo', 'ringmaster', 'muerta',
  'dark_seer', 'tidehunter', 'bane', 'silencer', 'ember_spirit', 'snapfire', 'pudge', 'razor', 'viper',
  'abyssal_underlord', 'kunkka', 'zeus',
};

/// Подходящие предметы против особенностей вражеского состава.
class ItemTip {
  final String title;
  final String reason;
  final List<String> items; // ключи предметов
  const ItemTip(this.title, this.reason, this.items);
}

const itemNames = {
  'black_king_bar': 'Black King Bar',
  'pipe': 'Pipe of Insight',
  'glimmer_cape': 'Glimmer Cape',
  'eternal_shroud': 'Eternal Shroud',
  'ghost': 'Ghost Scepter',
  'shivas_guard': "Shiva's Guard",
  'crimson_guard': 'Crimson Guard',
  'heavens_halberd': "Heaven's Halberd",
  'solar_crest': 'Solar Crest',
  'spirit_vessel': 'Spirit Vessel',
  'skadi': 'Eye of Skadi',
  'dust': 'Dust of Appearance',
  'ward_sentry': 'Sentry Ward',
  'gem': 'Gem of True Sight',
  'bfury': 'Battle Fury',
  'mjollnir': 'Mjollnir',
  'radiance': 'Radiance',
  'monkey_king_bar': 'Monkey King Bar',
  'bloodthorn': 'Bloodthorn',
  'sphere': "Linken's Sphere",
  'lotus_orb': 'Lotus Orb',
  'manta': 'Manta Style',
  'cyclone': "Eul's Scepter",
  'nullifier': 'Nullifier',
  'silver_edge': 'Silver Edge',
  'force_staff': 'Force Staff',
  'blink': 'Blink Dagger',
};

String itemImage(String key) => 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/items/$key.png';
