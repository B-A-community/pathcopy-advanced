# frozen_string_literal: true

module BACommunity
  module PathCopyAdvanced
    # The tool's right-click menu.
    #
    # Every option is reachable here, so nothing depends on remembering a
    # keyboard shortcut - the original hid its second mode behind "type 0 into
    # the measurement box" and never told anyone.
    module Menus
      module_function

      def build(menu, settings, &on_change)
        menu.add_item('Панель настроек') do
          settings.show_panel = true
          settings.save
          Panel.show(settings)
        end
        menu.add_separator

        radio_group(menu.add_submenu('Расстановка'), DISTRIBUTION_MODES,
                    DISTRIBUTION_LABELS, settings, :distribution, &on_change)
        radio_group(menu.add_submenu('Ориентация'), ORIENTATION_MODES,
                    ORIENTATION_LABELS, settings, :orientation, &on_change)
        radio_group(menu.add_submenu('Остаток шага'), ALIGN_MODES,
                    ALIGN_LABELS, settings, :align, &on_change)
        radio_group(menu.add_submenu('Точка привязки'), ANCHOR_MODES,
                    ANCHOR_LABELS, settings, :anchor, &on_change)
        radio_group(menu.add_submenu('Замкнутый контур'), FACING_MODES,
                    FACING_LABELS, settings, :facing, &on_change)

        menu.add_separator
        toggle(menu, 'Не дублировать копию на стыке', settings, :skip_seam, &on_change)
        toggle(menu, 'Развернуть направление пути', settings, :reverse_path, &on_change)
        toggle(menu, 'Разворачивать каждую вторую', settings, :alternate_flip, &on_change)
        toggle(menu, 'Разброс', settings, :jitter, &on_change)
        toggle(menu, 'Сгруппировать копии', settings, :group_result, &on_change)

        menu.add_separator
        menu.add_item('Смещения и поворот…') { offsets_dialog(settings, &on_change) }
        menu.add_item('Разброс…') { jitter_dialog(settings, &on_change) }
        menu.add_item('Тег для копий…') { tag_dialog(settings, &on_change) }

        menu.add_separator
        menu.add_item('Сбросить настройки') do
          Settings::DEFAULTS.each { |key, value| settings.send("#{key}=", value) unless key == :show_panel }
          settings.sanitize!
          on_change&.call
        end
        menu
      end

      def radio_group(menu, modes, labels, settings, attribute, &on_change)
        modes.each do |mode|
          item = menu.add_item(labels[mode]) do
            settings.send("#{attribute}=", mode)
            settings.sanitize!
            on_change&.call
          end
          menu.set_validation_proc(item) do
            settings.send(attribute) == mode ? MF_CHECKED : MF_UNCHECKED
          end
        end
      end

      def toggle(menu, label, settings, attribute, &on_change)
        item = menu.add_item(label) do
          settings.send("#{attribute}=", !settings.send(attribute))
          settings.sanitize!
          on_change&.call
        end
        menu.set_validation_proc(item) do
          settings.send(attribute) ? MF_CHECKED : MF_UNCHECKED
        end
      end

      # --- dialogs -------------------------------------------------------

      def offsets_dialog(settings, &on_change)
        prompts = ['Отступ от начала', 'Отступ от конца', 'Смещение вбок', 'Смещение вверх',
                   'Доворот, °']
        defaults = [
          length(settings.start_offset), length(settings.end_offset),
          length(settings.offset_lateral), length(settings.offset_vertical),
          settings.extra_angle.to_s
        ]
        result = UI.inputbox(prompts, defaults, "#{PLUGIN_NAME} — смещения")
        return unless result

        settings.start_offset    = to_inches(result[0], settings.start_offset)
        settings.end_offset      = to_inches(result[1], settings.end_offset)
        settings.offset_lateral  = to_inches(result[2], settings.offset_lateral)
        settings.offset_vertical = to_inches(result[3], settings.offset_vertical)
        settings.extra_angle     = result[4].to_f
        settings.sanitize!
        on_change&.call
      end

      def jitter_dialog(settings, &on_change)
        prompts = ['Поворот ±, °', 'Масштаб ±, %', 'Сдвиг вдоль ±',
                   'Сдвиг вбок ±', 'Сдвиг вверх ±', 'Зерно']
        defaults = [
          settings.jitter_angle.to_s,
          (settings.jitter_scale * 100.0).round(1).to_s,
          length(settings.jitter_along),
          length(settings.jitter_lateral),
          length(settings.jitter_vertical),
          settings.seed.to_s
        ]
        result = UI.inputbox(prompts, defaults, "#{PLUGIN_NAME} — разброс")
        return unless result

        settings.jitter_angle    = result[0].to_f
        settings.jitter_scale    = result[1].to_f / 100.0
        settings.jitter_along    = to_inches(result[2], settings.jitter_along)
        settings.jitter_lateral  = to_inches(result[3], settings.jitter_lateral)
        settings.jitter_vertical = to_inches(result[4], settings.jitter_vertical)
        settings.seed            = result[5].to_i
        settings.jitter = true
        settings.sanitize!
        on_change&.call
      end

      def tag_dialog(settings, &on_change)
        result = UI.inputbox(
          ['Тег для копий (пусто — как у исходника)'],
          [settings.tag_name],
          "#{PLUGIN_NAME} — результат"
        )
        return unless result

        settings.tag_name = result[0].to_s
        settings.sanitize!
        on_change&.call
      end

      def length(inches)
        Sketchup.format_length(inches.to_f)
      end

      def to_inches(text, fallback)
        value = text.to_s.strip
        return 0.0 if value.empty?

        value.to_l.to_f
      rescue ArgumentError
        UI.beep
        fallback.to_f
      end
    end
  end
end
