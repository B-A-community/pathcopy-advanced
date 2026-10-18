# Copyright 2026 B&A community
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Язык Ruby-части (меню, статусная строка, диалоги, имена в модели) — как в
# RALNCS и area counter. tools\build_rbz.ps1 -Lang en подменяет строку LANG;
# окно настроек берёт язык из html/i18n.js (там та же подмена).

module BACommunity
  module PathCopyAdvanced
    LANG = 'ru'

    STRINGS = {
      'ru' => {
        ext_description: 'Копирование групп и компонентов вдоль пути: цепочки рёбер без сварки, ' \
                         'шаг или количество, ориентация по пути, поручень профилем.',

        # меню и панель инструментов
        tip_tool:        'PathCopy Advanced',
        st_tool:         'Копировать группу или компонент вдоль пути',
        menu_panel:      'Панель настроек',
        tip_panel:       'Настройки PathCopy Advanced',
        st_panel:        'Открыть панель настроек PathCopy Advanced',
        menu_about:      'О плагине…',
        title_about:     'О плагине PathCopy Advanced',
        menu_reset:      'Сбросить настройки',

        # контекстное меню инструмента
        menu_distribution: 'Расстановка',
        menu_orientation:  'Ориентация',
        menu_align:        'Остаток шага',
        menu_anchor:       'Точка привязки',
        menu_facing:       'Замкнутый контур',
        menu_rail_align:   'Поручень: привязка',
        menu_rail_shape:   'Поручень: сечение',
        mi_rail:         'Поручень вдоль пути',
        mi_skip_seam:    'Не дублировать копию на стыке',
        mi_reverse:      'Развернуть направление пути',
        mi_flip:         'Разворачивать каждую вторую',
        mi_jitter:       'Разброс',
        mi_group:        'Сгруппировать копии',
        mi_offsets:      'Смещения и поворот…',
        mi_jitter_dlg:   'Разброс…',
        mi_rail_dlg:     'Поручень…',
        mi_tag:          'Тег для копий…',

        # режимы
        dist_spacing:    'Шаг',
        dist_count:      'Количество',
        dist_fit:        'Подгонка шага',
        dist_segments:   'Подгонка по сегментам',
        dist_vertices:   'По вершинам',
        orient_flat:     'По пути, в плане',
        orient_tangent3d: 'По пути, в 3D',
        orient_planar:   'По плоскости пути',
        orient_none:     'Не поворачивать',
        align_start:     'От начала',
        align_center:    'По центру',
        align_end:       'От конца',
        anchor_origin:   'Начало координат объекта',
        anchor_center:   'Центр габаритов',
        anchor_bottom:   'Низ габаритов',
        facing_auto:     'Как нарисовано',
        facing_outward:  'Наружу',
        facing_inward:   'Внутрь',
        railshape_rect:  'Прямоугольное',
        railshape_round: 'Круглое',
        railalign_center:  'По центру',
        railalign_outward: 'Наружу',
        railalign_inward:  'Внутрь',

        # сводка режима в статусной строке
        sum_reversed:    'путь развёрнут',
        sum_jitter:      'разброс',
        sum_rail:        'поручень',
        dash:            '—',

        # статусная строка инструмента
        hints:           'Tab — режим, ↑↓ — ориентация, ←→ — остаток, всё остальное — в панели',
        st_pick_path:    'Кликните ребро или грань — это путь (%s+клик добавляет ещё один, ' \
                         'или выделите рёбра заранее). [%s]',
        st_pick_source:  'Кликните группу или компонент — его копируем; %s+клик добавляет объекты и пути. ',
        st_paths_n:      'Путей: %d. ',
        st_queued_n:     'В очереди объектов: %d. ',
        st_places_n:     'Мест: %d. ',
        st_placed:       'Готово: %d. Клик по копии — доворот на %d°, Shift+клик — обратно; ' \
                         'Esc убирает всё. %s',

        # поле измерений
        vcb_spacing:     'Шаг',
        vcb_copies:      'Копий',
        vcb_vertices:    'Вершин',
        vcb_fit:         'Шаг, подгонка',
        vcb_segments:    'Шаг в сегменте',

        # строка состояния в панели
        ps_idle:         'Инструмент не запущен — значения запомнятся.',
        ps_pick_path:    'Кликните ребро или грань — это путь.',
        ps_pick_source:  'Путь выбран. Кликните группу или компонент. Мест: %d.',
        ps_placed:       'Готово: объектов %d.%s Клик по копии доворачивает её на %d°, Shift+клик — обратно.',
        ps_nudged:       ' Довёрнуто вручную: %d.',

        # диалоги
        dlg_offsets:     'PathCopy Advanced — смещения',
        p_start_offset:  'Отступ от начала',
        p_end_offset:    'Отступ от конца',
        p_offset_side:   'Смещение вбок',
        p_offset_up:     'Смещение вверх',
        p_extra_angle:   'Доворот, °',
        dlg_jitter:      'PathCopy Advanced — разброс',
        p_j_angle:       'Поворот ±, °',
        p_j_scale:       'Масштаб ±, %',
        p_j_along:       'Сдвиг вдоль ±',
        p_j_side:        'Сдвиг вбок ±',
        p_j_up:          'Сдвиг вверх ±',
        p_seed:          'Зерно',
        dlg_rail:        'PathCopy Advanced — поручень',
        p_rail_width:    'Ширина',
        p_rail_height:   'Высота',
        p_rail_extend:   'Продлить концы',
        p_rail_rise:     'Поднять над путём',
        dlg_tag:         'PathCopy Advanced — результат',
        p_tag:           'Тег для копий (пусто — как у исходника)',

        # ошибки и имена в модели
        err_place:       "PathCopy Advanced не смог расставить копии:\n\n%s",
        name_group:      'PathCopy — %s',
        name_objects:    'объекты',
        name_rail:       'PathCopy — поручень'
      },

      'en' => {
        ext_description: 'Copy groups and components along a path: edge chains without welding, ' \
                         'spacing or count, orientation along the path, a swept railing.',

        tip_tool:        'PathCopy Advanced',
        st_tool:         'Copy a group or component along a path',
        menu_panel:      'Settings panel',
        tip_panel:       'PathCopy Advanced settings',
        st_panel:        'Open the PathCopy Advanced settings panel',
        menu_about:      'About…',
        title_about:     'About PathCopy Advanced',
        menu_reset:      'Reset options',

        menu_distribution: 'Distribution',
        menu_orientation:  'Orientation',
        menu_align:        'Leftover',
        menu_anchor:       'Anchor',
        menu_facing:       'Closed path',
        menu_rail_align:   'Railing: alignment',
        menu_rail_shape:   'Railing: section',
        mi_rail:         'Railing along the path',
        mi_skip_seam:    'No duplicate copy at the seam',
        mi_reverse:      'Reverse path direction',
        mi_flip:         'Flip every second copy',
        mi_jitter:       'Randomise',
        mi_group:        'Group the copies',
        mi_offsets:      'Offsets and rotation…',
        mi_jitter_dlg:   'Randomisation…',
        mi_rail_dlg:     'Railing…',
        mi_tag:          'Tag for copies…',

        dist_spacing:    'Spacing',
        dist_count:      'Count',
        dist_fit:        'Fit spacing',
        dist_segments:   'Fit per segment',
        dist_vertices:   'Vertices',
        orient_flat:     'Follow path, in plan',
        orient_tangent3d: 'Follow path, in 3D',
        orient_planar:   'Follow path plane',
        orient_none:     'Keep orientation',
        align_start:     'From start',
        align_center:    'Centred',
        align_end:       'From end',
        anchor_origin:   'Object origin',
        anchor_center:   'Bounds centre',
        anchor_bottom:   'Bounds bottom',
        facing_auto:     'As drawn',
        facing_outward:  'Outward',
        facing_inward:   'Inward',
        railshape_rect:  'Rectangular',
        railshape_round: 'Round',
        railalign_center:  'Centred',
        railalign_outward: 'Outward',
        railalign_inward:  'Inward',

        sum_reversed:    'reversed',
        sum_jitter:      'random',
        sum_rail:        'railing',
        dash:            '—',

        hints:           'Tab — mode, ↑↓ — orientation, ←→ — leftover, everything else is in the panel',
        st_pick_path:    'Click an edge or a face to use as the path (%s+click adds another one, ' \
                         'or pre-select the edges). [%s]',
        st_pick_source:  'Click the group or component to copy; %s+click adds objects and paths. ',
        st_paths_n:      'Paths: %d. ',
        st_queued_n:     'Objects queued: %d. ',
        st_places_n:     'Placements: %d. ',
        st_placed:       'Done: %d. Click a copy to turn it by %d°, Shift+click turns it back; ' \
                         'Esc removes everything. %s',

        vcb_spacing:     'Spacing',
        vcb_copies:      'Copies',
        vcb_vertices:    'Vertices',
        vcb_fit:         'Target spacing',
        vcb_segments:    'Spacing per segment',

        ps_idle:         'The tool is not running — the values will be remembered.',
        ps_pick_path:    'Click an edge or a face to use as the path.',
        ps_pick_source:  'Path selected. Click a group or component. Placements: %d.',
        ps_placed:       'Done: %d objects.%s Click a copy to turn it by %d°, Shift+click turns it back.',
        ps_nudged:       ' Turned by hand: %d.',

        dlg_offsets:     'PathCopy Advanced — offsets',
        p_start_offset:  'Offset from start',
        p_end_offset:    'Offset from end',
        p_offset_side:   'Sideways offset',
        p_offset_up:     'Vertical offset',
        p_extra_angle:   'Extra rotation, °',
        dlg_jitter:      'PathCopy Advanced — randomisation',
        p_j_angle:       'Rotation ±, °',
        p_j_scale:       'Scale ±, %',
        p_j_along:       'Shift along ±',
        p_j_side:        'Shift sideways ±',
        p_j_up:          'Shift up ±',
        p_seed:          'Seed',
        dlg_rail:        'PathCopy Advanced — railing',
        p_rail_width:    'Width',
        p_rail_height:   'Height',
        p_rail_extend:   'Extend the ends',
        p_rail_rise:     'Raise above the path',
        dlg_tag:         'PathCopy Advanced — result',
        p_tag:           'Tag for copies (blank — same as the source)',

        err_place:       "PathCopy Advanced could not place the copies:\n\n%s",
        name_group:      'PathCopy — %s',
        name_objects:    'objects',
        name_rail:       'PathCopy — railing'
      }
    }.freeze

    def self.t(key, *args)
      table = STRINGS[LANG] || STRINGS['ru']
      string = table.key?(key) ? table[key] : STRINGS['ru'].fetch(key, key.to_s)
      args.empty? ? string : format(string, *args)
    end

    # Подписи режимов одним хэшем: меню и панель берут их отсюда, чтобы
    # список режимов и его перевод не разъезжались.
    def self.labels(group)
      prefix = LABEL_PREFIX.fetch(group)
      MODE_LISTS.fetch(group).each_with_object({}) do |mode, hash|
        hash[mode] = t(:"#{prefix}_#{mode}")
      end
    end
  end
end
