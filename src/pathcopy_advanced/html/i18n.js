// Язык окон — как в RALNCS и area counter.
// tools\build_rbz.ps1 -Lang en подменяет первую строку.
var LANG = 'ru';

var I18N = {
  ru: {
    // шапка и статус
    btn_reset: 'Сброс',
    t_reset: 'Вернуть все настройки к исходным',

    // расстановка
    g_distribution: 'Расстановка',
    f_mode: 'Режим',
    f_spacing: 'Шаг',
    hint_fit: 'подгоняется под длину',
    hint_segments: 'подгоняется в каждом сегменте',
    f_count: 'Копий',
    f_align: 'Остаток',
    f_offsets: 'Отступы',
    t_start_offset: 'От начала пути',
    t_end_offset: 'От конца пути',
    u_startend: 'начало / конец',
    c_skip_seam: 'на замкнутом контуре не дублировать копию на стыке',

    // ориентация
    g_orientation: 'Ориентация',
    f_rotation: 'Поворот',
    f_relative: 'Относительно пути',
    b_along: 'Вдоль',
    b_across: 'Поперёк',
    t_along: 'Ось X объекта вдоль пути',
    t_across: 'Ось X объекта поперёк пути',
    t_extra_angle: 'Доворот вокруг вертикальной оси объекта',
    f_anchor: 'Точка привязки',
    f_facing: 'Замкнутый контур',
    t_facing: 'Куда развёрнуты копии на замкнутом контуре: от центра или к центру',
    hint_facing_loop: 'Копии разворачиваются лицом от центра контура или к нему, как бы ни был нарисован контур.',
    hint_facing_open: 'Путь не замкнут — настройка не действует.',
    hint_facing_none: 'Действует только на замкнутом контуре: окружность, контур грани, замкнутая цепочка.',
    c_reverse: 'развернуть направление пути',
    c_flip: 'разворачивать каждую вторую копию',
    f_nudge: 'Доворот кликом',
    t_nudge: 'На сколько поворачивается копия, по которой кликнули',
    b_clear: 'Сбросить',
    t_clear: 'Вернуть довёрнутым копиям общую ориентацию',
    hint_nudge: 'Клик по уже поставленной копии доворачивает её, Shift+клик — обратно.',
    hint_nudge_n: 'Довёрнуто вручную: {n}. Клик по копии доворачивает её, Shift+клик — обратно.',
    f_offset: 'Смещение',
    t_offset_side: 'Вбок от пути (влево по ходу — положительное)',
    t_offset_up: 'По нормали пути',
    u_sideup: 'вбок / вверх',

    // разброс
    g_jitter: 'Разброс',
    f_j_angle: 'Поворот ±',
    f_j_scale: 'Масштаб ±',
    f_j_shift: 'Сдвиг ±',
    t_j_along: 'Вдоль пути',
    t_j_side: 'Вбок',
    t_j_up: 'Вверх',
    f_seed: 'Зерно',
    t_seed: 'Одно и то же число — один и тот же разброс',
    u_jitter: 'вдоль / вбок / вверх — в единицах модели',

    // поручень
    g_rail: 'Поручень вдоль пути',
    f_rail_shape: 'Сечение',
    f_rail_size: 'Габарит',
    t_rail_width: 'Ширина сечения, поперёк пути',
    t_rail_height: 'Высота сечения',
    u_wh: 'ширина / высота',
    f_rail_align: 'Привязка',
    t_rail_align: 'Где профиль относительно линии пути: сидит на ней или целиком с одной стороны',
    hint_rail_align_loop: 'Наружу и внутрь считаются от центра контура.',
    hint_rail_align_open: 'Наружу — влево по ходу пути, внутрь — вправо.',
    f_rail_extend: 'Продлить концы',
    t_rail_extend: 'На сколько вывести поручень за крайние точки пути',
    f_rail_rise: 'Поднять',
    t_rail_rise: 'Подъём профиля над линией пути — поручень поверх стоек',
    hint_rail_rise: 'Без подъёма профиль центрируется прямо на линии пути.',

    // результат
    g_result: 'Результат',
    f_tag: 'Тег копий',
    ph_tag: 'как у исходника',
    c_group: 'сгруппировать копии',

    foot: 'Всё применяется сразу, копии перестраиваются на месте; вся сессия — один шаг отмены (Ctrl+Z). ' +
          'В поле измерений SketchUp: число — шаг, <b>20x</b> — двадцать копий, <b>0</b> — по вершинам. ' +
          'Tab — следующий режим, ↑↓ — ориентация, ←→ — остаток.',

    // окно «О плагине»
    about_title: 'PathCopy Advanced',
    about_sub: 'Копирование групп и компонентов вдоль пути',
    about_version: 'Версия',
    about_authors: 'Создатели',
    about_repo: 'Репозиторий',
    about_license: 'Лицензия Apache 2.0 · © 2026 B&A community',
    about_close: 'Закрыть'
  },

  en: {
    btn_reset: 'Reset',
    t_reset: 'Restore every option to its default',

    g_distribution: 'Distribution',
    f_mode: 'Mode',
    f_spacing: 'Spacing',
    hint_fit: 'fitted to the path length',
    hint_segments: 'fitted inside each segment',
    f_count: 'Copies',
    f_align: 'Leftover',
    f_offsets: 'Offsets',
    t_start_offset: 'From the start of the path',
    t_end_offset: 'From the end of the path',
    u_startend: 'start / end',
    c_skip_seam: 'on a closed path, no duplicate copy at the seam',

    g_orientation: 'Orientation',
    f_rotation: 'Rotation',
    f_relative: 'Relative to path',
    b_along: 'Along',
    b_across: 'Across',
    t_along: "The object's X axis along the path",
    t_across: "The object's X axis across the path",
    t_extra_angle: "Extra turn about the object's vertical axis",
    f_anchor: 'Anchor',
    f_facing: 'Closed path',
    t_facing: 'Which way the copies face on a closed path: away from the centre or towards it',
    hint_facing_loop: 'Copies face away from the centre of the loop or towards it, however the loop was drawn.',
    hint_facing_open: 'The path is not closed — this setting does nothing.',
    hint_facing_none: 'Works on a closed path only: a circle, a face outline, a closed chain.',
    c_reverse: 'reverse the path direction',
    c_flip: 'flip every second copy',
    f_nudge: 'Click rotation',
    t_nudge: 'How far a copy turns when you click it',
    b_clear: 'Clear',
    t_clear: 'Return the hand-turned copies to the common orientation',
    hint_nudge: 'Click a placed copy to turn it, Shift+click turns it back.',
    hint_nudge_n: 'Turned by hand: {n}. Click a copy to turn it, Shift+click turns it back.',
    f_offset: 'Offset',
    t_offset_side: 'Sideways from the path (left along travel is positive)',
    t_offset_up: 'Along the path normal',
    u_sideup: 'side / up',

    g_jitter: 'Randomise',
    f_j_angle: 'Rotation ±',
    f_j_scale: 'Scale ±',
    f_j_shift: 'Shift ±',
    t_j_along: 'Along the path',
    t_j_side: 'Sideways',
    t_j_up: 'Upwards',
    f_seed: 'Seed',
    t_seed: 'The same number gives the same layout',
    u_jitter: 'along / sideways / up — in model units',

    g_rail: 'Railing along the path',
    f_rail_shape: 'Section',
    f_rail_size: 'Size',
    t_rail_width: 'Section width, across the path',
    t_rail_height: 'Section height',
    u_wh: 'width / height',
    f_rail_align: 'Alignment',
    t_rail_align: 'Where the profile sits relative to the path line: on it, or wholly to one side',
    hint_rail_align_loop: 'Outward and inward are measured from the centre of the loop.',
    hint_rail_align_open: 'Outward is left along the path, inward is right.',
    f_rail_extend: 'Extend the ends',
    t_rail_extend: 'How far the railing runs past the end points of the path',
    f_rail_rise: 'Raise',
    t_rail_rise: 'Lift the profile above the path line — a handrail over the balusters',
    hint_rail_rise: 'With no rise the profile is centred right on the path line.',

    g_result: 'Result',
    f_tag: 'Tag for copies',
    ph_tag: 'same as the source',
    c_group: 'group the copies',

    foot: 'Everything applies at once and the copies rebuild in place; the whole session is one undo step (Ctrl+Z). ' +
          'In the SketchUp measurement box: a number is the spacing, <b>20x</b> is twenty copies, <b>0</b> is one per vertex. ' +
          'Tab — next mode, ↑↓ — orientation, ←→ — leftover.',

    about_title: 'PathCopy Advanced',
    about_sub: 'Copy groups and components along a path',
    about_version: 'Version',
    about_authors: 'Created by',
    about_repo: 'Repository',
    about_license: 'Apache 2.0 licence · © 2026 B&A community',
    about_close: 'Close'
  }
};

// Короткий доступ: T.f_mode. Отсутствующий ключ возвращает сам ключ, чтобы
// пропажа была видна на экране, а не молча ломала разметку.
var T = new Proxy(I18N[LANG] || I18N.ru, {
  get: function (table, key) {
    return key in table ? table[key] : String(key);
  }
});

// Подстановка {n} и подобных.
function tf(key, values) {
  var s = T[key];
  Object.keys(values || {}).forEach(function (k) {
    s = s.split('{' + k + '}').join(values[k]);
  });
  return s;
}

// Проставляет подписи из словаря по data-атрибутам: data-t — текст,
// data-t-title — всплывающая подсказка, data-t-ph — placeholder.
function applyI18n(root) {
  (root || document).querySelectorAll('[data-t]').forEach(function (el) {
    el.innerHTML = T[el.dataset.t];
  });
  (root || document).querySelectorAll('[data-t-title]').forEach(function (el) {
    el.title = T[el.dataset.tTitle];
  });
  (root || document).querySelectorAll('[data-t-ph]').forEach(function (el) {
    el.placeholder = T[el.dataset.tPh];
  });
}
